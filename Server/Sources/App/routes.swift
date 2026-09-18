import Vapor

func routes(_ app: Application) throws {

    // サーバー起動確認
    app.get("health") { req async -> [String: String] in
        [
            "status": "ok",
            "app": "swift-frima"
        ]
    }

    // API
    try app.register(collection: MarketPriceController())
    try app.register(collection: ItemController())
    try app.register(collection: OrderController())
    try app.register(collection: StripeWebhookController())
    try app.register(collection: LikeController())
    try app.register(collection: ProfileController())
    try app.register(collection: NegotiationMessageController())
    try app.register(collection: AdminUserController())
    try app.register(collection: ReportController())
    try app.register(collection: AdminReportController())
}
