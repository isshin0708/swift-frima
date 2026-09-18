import Vapor

struct AuthenticatedUser: Authenticatable, Sendable {
    let id: UUID
    let isAdmin: Bool
}

struct SupabaseAuthMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        guard let header = request.headers.bearerAuthorization else { throw Abort(.unauthorized, reason: "Authorization Bearer token is required") }
        guard let base = Environment.get("SUPABASE_URL"), let key = Environment.get("SUPABASE_PUBLISHABLE_KEY") else {
            request.logger.error("SUPABASE_URL or SUPABASE_PUBLISHABLE_KEY is missing")
            throw Abort(.internalServerError, reason: "認証設定が不足しています")
        }
        guard let url = URL(string: base.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/auth/v1/user") else { throw Abort(.internalServerError) }
        var headers = HTTPHeaders()
        headers.bearerAuthorization = header
        headers.replaceOrAdd(name: "apikey", value: key)
        let response = try await request.client.get(URI(string: url.absoluteString), headers: headers)
        guard response.status == .ok else { throw Abort(.unauthorized, reason: "ログインセッションが無効です") }
        let user = try response.content.decode(SupabaseUser.self)
        guard let uuid = UUID(uuidString: user.id) else { throw Abort(.unauthorized, reason: "ユーザーIDが不正です") }
        let isAdmin = user.appMetadata?.role == "admin"

        // アカウント状態を確認
        guard let profile = try await Profile.query(on: request.db)
            .filter(\.$id, .equal, uuid)
            .first()
        else {
            throw Abort(
                .forbidden,
                reason: "プロフィールが見つかりません"
            )
        }

        // 一時停止・BANチェック
        switch profile.accountStatus {

        case "suspended":
            throw Abort(
                .forbidden,
                reason: "このアカウントは一時停止されています"
            )

        case "banned":
            throw Abort(
                .forbidden,
                reason: "このアカウントはBANされています"
            )

        case "active":
            break

        default:
            throw Abort(
                .forbidden,
                reason: "アカウント状態が不正です"
            )
        }

        request.auth.login(
            AuthenticatedUser(
                id: uuid,
                isAdmin: isAdmin
            )
        )

        return try await next.respond(to: request)
    }
}

/// 管理者専用エンドポイントの手前に挟むミドルウェア。
/// SupabaseAuthMiddlewareの後段で使うこと(先にAuthenticatedUserがログイン済みである必要がある)。
struct RequireAdminMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        let user = try request.auth.require(AuthenticatedUser.self)
        guard user.isAdmin else {
            throw Abort(.forbidden, reason: "管理者権限が必要です")
        }
        return try await next.respond(to: request)
    }
}

private struct SupabaseUser: Content {
    let id: String
    let appMetadata: AppMetadata?

    enum CodingKeys: String, CodingKey {
        case id
        case appMetadata = "app_metadata"
    }

    struct AppMetadata: Codable, Sendable {
        let role: String?
    }
}
