import Vapor
import Fluent

struct ReportController: RouteCollection {

    func boot(routes: any RoutesBuilder) throws {

        let protected = routes
            .grouped(SupabaseAuthMiddleware())
            .grouped("api", "reports")

        // ユーザー通報
        protected.post(
            "users",
            use: createUserReport
        )

        // 通報済みか確認
        protected.get(
            "users",
            ":userId",
            "status",
            use: getUserReportStatus
        )
    }

    // MARK: - Create Report

    @Sendable
    func createUserReport(
        req: Request
    ) async throws -> ReportResponse {

        let user = try req.auth.require(
            AuthenticatedUser.self
        )

        let request = try req.content.decode(
            CreateUserReportRequest.self
        )

        // 自分自身への通報を禁止
        guard user.id != request.reportedUserId else {
            throw Abort(
                .badRequest,
                reason: "自分自身を通報することはできません"
            )
        }

        // 通報理由のチェック
        let allowedReasons = [
            "迷惑行為",
            "詐欺・不正行為",
            "不適切な内容",
            "規約違反",
            "その他"
        ]

        guard allowedReasons.contains(request.reason) else {
            throw Abort(
                .badRequest,
                reason: "不正な通報理由です"
            )
        }

        // 通報対象ユーザーの存在確認
        guard try await Profile.query(on: req.db)
            .filter(
                \.$id,
                .equal,
                request.reportedUserId
            )
            .first() != nil
        else {
            throw Abort(
                .notFound,
                reason: "通報対象のユーザーが見つかりません"
            )
        }

        // MARK: - 重複通報チェック

        let alreadyReported = try await Report.query(on: req.db)
            .filter(
                \.$reporterId,
                .equal,
                user.id
            )
            .filter(
                \.$reportedUserId,
                .equal,
                request.reportedUserId
            )
            .first() != nil

        guard !alreadyReported else {
            throw Abort(
                .conflict,
                reason: "このユーザーはすでに通報済みです"
            )
        }

        // MARK: - 保存

        let report = Report(
            reporterId: user.id,
            reportedUserId: request.reportedUserId,
            reason: request.reason,
            description: request.description
        )

        try await report.save(on: req.db)

        return ReportResponse(report: report)
    }

    // MARK: - Check Report Status

    @Sendable
    func getUserReportStatus(
        req: Request
    ) async throws -> UserReportStatusResponse {

        let user = try req.auth.require(
            AuthenticatedUser.self
        )

        guard let userIdString = req.parameters.get("userId"),
              let reportedUserId = UUID(
                uuidString: userIdString
              )
        else {
            throw Abort(
                .badRequest,
                reason: "ユーザーIDが不正です"
            )
        }

        let alreadyReported = try await Report.query(on: req.db)
            .filter(
                \.$reporterId,
                .equal,
                user.id
            )
            .filter(
                \.$reportedUserId,
                .equal,
                reportedUserId
            )
            .first() != nil

        return UserReportStatusResponse(
            reported: alreadyReported
        )
    }
}

// MARK: - Create User Report Request

struct CreateUserReportRequest: Content {

    let reportedUserId: UUID
    let reason: String
    let description: String?

    enum CodingKeys: String, CodingKey {

        case reportedUserId = "reported_user_id"
        case reason
        case description
    }
}

// MARK: - Report Response

struct ReportResponse: Content {

    let id: UUID?
    let reporterId: UUID
    let reportedUserId: UUID
    let reason: String
    let description: String?
    let status: String
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {

        case id
        case reporterId = "reporter_id"
        case reportedUserId = "reported_user_id"
        case reason
        case description
        case status
        case createdAt = "created_at"
    }

    init(report: Report) {

        self.id = report.id
        self.reporterId = report.reporterId
        self.reportedUserId = report.reportedUserId
        self.reason = report.reason
        self.description = report.description
        self.status = report.status
        self.createdAt = report.createdAt
    }
}

// MARK: - Report Status Response

struct UserReportStatusResponse: Content {

    let reported: Bool
}
