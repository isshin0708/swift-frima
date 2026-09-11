import Fluent
import Vapor

struct OrderController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let authenticated = routes.grouped(SupabaseAuthMiddleware())
        authenticated.post("api", "orders", use: create)
        authenticated.post("api", "orders", ":orderId", "payment-intent", use: createPaymentIntent)
        authenticated.post("api", "orders", ":orderId", "cancel", use: cancel)
        authenticated.get("api", "orders", ":orderId", "status", use: status)
    }

    func create(req: Request) async throws -> OrderResponse {
        let buyer = try req.auth.require(AuthenticatedUser.self)
        let input = try req.content.decode(CreateOrderRequest.self)

        do {
            let order = try await req.db.transaction { db -> OrderModel in
                guard let item = try await ItemModel.find(input.itemId, on: db) else {
                    throw Abort(.notFound, reason: "商品が見つかりません")
                }
                guard item.userId != buyer.id else {
                    throw Abort(.badRequest, reason: "自分の出品物は購入できません")
                }
                guard item.status == "on_sale" else {
                    throw Abort(.conflict, reason: "この商品は現在購入できません")
                }

                item.status = "reserved"
                try await item.save(on: db)

                let order = OrderModel(
                    itemId: try item.requireID(),
                    buyerId: buyer.id,
                    price: item.price,
                    status: "pending_payment"
                )
                try await order.create(on: db)
                return order
            }

            return OrderResponse(
                orderId: try order.requireID(),
                status: order.status,
                message: "注文を作成しました。決済へ進みます。",
                paymentIntentClientSecret: nil
            )
        } catch let error as AbortError {
            throw error
        } catch {
            req.logger.error("注文作成失敗: \\(error)")
            throw Abort(.conflict, reason: "この商品は別の購入者が先に確保した可能性があります")
        }
    }

    func createPaymentIntent(req: Request) async throws -> PaymentIntentResponse {
        let buyer = try req.auth.require(AuthenticatedUser.self)
        guard let orderId = req.parameters.get("orderId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "orderIdが不正です")
        }
        guard let order = try await OrderModel.find(orderId, on: req.db) else {
            throw Abort(.notFound, reason: "注文が見つかりません")
        }
        guard order.buyerId == buyer.id else { throw Abort(.forbidden) }
        guard order.status == "pending_payment" else {
            throw Abort(.conflict, reason: "この注文は決済待ちではありません")
        }

        if let existing = order.paymentIntentId {
            let intent = try await StripeService().retrievePaymentIntent(req: req, id: existing)
            guard intent.status != "canceled" else {
                throw Abort(.conflict, reason: "この決済はキャンセルされています。注文を作り直してください")
            }
            return PaymentIntentResponse(orderId: orderId, paymentIntentId: intent.id, clientSecret: intent.clientSecret)
        }

        let intent = try await StripeService().createPaymentIntent(req: req, amountJPY: order.price, orderId: orderId)
        order.paymentIntentId = intent.id
        do {
            try await order.save(on: req.db)
        } catch {
            try? await StripeService().cancelPaymentIntent(req: req, id: intent.id)
            throw Abort(.internalServerError, reason: "決済情報の保存に失敗しました")
        }

        return PaymentIntentResponse(orderId: orderId, paymentIntentId: intent.id, clientSecret: intent.clientSecret)
    }

    func cancel(req: Request) async throws -> HTTPStatus {
        let buyer = try req.auth.require(AuthenticatedUser.self)
        guard let orderId = req.parameters.get("orderId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "orderIdが不正です")
        }
        guard let order = try await OrderModel.find(orderId, on: req.db) else {
            throw Abort(.notFound, reason: "注文が見つかりません")
        }
        guard order.buyerId == buyer.id else { throw Abort(.forbidden) }
        guard order.status == "pending_payment" else { return .ok }

        if let paymentIntentId = order.paymentIntentId {
            try? await StripeService().cancelPaymentIntent(req: req, id: paymentIntentId)
        }

        try await req.db.transaction { db in
            guard let locked = try await OrderModel.find(orderId, on: db) else { return }
            guard locked.status == "pending_payment" else { return }
            locked.status = "canceled"
            if let item = try await ItemModel.find(locked.itemId, on: db), item.status == "reserved" {
                item.status = "on_sale"
                try await item.save(on: db)
            }
            try await locked.save(on: db)
        }
        return .ok
    }

    func status(req: Request) async throws -> PaymentStatusResponse {
        let buyer = try req.auth.require(AuthenticatedUser.self)
        guard let orderId = req.parameters.get("orderId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "orderIdが不正です")
        }
        guard let order = try await OrderModel.find(orderId, on: req.db) else {
            throw Abort(.notFound, reason: "注文が見つかりません")
        }
        guard order.buyerId == buyer.id else { throw Abort(.forbidden) }
        guard let item = try await ItemModel.find(order.itemId, on: req.db) else {
            throw Abort(.internalServerError, reason: "商品データが壊れています")
        }
        return PaymentStatusResponse(orderId: orderId, orderStatus: order.status, itemStatus: item.status)
    }
}
