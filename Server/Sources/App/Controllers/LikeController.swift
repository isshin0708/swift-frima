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
}
