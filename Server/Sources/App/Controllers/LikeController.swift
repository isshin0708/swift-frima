import Vapor
import Fluent

struct LikeController: RouteCollection {

    func boot(routes: any RoutesBuilder) throws {
        let protected = routes.grouped(SupabaseAuthMiddleware())
        let items = protected.grouped("api", "items")

        // いいね
        items.post(":itemId", "like", use: like)

        // いいね状態取得
        items.get(":itemId", "like", use: status)

        // いいね解除
        items.delete(":itemId", "like", use: unlike)
        
        let api = protected.grouped("api")

        api.get(
            "users",
            "me",
            "likes",
            use: getMyLikedItems
        )
    }

    // MARK: - いいねする

    @Sendable
    func like(req: Request) async throws -> LikeStatusResponse {
        let user = try req.auth.require(AuthenticatedUser.self)

        guard
            let itemIdString = req.parameters.get("itemId"),
            let itemId = UUID(uuidString: itemIdString)
        else {
            throw Abort(.badRequest, reason: "商品IDが不正です")
        }

        // 商品が存在するか確認
        guard
            try await ItemModel.query(on: req.db)
                .filter(\.$id == itemId)
                .first() != nil
        else {
            throw Abort(.notFound, reason: "商品が見つかりません")
        }

        // すでにいいねしているか確認
        let existingLike = try await Like.query(on: req.db)
            .filter(\.$itemId == itemId)
            .filter(\.$userId == user.id)
            .first()

        // まだいいねしていなければ追加
        if existingLike == nil {
            let newLike = Like(
                itemId: itemId,
                userId: user.id
            )

            try await newLike.save(on: req.db)
        }

        // 最新のいいね数を取得
        let likeCount = try await Like.query(on: req.db)
            .filter(\.$itemId == itemId)
            .count()

        return LikeStatusResponse(
            isLiked: true,
            likeCount: likeCount
        )
    }

    // MARK: - いいね解除

    @Sendable
    func unlike(req: Request) async throws -> LikeStatusResponse {
        let user = try req.auth.require(AuthenticatedUser.self)

        guard
            let itemIdString = req.parameters.get("itemId"),
            let itemId = UUID(uuidString: itemIdString)
        else {
            throw Abort(.badRequest, reason: "商品IDが不正です")
        }

        // 商品が存在するか確認
        guard
            try await ItemModel.query(on: req.db)
                .filter(\.$id == itemId)
                .first() != nil
        else {
            throw Abort(.notFound, reason: "商品が見つかりません")
        }

        // 自分のいいねを取得
        let existingLike = try await Like.query(on: req.db)
            .filter(\.$itemId == itemId)
            .filter(\.$userId == user.id)
            .first()

        // いいねが存在すれば削除
        if let existingLike {
            try await existingLike.delete(on: req.db)
        }

        // 最新のいいね数を取得
        let likeCount = try await Like.query(on: req.db)
            .filter(\.$itemId == itemId)
            .count()

        return LikeStatusResponse(
            isLiked: false,
            likeCount: likeCount
        )
    }

    // MARK: - いいね状態を取得

    @Sendable
    func status(req: Request) async throws -> LikeStatusResponse {
        let user = try req.auth.require(AuthenticatedUser.self)

        guard
            let itemIdString = req.parameters.get("itemId"),
            let itemId = UUID(uuidString: itemIdString)
        else {
            throw Abort(.badRequest, reason: "商品IDが不正です")
        }

        let existingLike = try await Like.query(on: req.db)
            .filter(\.$itemId == itemId)
            .filter(\.$userId == user.id)
            .first()

        let likeCount = try await Like.query(on: req.db)
            .filter(\.$itemId == itemId)
            .count()

        return LikeStatusResponse(
            isLiked: existingLike != nil,
            likeCount: likeCount
        )
    }
    
    @Sendable
    func getMyLikedItems(req: Request) async throws -> [LikedItemResponse] {
        let user = try req.auth.require(AuthenticatedUser.self)

        let likes = try await Like.query(on: req.db)
            .filter(\.$userId == user.id)
            .sort(\.$createdAt, .descending)
            .all()

        var result: [LikedItemResponse] = []

        for like in likes {
            guard let item = try await ItemModel.query(on: req.db)
                .filter(\.$id == like.itemId)
                .first()
            else {
                continue
            }

            guard let itemId = item.id else {
                continue
            }

            let response = LikedItemResponse(
                id: itemId,
                userId: item.userId,
                name: item.name,
                description: item.description,
                price: item.price,
                manufacturerSuggestedRetailPrice: item.manufacturerSuggestedRetailPrice,
                referencePrice: item.referencePrice,
                categoryId: item.categoryId,
                status: item.status,
                imageUrl: item.imageUrl,
                createdAt: item.createdAt
            )

            result.append(response)
        }

        return result
    }
}

struct LikedItemResponse: Content {
    let id: UUID
    let userId: UUID
    let name: String
    let description: String
    let price: Decimal
    let manufacturerSuggestedRetailPrice: Decimal?
    let referencePrice: Decimal?
    let categoryId: Int
    let status: String
    let imageUrl: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case description
        case price
        case manufacturerSuggestedRetailPrice = "manufacturer_suggested_retail_price"
        case referencePrice = "reference_price"
        case categoryId = "category_id"
        case status
        case imageUrl = "image_url"
        case createdAt = "created_at"
    }
}
