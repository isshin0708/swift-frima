import Vapor
import Fluent

struct NegotiationMessageController: RouteCollection {

    func boot(routes: any RoutesBuilder) throws {

        // ログイン必須
        let protected = routes.grouped(
            SupabaseAuthMiddleware()
        )

        let items = protected.grouped(
            "api",
            "items"
        )

        // メッセージ送信
        items.post(
            ":itemId",
            "messages",
            use: sendMessage
        )
        items.get(
            ":itemId",
            "messages",
            use: getMessages
        )
    }

    @Sendable
    func sendMessage(
        req: Request
    ) async throws -> NegotiationMessage {

        // ログインユーザーを取得
        let user = try req.auth.require(
            AuthenticatedUser.self
        )

        // 商品IDを取得
        guard
            let itemIdString = req.parameters.get("itemId"),
            let itemId = UUID(uuidString: itemIdString)
        else {
            throw Abort(
                .badRequest,
                reason: "商品IDが不正です"
            )
        }

        // リクエスト本文
        let request = try req.content.decode(
            SendNegotiationMessageRequest.self
        )

        // 空メッセージを防止
        let messageText = request.message
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !messageText.isEmpty else {
            throw Abort(
                .badRequest,
                reason: "メッセージを入力してください"
            )
        }

        // 商品が存在するか確認
        guard try await ItemModel.query(on: req.db)
            .filter(\.$id == itemId)
            .first() != nil
        else {
            throw Abort(
                .notFound,
                reason: "商品が見つかりません"
            )
        }

        // メッセージを作成
        let message = NegotiationMessage(
            itemId: itemId,
            senderId: user.id,
            message: messageText
        )

        // DBへ保存
        try await message.save(on: req.db)

        return message
    }
    
    @Sendable
    func getMessages(
        req: Request
    ) async throws -> [NegotiationMessage] {

        // ログインユーザーを取得
        let user = try req.auth.require(
            AuthenticatedUser.self
        )

        // 商品IDを取得
        guard
            let itemIdString = req.parameters.get("itemId"),
            let itemId = UUID(uuidString: itemIdString)
        else {
            throw Abort(
                .badRequest,
                reason: "商品IDが不正です"
            )
        }

        // 商品を取得
        guard let item = try await ItemModel.query(on: req.db)
            .filter(\.$id == itemId)
            .first()
        else {
            throw Abort(
                .notFound,
                reason: "商品が見つかりません"
            )
        }

        // 出品者または購入者だけが閲覧できるようにする
        let isSeller = item.userId == user.id

        let isParticipant = try await NegotiationMessage.query(on: req.db)
            .filter(\.$itemId == itemId)
            .filter(\.$senderId == user.id)
            .first() != nil

        guard isSeller || isParticipant else {
            throw Abort(
                .forbidden,
                reason: "このメッセージを閲覧する権限がありません"
            )
        }

        // 古いメッセージ → 新しいメッセージの順
        return try await NegotiationMessage.query(on: req.db)
            .filter(\.$itemId == itemId)
            .sort(\.$createdAt, .ascending)
            .all()
    }
}


// MARK: - Request

struct SendNegotiationMessageRequest: Content {

    let message: String
}
