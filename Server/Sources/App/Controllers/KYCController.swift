import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import Fluent
import FluentSQL
import Vapor

struct KYCController: RouteCollection {

    // MARK: - Constants

    private let maxFileSize = 10 * 1024 * 1024
    private let signedURLExpiration = 300

    private enum DocumentType {
        static let driversLicense = "drivers_license"
        static let myNumberCard = "my_number_card"

        static let all: Set<String> = [
            driversLicense,
            myNumberCard
        ]
    }

    // MARK: - Routes

    func boot(routes: any RoutesBuilder) throws {

        // ログイン必須
        let protected = routes.grouped(
            SupabaseAuthMiddleware()
        )

        let kyc = protected.grouped(
            "api",
            "kyc"
        )

        // 本人確認書類提出
        kyc.on(
            .POST,
            "submit",
            body: .collect(maxSize: "12mb"),
            use: submit
        )

        // 自分の本人確認状態
        kyc.get(
            "status",
            use: status
        )

        // 管理者専用
        let admin = kyc
            .grouped("admin")
            .grouped(
                RequireAdminMiddleware()
            )

        // 審査待ち一覧
        admin.get(
            "submissions",
            use: adminSubmissions
        )

        // 本人確認書類のSigned URL取得
        admin.get(
            ":submissionId",
            "document-url",
            use: adminDocumentURL
        )

        // 承認
        admin.post(
            ":submissionId",
            "approve",
            use: approve
        )

        // 却下
        admin.post(
            ":submissionId",
            "reject",
            use: reject
        )
    }

    // MARK: - Submit KYC

    @Sendable
    func submit(
        req: Request
    ) async throws -> KYCSubmissionResponse {

        // ログインユーザー取得
        let user = try req.auth.require(
            AuthenticatedUser.self
        )

        // multipart/form-dataを取得
        let form = try req.content.decode(
            KYCUploadForm.self
        )

        // 書類種類
        let documentType = form.documentType
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .lowercased()

        guard DocumentType.all.contains(documentType) else {
            throw Abort(
                .badRequest,
                reason: "本人確認書類の種類が不正です。"
            )
        }

        // ByteBuffer → Data
        let data = Data(
            form.file.data.readableBytesView
        )

        guard !data.isEmpty else {
            throw Abort(
                .badRequest,
                reason: "本人確認書類の画像がありません。"
            )
        }

        guard data.count <= maxFileSize else {
            throw Abort(
                .payloadTooLarge,
                reason: "本人確認画像は10MB以下にしてください。"
            )
        }

        let verified = try await isVerified(
            userId: user.id,
            database: req.db
        )

        if verified {
            throw Abort(
                .conflict,
                reason: "すでに本人確認済みです。"
            )
        }

        let existingPending = try await KYCSubmission.query(
            on: req.db
        )
        .filter(\.$userId == user.id)
        .filter(\.$status == KYCSubmission.Status.pending)
        .first()

        if existingPending != nil {
            throw Abort(
                .conflict,
                reason: "現在、本人確認申請を審査中です。"
            )
        }

        guard let imageType = detectImageType(data) else {
            throw Abort(
                .unsupportedMediaType,
                reason: "JPEG、PNG、HEICの画像のみ提出できます。"
            )
        }

        // Supabase Storage設定
        let config = try supabaseConfiguration()

        // ファイルID
        let fileID = UUID().uuidString

        let fileName =
            "\(fileID).\(imageType.fileExtension)"

        // Storage上の保存場所
        let storagePath =
            "\(user.id.uuidString)/\(documentType)/\(fileName)"

        do {

            // ------------------------------------------
            // 1. Supabase Storageへアップロード
            // ------------------------------------------

            try await uploadToSupabaseStorage(
                data: data,
                bucket: config.bucket,
                path: storagePath,
                contentType: imageType.mimeType,
                baseURL: config.baseURL,
                secretKey: config.secretKey
            )

            // ------------------------------------------
            // 2. DBへ申請登録
            // ------------------------------------------

            let submission = KYCSubmission(
                userId: user.id,
                documentType: documentType,
                documentPath: storagePath,
                status: KYCSubmission.Status.pending
            )

            try await submission.save(
                on: req.db
            )

            guard let submissionID = submission.id else {
                throw Abort(
                    .internalServerError,
                    reason: "本人確認申請IDを取得できませんでした。"
                )
            }

            return KYCSubmissionResponse(
                id: submissionID,
                userId: submission.userId,
                documentType: submission.documentType,
                status: submission.status
            )

        } catch {

            // DB登録失敗時はStorageに残ったファイルを削除
            do {

                try await deleteFromSupabaseStorage(
                    bucket: config.bucket,
                    path: storagePath,
                    baseURL: config.baseURL,
                    secretKey: config.secretKey
                )

            } catch {

                req.logger.error(
                    """
                    KYC Storage cleanup failed:
                    \(String(describing: error))
                    """
                )
            }

            throw error
        }
    }

