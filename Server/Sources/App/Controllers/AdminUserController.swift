import Vapor
import Fluent

struct AdminUserController: RouteCollection {

    func boot(routes: any RoutesBuilder) throws {

        let admin = routes
            .grouped(SupabaseAuthMiddleware())
            .grouped(RequireAdminMiddleware())
            .grouped("api", "admin", "users")

        // ユーザー一覧
        admin.get(
            use: getUsers
        )

        // ユーザー1件取得
        admin.get(
            ":id",
            use: getUser
        )

        // アカウント状態変更
        admin.patch(
            ":id",
            "status",
            use: updateStatus
        )
    }

    // MARK: - Get Users

    @Sendable
    func getUsers(
        req: Request
    ) async throws -> [AdminUserResponse] {

        _ = try req.auth.require(
            AuthenticatedUser.self
        )

        let profiles = try await Profile.query(on: req.db)
            .sort(
                \.$createdAt,
                .descending
            )
            .all()

        return profiles.map {
            AdminUserResponse(
                profile: $0
            )
        }
    }

    // MARK: - Get User

    @Sendable
    func getUser(
        req: Request
    ) async throws -> AdminUserResponse {

        _ = try req.auth.require(
            AuthenticatedUser.self
        )

        guard let idString = req.parameters.get("id"),
              let id = UUID(uuidString: idString) else {

            throw Abort(
                .badRequest,
                reason: "ユーザーIDが不正です"
            )
        }

        guard let profile = try await Profile.query(on: req.db)
            .filter(
                \.$id,
                .equal,
                id
            )
            .first()
        else {

            throw Abort(
                .notFound,
                reason: "ユーザーが見つかりません"
            )
        }

        return AdminUserResponse(
            profile: profile
        )
    }

    // MARK: - Update Status

    @Sendable
    func updateStatus(
        req: Request
    ) async throws -> AdminUserResponse {

        _ = try req.auth.require(
            AuthenticatedUser.self
        )

        guard let idString = req.parameters.get("id"),
              let id = UUID(uuidString: idString) else {

            throw Abort(
                .badRequest,
                reason: "ユーザーIDが不正です"
            )
        }

        let request =
            try req.content.decode(
                UpdateAccountStatusRequest.self
            )

        let allowedStatuses = [
            "active",
            "suspended",
            "banned"
        ]

        guard allowedStatuses.contains(
            request.status
        ) else {

            throw Abort(
                .badRequest,
                reason: "不正なアカウント状態です"
            )
        }

        guard let profile = try await Profile.query(on: req.db)
            .filter(
                \.$id,
                .equal,
                id
            )
            .first()
        else {

            throw Abort(
                .notFound,
                reason: "ユーザーが見つかりません"
            )
        }

        profile.accountStatus = request.status

        try await profile.save(
            on: req.db
        )

        return AdminUserResponse(
            profile: profile
        )
    }
}

// MARK: - Update Account Status Request

struct UpdateAccountStatusRequest: Content {

    let status: String
}

// MARK: - Admin User Response

struct AdminUserResponse: Content {

    let id: UUID?
    let userName: String
    let role: String
    let accountStatus: String
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {

        case id
        case userName = "user_name"
        case role
        case accountStatus = "account_status"
        case createdAt = "created_at"
    }

    init(profile: Profile) {

        self.id = profile.id
        self.userName = profile.username
        self.role = profile.role
        self.accountStatus = profile.accountStatus
        self.createdAt = profile.createdAt
    }
}
