import Vapor
import Fluent

final class Profile: Model, Content, @unchecked Sendable {

    static let schema = "profiles"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "username")
    var username: String

    @Field(key: "role")
    var role: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        username: String,
        role: String
    ) {
        self.id = id
        self.username = username
        self.role = role
    }
}