    // MARK: - KYC Status

    @Sendable
    func status(
        req: Request
    ) async throws -> KYCSubmissionResponse {

        let user = try req.auth.require(
            AuthenticatedUser.self
        )

        let submission = try await KYCSubmission.query(
            on: req.db
        )
        .filter(\.$userId == user.id)
        .sort(
            \.$id,
            .descending
        )
        .first()

        // まだ申請していない場合
        guard let submission else {

            return KYCSubmissionResponse(
                id: nil,
                userId: nil,
                documentType: nil,
                status: nil
            )
        }

        guard let id = submission.id else {
            throw Abort(
                .internalServerError,
                reason: "本人確認申請IDを取得できませんでした。"
            )
        }

        return KYCSubmissionResponse(
            id: id,
            userId: submission.userId,
            documentType: submission.documentType,
            status: submission.status
        )
    }

    // MARK: - Admin: Submission List

    @Sendable
    func adminSubmissions(
        req: Request
    ) async throws -> [KYCSubmissionResponse] {

        // RequireAdminMiddlewareですでに管理者確認済み
        _ = try req.auth.require(
            AuthenticatedUser.self
        )

        let submissions = try await KYCSubmission.query(
            on: req.db
        )
        .filter(
            \.$status == KYCSubmission.Status.pending
        )
        .sort(
            \.$id,
            .ascending
        )
        .all()

        return try submissions.map { submission in

            guard let id = submission.id else {
                throw Abort(
                    .internalServerError,
                    reason: "本人確認申請IDを取得できませんでした。"
                )
            }

            return KYCSubmissionResponse(
                id: id,
                userId: submission.userId,
                documentType: submission.documentType,
                status: submission.status
            )
        }
    }

    // MARK: - Admin: Document URL

    @Sendable
    func adminDocumentURL(
        req: Request
    ) async throws -> KYCDocumentURLResponse {

        _ = try req.auth.require(
            AuthenticatedUser.self
        )

        guard
            let submissionIDString =
                req.parameters.get("submissionId"),
            let submissionID =
                UUID(uuidString: submissionIDString)
        else {
            throw Abort(
                .badRequest,
                reason: "申請IDが不正です。"
            )
        }

        guard let submission =
            try await KYCSubmission.query(
                on: req.db
            )
            .filter(\.$id == submissionID)
            .first()
        else {
            throw Abort(
                .notFound,
                reason: "本人確認申請が見つかりません。"
            )
        }

        let config = try supabaseConfiguration()

        let signedURL = try await createSignedURL(
            bucket: config.bucket,
            path: submission.documentPath,
            expiresIn: signedURLExpiration,
            baseURL: config.baseURL,
            secretKey: config.secretKey
        )

        return KYCDocumentURLResponse(
            url: signedURL,
            expiresIn: signedURLExpiration
        )
    }

    // MARK: - Admin: Approve

