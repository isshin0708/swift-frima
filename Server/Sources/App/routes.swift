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
}
