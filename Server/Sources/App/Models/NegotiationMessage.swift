import Vapor
import Fluent

final class NegotiationMessage: Model, Content, @unchecked Sendable {

    static let schema = "negotiation_messages"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "item_id")
    var itemId: UUID

    @Field(key: "sender_id")
    var senderId: UUID

    @Field(key: "message")
    var message: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case itemId = "item_id"
        case senderId = "sender_id"
        case message
        case createdAt = "created_at"
    }

    init() {}

    init(
        id: UUID? = nil,
        itemId: UUID,
        senderId: UUID,
        message: String
    ) {
        self.id = id
        self.itemId = itemId
        self.senderId = senderId
        self.message = message
    }
}