    @Sendable
    func approve(
        req: Request
    ) async throws -> KYCSubmissionResponse {

        let admin = try req.auth.require(
            AuthenticatedUser.self
        )

        guard
            let submissionIDString =
                req.parameters.get("submissionId"),
            let submissionID =
                UUID(uuidString: submissionIDString)
        else {
            throw Abort(
                .badRequest,
                reason: "申請IDが不正です。"
            )
        }

        guard let submission =
            try await KYCSubmission.query(
                on: req.db
            )
            .filter(\.$id == submissionID)
            .first()
        else {
            throw Abort(
                .notFound,
                reason: "本人確認申請が見つかりません。"
            )
        }

        // 二重審査防止
        guard submission.status == KYCSubmission.Status.pending else {
            throw Abort(
                .conflict,
                reason: "この申請はすでに審査済みです。"
            )
        }

        // PostgreSQLへ直接更新
        guard let sql = req.db as? SQLDatabase else {
            throw Abort(
                .internalServerError,
                reason: "PostgreSQLデータベースに接続できません。"
            )
        }

        try await sql.raw(
            """
            UPDATE public.profiles
            SET is_verified = TRUE
            WHERE id = \(bind: submission.userId)
            """
        )
        .run()

        // KYC申請を承認
        submission.status =
            KYCSubmission.Status.approved

        try await submission.save(
            on: req.db
        )

        req.logger.info(
            """
            KYC approved.
            submission=\(submissionID)
            admin=\(admin.id)
            """
        )

        guard let id = submission.id else {
            throw Abort(
                .internalServerError,
                reason: "本人確認申請IDを取得できませんでした。"
            )
        }

        return KYCSubmissionResponse(
            id: id,
            userId: submission.userId,
            documentType: submission.documentType,
            status: submission.status
        )
    }

    // MARK: - Admin: Reject

    @Sendable
    func reject(
        req: Request
    ) async throws -> KYCSubmissionResponse {

        let admin = try req.auth.require(
            AuthenticatedUser.self
        )

        guard
            let submissionIDString =
                req.parameters.get("submissionId"),
            let submissionID =
                UUID(uuidString: submissionIDString)
        else {
            throw Abort(
                .badRequest,
                reason: "申請IDが不正です。"
            )
        }

        guard let submission =
            try await KYCSubmission.query(
                on: req.db
            )
            .filter(\.$id == submissionID)
            .first()
        else {
            throw Abort(
                .notFound,
                reason: "本人確認申請が見つかりません。"
            )
        }

        // 二重審査防止
        guard submission.status == KYCSubmission.Status.pending else {
            throw Abort(
                .conflict,
                reason: "この申請はすでに審査済みです。"
            )
        }

        // 却下
        submission.status =
            KYCSubmission.Status.rejected

        try await submission.save(
            on: req.db
        )

        req.logger.info(
            """
            KYC rejected.
            submission=\(submissionID)
            admin=\(admin.id)
            """
        )

        guard let id = submission.id else {
            throw Abort(
                .internalServerError,
                reason: "本人確認申請IDを取得できませんでした。"
            )
        }

        return KYCSubmissionResponse(
            id: id,
            userId: submission.userId,
            documentType: submission.documentType,
            status: submission.status
        )
    }

    // MARK: - Profile Verification

    private func isVerified(
        userId: UUID,
        database: Database
    ) async throws -> Bool {

        guard let sql = database as? SQLDatabase else {
            throw Abort(
                .internalServerError,
                reason: "PostgreSQLデータベースに接続できません。"
            )
        }

        struct VerificationRow: Decodable {

            let isVerified: Bool

            enum CodingKeys: String, CodingKey {
                case isVerified = "is_verified"
            }
        }

        let result = try await sql.raw(
            """
            SELECT is_verified
            FROM public.profiles
            WHERE id = \(bind: userId)
            LIMIT 1
            """
        )
        .first(
            decoding: VerificationRow.self
        )

        return result?.isVerified ?? false
    }

    // MARK: - Image Type

    private enum DetectedImageType {

        case jpeg
        case png
        case heic

        var fileExtension: String {

            switch self {

            case .jpeg:
                return "jpg"

            case .png:
                return "png"

            case .heic:
                return "heic"
            }
        }

        var mimeType: String {

            switch self {

            case .jpeg:
                return "image/jpeg"

            case .png:
                return "image/png"

            case .heic:
                return "image/heic"
            }
        }
    }

