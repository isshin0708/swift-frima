import Foundation

public struct Item: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID?
    public var userId: UUID
    public var name: String
    public var description: String
    public var price: Decimal
    public var manufacturerSuggestedRetailPrice: Decimal?
    public var referencePrice: Decimal?
    public var categoryId: Int
    public var status: ItemStatus
    public var imageUrl: String?
    public var createdAt: Date?

    public enum ItemStatus: String, Codable, Sendable {
        case onSale = "on_sale"
        case soldOut = "sold_out"
        case suspended = "suspended"
        case pendingReview = "pending_review"
        case reserved = "reserved"
    }

    enum CodingKeys: String, CodingKey {
        case id, name, description, price, status
        case userId = "user_id"
        case manufacturerSuggestedRetailPrice = "manufacturer_suggested_retail_price"
        case referencePrice = "reference_price"
        case categoryId = "category_id"
        case imageUrl = "image_url"
        case createdAt = "created_at"
    }
}

public struct ItemCreateRequest: Codable, Sendable {
    public let name: String
    public let description: String
    public let price: Decimal
    public let categoryId: Int
    public let imageUrl: String?

    enum CodingKeys: String, CodingKey {
        case name, description, price
        case categoryId = "category_id"
        case imageUrl = "image_url"
    }
}

public struct ItemCreateResponse: Codable, Sendable {
    public let item: Item
    public let isSuspiciousResale: Bool
    public let manufacturerSuggestedRetailPrice: Decimal?
    public let referencePrice: Decimal?
    public let message: String?
}

public struct MarketPriceResult: Codable, Sendable, Equatable {
    public let sampleCount: Int
    public let averageMarketPrice: Decimal?
    public let medianMarketPrice: Decimal?
    public let minPrice: Decimal?
    public let maxPrice: Decimal?
    public let manufacturerSuggestedRetailPrice: Decimal?

    enum CodingKeys: String, CodingKey {
        case sampleCount = "sample_count"
        case averageMarketPrice = "average_market_price"
        case medianMarketPrice = "median_market_price"
        case minPrice = "min_price"
        case maxPrice = "max_price"
        case manufacturerSuggestedRetailPrice = "manufacturer_suggested_retail_price"
    }
}

// MARK: - Order

public struct CreateOrderRequest: Codable, Sendable {
    public let itemId: UUID
    public let price: Decimal

    public init(itemId: UUID, price: Decimal) {
        self.itemId = itemId
        self.price = price
    }
}

public struct OrderResponse: Codable, Sendable {
    public let id: UUID
    public let itemId: UUID
    public let buyerId: UUID
    public let price: Decimal
    public let status: String
    public let paymentIntentId: String?
    public let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case itemId = "item_id"
        case buyerId = "buyer_id"
        case price
        case status
        case paymentIntentId = "payment_intent_id"
        case createdAt = "created_at"
    }
}

public struct PaymentIntentResponse: Codable, Sendable {
    public let paymentIntentId: String
    public let clientSecret: String
    public let amount: Decimal

    enum CodingKeys: String, CodingKey {
        case paymentIntentId = "payment_intent_id"
        case clientSecret = "client_secret"
        case amount
    }
}

public struct PaymentStatusResponse: Codable, Sendable {
    public let orderId: UUID
    public let status: String
    public let paymentIntentId: String?
    public let paidAt: Date?

    enum CodingKeys: String, CodingKey {
        case orderId = "order_id"
        case status
        case paymentIntentId = "payment_intent_id"
        case paidAt = "paid_at"
    }
}

public struct Like: Codable, Sendable, Equatable {
    public let id: UUID
    public let itemId: UUID
    public let userId: UUID
    public let createdAt: Date?

    public init(
        id: UUID,
        itemId: UUID,
        userId: UUID,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.itemId = itemId
        self.userId = userId
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case itemId = "item_id"
        case userId = "user_id"
        case createdAt = "created_at"
    }
}

public struct LikeStatusResponse: Codable, Sendable, Equatable {
    public let isLiked: Bool
    public let likeCount: Int

    public init(
        isLiked: Bool,
        likeCount: Int
    ) {
        self.isLiked = isLiked
        self.likeCount = likeCount
    }

    enum CodingKeys: String, CodingKey {
        case isLiked = "is_liked"
        case likeCount = "like_count"
    }
}
