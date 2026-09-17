import Vapor
import Fluent

struct LikeController: RouteCollection {

    func boot(routes: any RoutesBuilder) throws {
        let protected = routes.grouped(SupabaseAuthMiddleware())
        let items = protected.grouped("api", "items")

        items.post(":itemId", "like", use: like)
        items.get(":itemId", "like", use: status)
    }

    // いいねする
    @Sendable
    func like(req: Request) async throws -> LikeStatusResponse {
        let user = try req.auth.require(AuthenticatedUser.self)

        guard let itemIdString = req.parameters.get("itemId"),
              let itemId = UUID(uuidString: itemIdString) else {
            throw Abort(.badRequest, reason: "商品IDが不正です")
        }

        // 商品が存在するか確認
        guard try await ItemModel.query(on: req.db)
            .filter(\.$id == itemId)
            .first() != nil else {
            throw Abort(.notFound, reason: "商品が見つかりません")
        }

        // すでにいいねしているか確認
        let existingLike = try await Like.query(on: req.db)
            .filter(\.$itemId == itemId)
            .filter(\.$userId == user.id)
            .first()

        if existingLike == nil {
            let newLike = Like(
                itemId: itemId,
                userId: user.id
            )

            try await newLike.save(on: req.db)
        }

        let likeCount = try await Like.query(on: req.db)
            .filter(\.$itemId == itemId)
            .count()

        return LikeStatusResponse(
            isLiked: true,
            likeCount: likeCount
        )
    }

    // いいね状態を取得
    @Sendable
    func status(req: Request) async throws -> LikeStatusResponse {
        let user = try req.auth.require(AuthenticatedUser.self)

        guard let itemIdString = req.parameters.get("itemId"),
              let itemId = UUID(uuidString: itemIdString) else {
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
}