    private func detectImageType(
        _ data: Data
    ) -> DetectedImageType? {

        let bytes = [UInt8](
            data.prefix(12)
        )

        // JPEG
        if bytes.count >= 3,
           bytes[0] == 0xFF,
           bytes[1] == 0xD8,
           bytes[2] == 0xFF {

            return .jpeg
        }

        // PNG
        if bytes.count >= 8,
           bytes[0] == 0x89,
           bytes[1] == 0x50,
           bytes[2] == 0x4E,
           bytes[3] == 0x47,
           bytes[4] == 0x0D,
           bytes[5] == 0x0A,
           bytes[6] == 0x1A,
           bytes[7] == 0x0A {

            return .png
        }

        // HEIC / HEIF
        if bytes.count >= 12,
           bytes[4] == 0x66,
           bytes[5] == 0x74,
           bytes[6] == 0x79,
           bytes[7] == 0x70 {

            let brand = String(
                bytes: bytes[8..<12],
                encoding: .ascii
            )

            let supportedBrands: Set<String> = [
                "heic",
                "heix",
                "hevc",
                "hevx",
                "mif1",
                "msf1"
            ]

            if let brand,
               supportedBrands.contains(brand) {

                return .heic
            }
        }

        return nil
    }

    // MARK: - Supabase Configuration

    private func supabaseConfiguration() throws
        -> (
            baseURL: URL,
            secretKey: String,
            bucket: String
        )
    {
        guard
            let urlString =
                Environment.get("SUPABASE_URL"),
            let baseURL =
                URL(string: urlString)
        else {

            throw Abort(
                .internalServerError,
                reason: "SUPABASE_URLが設定されていません。"
            )
        }

        // Secret Keyを優先
        // 旧service_roleも許可
        let secretKey =
            Environment.get("SUPABASE_SECRET_KEY")
            ?? Environment.get(
                "SUPABASE_SERVICE_ROLE_KEY"
            )

        guard
            let secretKey,
            !secretKey.isEmpty
        else {

            throw Abort(
                .internalServerError,
                reason:
                    "SUPABASE_SECRET_KEYまたはSUPABASE_SERVICE_ROLE_KEYが設定されていません。"
            )
        }

        let bucket =
            Environment.get(
                "SUPABASE_KYC_BUCKET"
            )
            ?? "kyc-documents"

        return (
            baseURL,
            secretKey,
            bucket
        )
    }

    // MARK: - Supabase Storage Upload

    private func uploadToSupabaseStorage(
        data: Data,
        bucket: String,
        path: String,
        contentType: String,
        baseURL: URL,
        secretKey: String
    ) async throws {

        let url = try storageObjectURL(
            baseURL: baseURL,
            bucket: bucket,
            path: path
        )

        var request = URLRequest(
            url: url
        )

        request.httpMethod = "POST"

        request.setValue(
            secretKey,
            forHTTPHeaderField: "apikey"
        )

        request.setValue(
            "Bearer \(secretKey)",
            forHTTPHeaderField: "Authorization"
        )

        request.setValue(
            contentType,
            forHTTPHeaderField: "Content-Type"
        )

        request.setValue(
            "false",
            forHTTPHeaderField: "x-upsert"
        )

        request.httpBody = data

        let (data, response) =
            try await URLSession.shared.data(
                for: request
            )

        guard
            let httpResponse =
                response as? HTTPURLResponse
        else {

            throw Abort(
                .badGateway,
                reason:
                    "Supabase Storageから不正なレスポンスが返りました。"
            )
        }

        guard
            (200..<300).contains(
                httpResponse.statusCode
            )
        else {

            let body =
                String(
                    data: data,
                    encoding: .utf8
                )
                ?? "unknown"

            throw Abort(
                .badGateway,
                reason:
                    "Storageへのアップロードに失敗しました。HTTP \(httpResponse.statusCode): \(body)"
            )
        }
    }

    // MARK: - Supabase Storage Delete

    private func deleteFromSupabaseStorage(
        bucket: String,
        path: String,
        baseURL: URL,
        secretKey: String
    ) async throws {

        let url = try storageObjectURL(
            baseURL: baseURL,
            bucket: bucket,
            path: path
        )

        var request = URLRequest(
            url: url
        )

        request.httpMethod = "DELETE"

        request.setValue(
            secretKey,
            forHTTPHeaderField: "apikey"
        )

        request.setValue(
            "Bearer \(secretKey)",
            forHTTPHeaderField: "Authorization"
        )

        let (data, response) =
            try await URLSession.shared.data(
                for: request
            )

        guard
            let httpResponse =
                response as? HTTPURLResponse
        else {

            throw Abort(
                .badGateway,
                reason:
                    "Supabase Storageから不正なレスポンスが返りました。"
            )
        }

        guard
            (200..<300).contains(
                httpResponse.statusCode
            )
        else {

            let body =
                String(
                    data: data,
                    encoding: .utf8
                )
                ?? "unknown"

            throw Abort(
                .badGateway,
                reason:
                    "Storageの削除に失敗しました。HTTP \(httpResponse.statusCode): \(body)"
            )
        }
    }

