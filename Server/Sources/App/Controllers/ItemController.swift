import Fluent
import Vapor

struct ItemController: RouteCollection {
    static let resaleThreshold: Decimal = Decimal(18) / Decimal(10)
    let marketService = MarketPriceService()

    func boot(routes: RoutesBuilder) throws {

        // 商品一覧の閲覧はログイン不要
        routes.get("api", "items", use: list)

        // 出品にはログインが必要
        routes
            .grouped(SupabaseAuthMiddleware())
            .post("api", "items", use: create)

        // 商品編集
        routes
            .grouped(SupabaseAuthMiddleware())
            .patch("api", "items", ":itemId", use: update)
        
        //商品削除
        routes
            .grouped(SupabaseAuthMiddleware())
            .delete("api", "items", ":itemId", use: delete)
    }

    func list(req: Request) async throws -> [Item] {
        var query = ItemModel.query(on: req.db)
            .filter(\.$status == "on_sale")

        // user_id が指定されている場合は、そのユーザーの商品だけ取得
        if let userIdString = req.query[String.self, at: "user_id"] {
            guard let userId = UUID(uuidString: userIdString) else {
                throw Abort(.badRequest, reason: "user_idが不正です")
            }

            query = query.filter(\.$userId == userId)
        }

        let records = try await query
            .sort(\.$createdAt, .descending)
            .all()

        return records.map(Self.toItem)
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

        guard record.id != nil else { throw Abort(.internalServerError, reason: "商品IDの生成に失敗しました") }
        let item = Self.toItem(record)
        let message = suspicious ? "市場相場の1.8倍以上のため審査待ちです。" : nil
        return ItemCreateResponse(item: item, isSuspiciousResale: suspicious, manufacturerSuggestedRetailPrice: market.manufacturerSuggestedRetailPrice, referencePrice: reference, message: message)
    }
    
    @Sendable
    func update(req: Request) async throws -> Item {
        let user = try req.auth.require(AuthenticatedUser.self)

        // 商品ID
        guard let idString = req.parameters.get("itemId"),
              let itemId = UUID(uuidString: idString) else {
            throw Abort(.badRequest, reason: "商品IDが不正です")
        }

        // 商品取得
        guard let item = try await ItemModel.query(on: req.db)
            .filter(\.$id == itemId)
            .first()
        else {
            throw Abort(.notFound, reason: "商品が見つかりません")
        }

        // 出品者本人か確認
        guard item.userId == user.id else {
            throw Abort(.forbidden, reason: "この商品を編集する権限がありません")
        }

        // 編集内容
        let input = try req.content.decode(ItemUpdateRequest.self)

        let name = input.name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard name.count >= 2, name.count <= 100 else {
            throw Abort(
                .badRequest,
                reason: "商品名は2〜100文字です"
            )
        }

        guard input.price > 0, input.price <= 10_000_000 else {
            throw Abort(.badRequest, reason: "価格が不正です")
        }

        // 参考価格の1.8倍を超える価格への変更を禁止
        if let referencePrice = item.referencePrice,
           referencePrice > 0 {

            let maximumPrice = referencePrice * Self.resaleThreshold

            guard input.price <= maximumPrice else {
                throw Abort(
                    .badRequest,
                    reason: "参考価格の1.8倍を超える価格には変更できません。"
                )
            }
        }

        guard (1...100).contains(input.categoryId) else {
            throw Abort(
                .badRequest,
                reason: "カテゴリが不正です"
            )
        }

        let description = input.description.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard description.count <= 2_000 else {
            throw Abort(
                .badRequest,
                reason: "説明文は2,000文字以内です"
            )
        }

        // 更新
        item.name = name
        item.itemDescription = description
        item.price = input.price
        item.categoryId = input.categoryId
        item.imageUrl = input.imageUrl

        try await item.save(on: req.db)

        return Self.toItem(item)
    }
    
    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(AuthenticatedUser.self)

        guard let idString = req.parameters.get("itemId"),
              let itemId = UUID(uuidString: idString) else {
            throw Abort(.badRequest, reason: "商品IDが不正です")
        }

        guard let item = try await ItemModel.query(on: req.db)
            .filter(\.$id == itemId)
            .first()
        else {
            throw Abort(.notFound, reason: "商品が見つかりません")
        }

        // 自分の商品だけ削除可能
        guard item.userId == user.id else {
            throw Abort(.forbidden, reason: "この商品を削除する権限がありません")
        }

        try await item.delete(on: req.db)

        return .noContent
    }

    private static func toItem(_ record: ItemModel) -> Item {
        Item(
            id: record.id,
            userId: record.userId,
            name: record.name,
            description: record.itemDescription,
            price: record.price,
            manufacturerSuggestedRetailPrice: record.manufacturerSuggestedRetailPrice,
            referencePrice: record.referencePrice,
            categoryId: record.categoryId,
            status: Item.ItemStatus(rawValue: record.status) ?? .pendingReview,
            imageUrl: record.imageUrl,
            createdAt: record.createdAt
        )
    }
}
