import Vapor
import Fluent

final class Report: Model, Content, @unchecked Sendable {

    static let schema = "reports"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "reporter_id")
    var reporterId: UUID

    @Field(key: "reported_user_id")
    var reportedUserId: UUID

    @Field(key: "reason")
    var reason: String

    @OptionalField(key: "description")
    var description: String?

    @Field(key: "status")
    var status: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        reporterId: UUID,
        reportedUserId: UUID,
        reason: String,
        description: String? = nil,
        status: String = "pending"
    ) {
        self.id = id
        self.reporterId = reporterId
        self.reportedUserId = reportedUserId
        self.reason = reason
        self.description = description
        self.status = status
    }
}
