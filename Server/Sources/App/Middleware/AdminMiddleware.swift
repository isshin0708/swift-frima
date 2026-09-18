import Vapor
import Fluent

struct AdminMiddleware: AsyncMiddleware {

    func respond(
        to request: Request,
        chainingTo next: any AsyncResponder
    ) async throws -> Response {

        let user = try request.auth.require(AuthenticatedUser.self)

        guard let profile = try await Profile.query(on: request.db)
            .filter(\.$id == user.id)
            .first()
        else {
            throw Abort(
                .forbidden,
                reason: "プロフィールが見つかりません"
            )
        }

        guard profile.role == "admin" else {
            throw Abort(
                .forbidden,
                reason: "管理者権限が必要です"
            )
        }

        return try await next.respond(to: request)
    }
}
