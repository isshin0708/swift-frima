import Fluent
import Vapor

final class OrderModel: Model, Content {
    static let schema = "orders"

    @ID(key: .id) var id: UUID?
    @Field(key: "item_id") var itemId: UUID
    @Field(key: "buyer_id") var buyerId: UUID
    @Field(key: "price") var price: Decimal
    @Field(key: "status") var status: String
    @OptionalField(key: "payment_intent_id") var paymentIntentId: String?
    @OptionalField(key: "paid_at") var paidAt: Date?
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?

    init() {}

    init(id: UUID? = nil, itemId: UUID, buyerId: UUID, price: Decimal, status: String) {
        self.id = id
        self.itemId = itemId
        self.buyerId = buyerId
        self.price = price
        self.status = status
    }
}
