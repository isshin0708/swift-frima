import Fluent
import Vapor

final class ItemModel: Model, Content {
    static let schema = "items"
    @ID(key: .id) var id: UUID?
    @Field(key: "user_id") var userId: UUID
    @Field(key: "name") var name: String
    @Field(key: "description") var itemDescription: String
    @Field(key: "price") var price: Decimal
    @OptionalField(key: "manufacturer_suggested_retail_price") var manufacturerSuggestedRetailPrice: Decimal?
    @OptionalField(key: "reference_price") var referencePrice: Decimal?
    @Field(key: "category_id") var categoryId: Int
    @Field(key: "status") var status: String
    @OptionalField(key: "image_url") var imageUrl: String?
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?

    init() {}
    init(id: UUID? = nil, userId: UUID, name: String, description: String, price: Decimal, manufacturerSuggestedRetailPrice: Decimal?, referencePrice: Decimal?, categoryId: Int, status: String, imageUrl: String?) {
        self.id = id; self.userId = userId; self.name = name; self.itemDescription = description; self.price = price
        self.manufacturerSuggestedRetailPrice = manufacturerSuggestedRetailPrice; self.referencePrice = referencePrice
        self.categoryId = categoryId; self.status = status; self.imageUrl = imageUrl
    }
}