    // MARK: - Signed URL

    private func createSignedURL(
        bucket: String,
        path: String,
        expiresIn: Int,
        baseURL: URL,
        secretKey: String
    ) async throws -> String {

        let encodedBucket =
            bucket.addingPercentEncoding(
                withAllowedCharacters:
                    .urlPathAllowed
            )
            ?? bucket

        let encodedPath =
            path.addingPercentEncoding(
                withAllowedCharacters:
                    .urlPathAllowed
            )
            ?? path

        let base =
            baseURL.absoluteString
                .trimmingCharacters(
                    in: CharacterSet(
                        charactersIn: "/"
                    )
                )

        guard let url = URL(
            string:
                "\(base)/storage/v1/object/sign/\(encodedBucket)/\(encodedPath)"
        ) else {

            throw Abort(
                .internalServerError,
                reason: "Signed URLの生成URLが不正です。"
            )
        }

        struct SignRequest: Encodable {
            let expiresIn: Int
        }

        struct SignResponse: Decodable {

            let signedURL: String

            enum CodingKeys: String, CodingKey {
                case signedURL = "signedURL"
            }
        }

        var request = URLRequest(
            url: url
        )

        request.httpMethod = "POST"

        request.setValue(
            secretKey,
            forHTTPHeaderField: "apikey"
        )

        request.setValue(
            "Bearer \(secretKey)",
            forHTTPHeaderField: "Authorization"
        )

        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )

        request.httpBody =
            try JSONEncoder().encode(
                SignRequest(
                    expiresIn: expiresIn
                )
            )

        let (data, response) =
            try await URLSession.shared.data(
                for: request
            )

        guard
            let httpResponse =
                response as? HTTPURLResponse
        else {

            throw Abort(
                .badGateway,
                reason:
                    "Supabase Storageから不正なレスポンスが返りました。"
            )
        }

        guard
            (200..<300).contains(
                httpResponse.statusCode
            )
        else {

            let body =
                String(
                    data: data,
                    encoding: .utf8
                )
                ?? "unknown"

            throw Abort(
                .badGateway,
                reason:
                    "Signed URLの生成に失敗しました。HTTP \(httpResponse.statusCode): \(body)"
            )
        }

        let decoded =
            try JSONDecoder().decode(
                SignResponse.self,
                from: data
            )

        // 完全URLならそのまま返す
        if decoded.signedURL.hasPrefix(
            "https://"
        ) || decoded.signedURL.hasPrefix(
            "http://"
        ) {

            return decoded.signedURL
        }

        // 相対URLならSupabase URLを付ける
        if decoded.signedURL.hasPrefix("/") {
            return base + decoded.signedURL
        }

        return base + "/" + decoded.signedURL
    }

    // MARK: - Storage Object URL

    private func storageObjectURL(
        baseURL: URL,
        bucket: String,
        path: String
    ) throws -> URL {

        let encodedBucket =
            bucket.addingPercentEncoding(
                withAllowedCharacters:
                    .urlPathAllowed
            )
            ?? bucket

        let encodedPath =
            path.addingPercentEncoding(
                withAllowedCharacters:
                    .urlPathAllowed
            )
            ?? path

        let base =
            baseURL.absoluteString
                .trimmingCharacters(
                    in: CharacterSet(
                        charactersIn: "/"
                    )
                )

        guard let url = URL(
            string:
                "\(base)/storage/v1/object/\(encodedBucket)/\(encodedPath)"
        ) else {

            throw Abort(
                .internalServerError,
                reason:
                    "Supabase Storage URLが不正です。"
            )
        }

        return url
    }
}

// MARK: - Multipart Request

struct KYCUploadForm: Content, Sendable {

    let documentType: String

    let file: File
}

// MARK: - Response

struct KYCSubmissionResponse: Content, Sendable {

    let id: UUID?

    let userId: UUID?

    let documentType: String?

    let status: String?
}

struct KYCDocumentURLResponse: Content, Sendable {

    let url: String

    let expiresIn: Int
}
