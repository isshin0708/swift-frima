import Foundation
import Vapor

public struct Item: Identifiable, Content, Sendable, Equatable {
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

public struct ItemUpdateRequest: Codable, Sendable {
    public let name: String
    public let description: String
    public let price: Decimal
    public let categoryId: Int
    public let imageUrl: String?

    public init(
        name: String,
        description: String,
        price: Decimal,
        categoryId: Int,
        imageUrl: String?
    ) {
        self.name = name
        self.description = description
        self.price = price
        self.categoryId = categoryId
        self.imageUrl = imageUrl
    }

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case price
        case categoryId = "category_id"
        case imageUrl = "image_url"
    }
}

public struct ItemCreateResponse: Content, Sendable {
    public let item: Item
    public let isSuspiciousResale: Bool
    public let manufacturerSuggestedRetailPrice: Decimal?
    public let referencePrice: Decimal?
    public let message: String?
}

public struct CreateOrderRequest: Codable, Sendable {
    public let itemId: UUID
    enum CodingKeys: String, CodingKey { case itemId = "item_id" }
}

public struct OrderResponse: Content, Sendable {
    public let orderId: UUID
    public let status: String
    public let message: String?
    public let paymentIntentClientSecret: String?

    enum CodingKeys: String, CodingKey {
        case orderId = "order_id"
        case status, message
        case paymentIntentClientSecret = "payment_intent_client_secret"
    }
}

public struct PaymentIntentResponse: Content, Sendable {
    public let orderId: UUID
    public let paymentIntentId: String
    public let clientSecret: String

    enum CodingKeys: String, CodingKey {
        case orderId = "order_id"
        case paymentIntentId = "payment_intent_id"
        case clientSecret = "client_secret"
    }
}

public struct PaymentStatusResponse: Content, Sendable {
    public let orderId: UUID
    public let orderStatus: String
    public let itemStatus: String

    enum CodingKeys: String, CodingKey {
        case orderId = "order_id"
        case orderStatus = "order_status"
        case itemStatus = "item_status"
    }
}

public struct MarketPriceResult: Content, Sendable, Equatable {
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

public struct LikeStatusResponse: Content, Sendable {
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
