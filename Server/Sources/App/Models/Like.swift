import Vapor
import Fluent

final class Like: Model, Content, @unchecked Sendable {
    static let schema = "likes"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "item_id")
    var itemId: UUID

    @Field(key: "user_id")
    var userId: UUID

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        itemId: UUID,
        userId: UUID
    ) {
        self.id = id
        self.itemId = itemId
        self.userId = userId
    }
}
