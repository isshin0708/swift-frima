import Fluent
import Vapor

struct AdminItemController: RouteCollection {

    func boot(routes: any RoutesBuilder) throws {

        let admin = routes
            .grouped(SupabaseAuthMiddleware())
            .grouped(RequireAdminMiddleware())
            .grouped("api", "admin")

        // 商品管理
        admin.get(
            "items",
            use: list
        )

        admin.get(
            "items",
            ":itemId",
            use: detail
        )

        admin.post(
            "items",
            ":itemId",
            "approve",
            use: approve
        )

        admin.delete(
            "items",
            ":itemId",
            use: delete
        )

        // 転売疑い商品
        admin.get(
            "suspicious",
            use: suspicious
        )

        admin.post(
            "suspicious",
            ":itemId",
            "approve",
            use: approveSuspicious
        )

        admin.delete(
            "suspicious",
            ":itemId",
            use: deleteSuspicious
        )
    }

    // MARK: - 商品一覧

    @Sendable
    func list(
        req: Request
    ) async throws -> [Item] {

        let query = ItemModel.query(on: req.db)
            .sort(
                \.$createdAt,
                .descending
            )

        let records = try await query.all()

        return records.map(Self.toItem)
    }

    // MARK: - 商品詳細

    @Sendable
    func detail(
        req: Request
    ) async throws -> Item {

        guard
            let itemIdString = req.parameters.get("itemId"),
            let itemId = UUID(uuidString: itemIdString)
        else {
            throw Abort(
                .badRequest,
                reason: "商品IDが不正です"
            )
        }

        guard
            let item = try await ItemModel.query(on: req.db)
                .filter(\.$id == itemId)
                .first()
        else {
            throw Abort(
                .notFound,
                reason: "商品が見つかりません"
            )
        }

        return Self.toItem(item)
    }

    // MARK: - 商品承認

    @Sendable
    func approve(
        req: Request
    ) async throws -> Item {

        let admin = try req.auth.require(
            AuthenticatedUser.self
        )

        guard
            let itemIdString = req.parameters.get("itemId"),
            let itemId = UUID(uuidString: itemIdString)
        else {
            throw Abort(
                .badRequest,
                reason: "商品IDが不正です"
            )
        }

        guard
            let item = try await ItemModel.query(on: req.db)
                .filter(\.$id == itemId)
                .first()
        else {
            throw Abort(
                .notFound,
                reason: "商品が見つかりません"
            )
        }

        // 審査対象以外を二重承認しない
        guard item.status == "pending_review" else {
            throw Abort(
                .conflict,
                reason: "この商品は審査対象ではありません"
            )
        }

        item.status = "on_sale"

        try await item.save(
            on: req.db
        )

        req.logger.info(
            """
            Admin approved item.
            item=\(itemId)
            admin=\(admin.id)
            """
        )

        return Self.toItem(item)
    }

    // MARK: - 商品強制削除

    @Sendable
    func delete(
        req: Request
    ) async throws -> HTTPStatus {

        let admin = try req.auth.require(
            AuthenticatedUser.self
        )

        guard
            let itemIdString = req.parameters.get("itemId"),
            let itemId = UUID(uuidString: itemIdString)
        else {
            throw Abort(
                .badRequest,
                reason: "商品IDが不正です"
            )
        }

        guard
            let item = try await ItemModel.query(on: req.db)
                .filter(\.$id == itemId)
                .first()
        else {
            throw Abort(
                .notFound,
                reason: "商品が見つかりません"
            )
        }

        try await item.delete(
            on: req.db
        )

        req.logger.info(
            """
            Admin deleted item.
            item=\(itemId)
            admin=\(admin.id)
            """
        )

        return .noContent
    }

    // MARK: - 転売疑い一覧

    @Sendable
    func suspicious(
        req: Request
    ) async throws -> [Item] {

        let records = try await ItemModel.query(on: req.db)
            .filter(
                \.$status == "pending_review"
            )
            .sort(
                \.$createdAt,
                .ascending
            )
            .all()

        return records.map(Self.toItem)
    }

    // MARK: - 転売疑い商品承認

    @Sendable
    func approveSuspicious(
        req: Request
    ) async throws -> Item {

        let admin = try req.auth.require(
            AuthenticatedUser.self
        )

        guard
            let itemIdString = req.parameters.get("itemId"),
            let itemId = UUID(uuidString: itemIdString)
        else {
            throw Abort(
                .badRequest,
                reason: "商品IDが不正です"
            )
        }

        guard
            let item = try await ItemModel.query(on: req.db)
                .filter(\.$id == itemId)
                .first()
        else {
            throw Abort(
                .notFound,
                reason: "商品が見つかりません"
            )
        }

        guard item.status == "pending_review" else {
            throw Abort(
                .conflict,
                reason: "この商品は転売審査中ではありません"
            )
        }

        item.status = "on_sale"

        try await item.save(
            on: req.db
        )

        req.logger.info(
            """
            Suspicious item approved.
            item=\(itemId)
            admin=\(admin.id)
            """
        )

        return Self.toItem(item)
    }

    // MARK: - 転売疑い商品削除

    @Sendable
    func deleteSuspicious(
        req: Request
    ) async throws -> HTTPStatus {

        let admin = try req.auth.require(
            AuthenticatedUser.self
        )

        guard
            let itemIdString = req.parameters.get("itemId"),
            let itemId = UUID(uuidString: itemIdString)
        else {
            throw Abort(
                .badRequest,
                reason: "商品IDが不正です"
            )
        }

        guard
            let item = try await ItemModel.query(on: req.db)
                .filter(\.$id == itemId)
                .first()
        else {
            throw Abort(
                .notFound,
                reason: "商品が見つかりません"
            )
        }

        guard item.status == "pending_review" else {
            throw Abort(
                .conflict,
                reason: "この商品は転売審査中ではありません"
            )
        }

        try await item.delete(
            on: req.db
        )

        req.logger.info(
            """
            Suspicious item deleted.
            item=\(itemId)
            admin=\(admin.id)
            """
        )

        return .noContent
    }

    // MARK: - DTO Conversion

    private static func toItem(
        _ record: ItemModel
    ) -> Item {

        Item(
            id: record.id,
            userId: record.userId,
            name: record.name,
            description: record.itemDescription,
            price: record.price,
            manufacturerSuggestedRetailPrice:
                record.manufacturerSuggestedRetailPrice,
            referencePrice: record.referencePrice,
            categoryId: record.categoryId,
            status:
                Item.ItemStatus(
                    rawValue: record.status
                ) ?? .pendingReview,
            imageUrl: record.imageUrl,
            createdAt: record.createdAt
        )
    }
}
