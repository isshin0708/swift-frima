import Fluent
import Crypto
import Vapor

struct StripeWebhookController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.post("api", "stripe", "webhook", use: webhook)
    }

    func webhook(req: Request) async throws -> HTTPStatus {
        guard let secret = Environment.get("STRIPE_WEBHOOK_SECRET"), !secret.isEmpty else {
            throw Abort(.internalServerError, reason: "STRIPE_WEBHOOK_SECRET is not configured")
        }
        guard let signature = req.headers.first(name: "Stripe-Signature") else {
            throw Abort(.unauthorized, reason: "Stripe-Signatureがありません")
        }
        let payload = try await req.body.collect(upTo: 2 * 1024 * 1024)
        let body = String(buffer: payload)
        try verify(signature: signature, payload: body, secret: secret)

        let event = try JSONDecoder().decode(StripeEvent.self, from: Data(body.utf8))
        switch event.type {
        case "payment_intent.succeeded":
            try await handleSucceeded(req: req, event: event)
        case "payment_intent.payment_failed", "payment_intent.canceled":
            try await handleCanceled(req: req, event: event)
        default:
            break
        }
        return .ok
    }

    private func handleSucceeded(req: Request, event: StripeEvent) async throws {
        let paymentIntent = event.data.object
        guard let order = try await OrderModel.query(on: req.db).filter(\.$paymentIntentId == paymentIntent.id).first() else {
            req.logger.warning("Stripe payment intentに対応する注文がありません: \(paymentIntent.id)")
            return
        }
        try await req.db.transaction { db in
            guard let locked = try await OrderModel.find(order.requireID(), on: db) else { return }
            guard locked.status == "pending_payment" else { return }
            guard let item = try await ItemModel.find(locked.itemId, on: db) else {
                throw Abort(.internalServerError, reason: "注文の商品が見つかりません")
            }
            guard item.status == "reserved" else {
                throw Abort(.conflict, reason: "商品状態が不正です")
            }
            locked.status = "paid"
            locked.paidAt = Date()
            item.status = "sold_out"
            try await locked.save(on: db)
            try await item.save(on: db)
        }
    }

    private func handleCanceled(req: Request, event: StripeEvent) async throws {
        let paymentIntent = event.data.object
        guard let order = try await OrderModel.query(on: req.db).filter(\.$paymentIntentId == paymentIntent.id).first() else { return }
        try await req.db.transaction { db in
            guard let locked = try await OrderModel.find(order.requireID(), on: db) else { return }
            guard locked.status == "pending_payment" else { return }
            locked.status = "canceled"
            if let item = try await ItemModel.find(locked.itemId, on: db), item.status == "reserved" {
                item.status = "on_sale"
                try await item.save(on: db)
            }
            try await locked.save(on: db)
        }
    }

    private func verify(signature: String, payload: String, secret: String) throws {
        var timestamp: String?
        var signatures: [String] = []
        for part in signature.split(separator: ",") {
            let pair = part.split(separator: "=", maxSplits: 1).map(String.init)
            guard pair.count == 2 else { continue }
            if pair[0] == "t" { timestamp = pair[1] }
            if pair[0] == "v1" { signatures.append(pair[1]) }
        }
        guard let timestamp, let ts = TimeInterval(timestamp), abs(Date().timeIntervalSince1970 - ts) <= 300 else {
            throw Abort(.unauthorized, reason: "Stripe webhook timestampが不正です")
        }
        let signedPayload = "\(timestamp).\(payload)"
        let key = SymmetricKey(data: Data(secret.utf8))
        let digest = HMAC<SHA256>.authenticationCode(for: Data(signedPayload.utf8), using: key)
        let expected = Data(digest).map { String(format: "%02x", $0) }.joined()
        guard signatures.contains(expected) else { throw Abort(.unauthorized, reason: "Stripe webhook署名が不正です") }
    }
}

private struct StripeEvent: Decodable {
    let type: String
    let data: StripeEventData
}
private struct StripeEventData: Decodable {
    let object: StripePaymentIntentPayload
}
private struct StripePaymentIntentPayload: Decodable {
    let id: String
    let metadata: [String: String]?
    let status: String
}
