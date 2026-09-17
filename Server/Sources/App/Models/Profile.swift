import Vapor
import Fluent

final class Profile: Model, Content, @unchecked Sendable {

    static let schema = "profiles"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "user_name")
    var userName: String

    @Field(key: "role")
    var role: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        userName: String,
        role: String
    ) {
        self.id = id
        self.userName = userName
        self.role = role
    }
}
