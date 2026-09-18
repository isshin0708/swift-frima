import Vapor
import Fluent

struct AdminReportController: RouteCollection {

    func boot(routes: any RoutesBuilder) throws {

        let admin = routes
            .grouped(SupabaseAuthMiddleware())
            .grouped(RequireAdminMiddleware())
            .grouped("api", "admin", "reports")

        // 通報されたユーザーを
        // 通報件数の多い順に取得
        admin.get(
            "users",
            use: getReportedUsers
        )

        // 特定ユーザーへの通報内容を取得
        admin.get(
            "users",
            ":userId",
            use: getUserReports
        )
    }

    // MARK: - Get Reported Users

    @Sendable
    func getReportedUsers(
        req: Request
    ) async throws -> [AdminReportedUserResponse] {

        _ = try req.auth.require(
            AuthenticatedUser.self
        )

        // reportsをすべて取得
        let reports = try await Report.query(on: req.db)
            .all()

        // ユーザーごとの通報件数を集計
        var reportCounts: [UUID: Int] = [:]

        for report in reports {
            reportCounts[report.reportedUserId, default: 0] += 1
        }

        // 通報件数の多い順にユーザーIDを並べる
        let sortedUserIds = reportCounts
            .sorted {
                if $0.value != $1.value {
                    return $0.value > $1.value
                }

                return $0.key.uuidString < $1.key.uuidString
            }
            .map {
                $0.key
            }

        var result: [AdminReportedUserResponse] = []

        // ユーザーごとにプロフィールを取得
        for userId in sortedUserIds {

            guard let profile = try await Profile.query(on: req.db)
                .filter(
                    \.$id,
                    .equal,
                    userId
                )
                .first()
            else {
                continue
            }

            let reportCount = reportCounts[userId] ?? 0

            result.append(
                AdminReportedUserResponse(
                    id: userId,
                    userName: profile.username,
                    reportCount: reportCount,
                    accountStatus: profile.accountStatus
                )
            )
        }

        return result
    }
    // MARK: - Get User Reports

    @Sendable
    func getUserReports(
        req: Request
    ) async throws -> [AdminReportResponse] {

        _ = try req.auth.require(
            AuthenticatedUser.self
        )

        guard let userIdString = req.parameters.get("userId"),
              let userId = UUID(uuidString: userIdString) else {

            throw Abort(
                .badRequest,
                reason: "ユーザーIDが不正です"
            )
        }

        // 指定されたユーザーへの通報を取得
        let reports = try await Report.query(on: req.db)
            .filter(
                \.$reportedUserId,
                .equal,
                userId
            )
            .sort(
                \.$createdAt,
                .descending
            )
            .all()

        return reports.map {
            AdminReportResponse(report: $0)
        }
    }
}

// MARK: - Reported User Response

struct AdminReportedUserResponse: Content {

    let id: UUID
    let userName: String
    let reportCount: Int
    let accountStatus: String

    enum CodingKeys: String, CodingKey {

        case id
        case userName = "user_name"
        case reportCount = "report_count"
        case accountStatus = "account_status"
    }
}

// MARK: - Report Response

struct AdminReportResponse: Content {

    let id: UUID
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

        guard let id = report.id else {
            fatalError("Report ID is missing")
        }

        self.id = id
        self.reporterId = report.reporterId
        self.reportedUserId = report.reportedUserId
        self.reason = report.reason
        self.description = report.description
        self.status = report.status
        self.createdAt = report.createdAt
    }
}
