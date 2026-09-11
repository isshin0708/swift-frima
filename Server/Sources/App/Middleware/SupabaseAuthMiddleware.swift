import Vapor

struct AuthenticatedUser: Authenticatable, Sendable {
    let id: UUID
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
        request.auth.login(AuthenticatedUser(id: uuid))
        return try await next.respond(to: request)
    }
}

private struct SupabaseUser: Content { let id: String }
