import Fluent
import Vapor

struct ItemController: RouteCollection {
    static let resaleThreshold: Decimal = Decimal(18) / Decimal(10)
    let marketService = MarketPriceService()

    func boot(routes: RoutesBuilder) throws {
        routes.grouped(SupabaseAuthMiddleware()).post("api", "items", use: create)
    }

    func create(req: Request) async throws -> ItemCreateResponse {
        let user = try req.auth.require(AuthenticatedUser.self)
        let input = try req.content.decode(ItemCreateRequest.self)
        let name = input.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.count >= 2, name.count <= 100 else { throw Abort(.badRequest, reason: "商品名は2〜100文字です") }
        guard input.price > 0, input.price <= 10_000_000 else { throw Abort(.badRequest, reason: "価格が不正です") }
        guard (1...100).contains(input.categoryId) else { throw Abort(.badRequest, reason: "カテゴリが不正です") }
        let description = input.description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard description.count <= 2_000 else { throw Abort(.badRequest, reason: "説明文は2,000文字以内です") }

        let market = try await marketService.search(query: name, on: req)
        let reference = market.medianMarketPrice ?? market.averageMarketPrice
        let suspicious = if let reference, reference > 0 { input.price >= reference * Self.resaleThreshold } else { false }
        let status = suspicious ? "pending_review" : "on_sale"

        let record = ItemModel(userId: user.id, name: name, description: description, price: input.price, manufacturerSuggestedRetailPrice: market.manufacturerSuggestedRetailPrice, referencePrice: reference, categoryId: input.categoryId, status: status, imageUrl: input.imageUrl)
        try await record.create(on: req.db)

        guard let id = record.id else { throw Abort(.internalServerError, reason: "商品IDの生成に失敗しました") }
        let item = Item(id: id, userId: user.id, name: record.name, description: record.itemDescription, price: record.price, manufacturerSuggestedRetailPrice: record.manufacturerSuggestedRetailPrice, referencePrice: record.referencePrice, categoryId: record.categoryId, status: Item.ItemStatus(rawValue: record.status) ?? .pendingReview, imageUrl: record.imageUrl, createdAt: record.createdAt)
        let message = suspicious ? "市場相場の1.8倍以上のため審査待ちです。" : nil
        return ItemCreateResponse(item: item, isSuspiciousResale: suspicious, manufacturerSuggestedRetailPrice: market.manufacturerSuggestedRetailPrice, referencePrice: reference, message: message)
    }
}
