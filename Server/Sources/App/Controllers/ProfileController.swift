import Vapor
import Fluent

struct ProfileController: RouteCollection {

    func boot(routes: any RoutesBuilder) throws {

        let profiles = routes.grouped("api", "profiles")

        profiles.get(":id", use: getProfile)
    }

    @Sendable
    func getProfile(req: Request) async throws -> Profile {

        guard let idString = req.parameters.get("id"),
              let id = UUID(uuidString: idString) else {
            throw Abort(
                .badRequest,
                reason: "ユーザーIDが不正です"
            )
        }

        guard let profile = try await Profile.query(on: req.db)
            .filter(\.$id == id)
            .first()
        else {
            throw Abort(
                .notFound,
                reason: "プロフィールが見つかりません"
            )
        }

        return profile
    }
}
