import Foundation
import Vapor

struct StripeService: Sendable {
    private let secretKey: String
    private let apiBaseURL = "https://api.stripe.com/v1"

    init() throws {
        guard let key = Environment.get("STRIPE_SECRET_KEY"), !key.isEmpty else {
            throw Abort(.internalServerError, reason: "STRIPE_SECRET_KEY is not configured")
        }
        self.secretKey = key
    }

    func createPaymentIntent(req: Request, amountJPY: Decimal, orderId: UUID) async throws -> StripePaymentIntent {
        let amount = try jpyAmount(amountJPY)
        let body = formEncoded([
            ("amount", String(amount)),
            ("currency", "jpy"),
            ("payment_method_types[]", "card"),
            ("metadata[order_id]", orderId.uuidString)
        ])
        return try await request(req: req, path: "/payment_intents", body: body, idempotencyKey: "order-\(orderId.uuidString)")
    }

    func retrievePaymentIntent(req: Request, id: String) async throws -> StripePaymentIntent {
        let response = try await req.client.get(URI(string: "\(apiBaseURL)/payment_intents/\(id)"), headers: authHeaders())
        return try await decode(response, as: StripePaymentIntent.self)
    }

    func cancelPaymentIntent(req: Request, id: String) async throws {
        var headers = authHeaders()
        headers.replaceOrAdd(name: .contentType, value: "application/x-www-form-urlencoded")
        let response = try await req.client.post(URI(string: "\(apiBaseURL)/payment_intents/\(id)/cancel"), headers: headers)
        let body = response.body ?? ByteBuffer()
        guard response.status == .ok else {
            throw Abort(.badGateway, reason: "Stripe決済のキャンセルに失敗しました: \(String(buffer: body))")
        }
    }

    private func request(req: Request, path: String, body: String, idempotencyKey: String) async throws -> StripePaymentIntent {
        var headers = authHeaders()
        headers.replaceOrAdd(name: .contentType, value: "application/x-www-form-urlencoded")
        headers.replaceOrAdd(name: "Idempotency-Key", value: idempotencyKey)
        let response = try await req.client.post(URI(string: "\(apiBaseURL)\(path)"), headers: headers) { request in
            request.body = .init(string: body)
        }
        return try await decode(response, as: StripePaymentIntent.self)
    }

    private func authHeaders() -> HTTPHeaders {
        var headers = HTTPHeaders()
        headers.basicAuthorization = .init(username: secretKey, password: "")
        headers.replaceOrAdd(name: .accept, value: "application/json")
        return headers
    }

    private func decode<T: Decodable>(_ response: ClientResponse, as type: T.Type) async throws -> T {
        let buffer = response.body ?? ByteBuffer()
        guard response.status == .ok || response.status == .created else {
            let message = String(buffer: buffer)
            throw Abort(.badGateway, reason: "Stripe API error: \(message)")
        }
        do {
            return try JSONDecoder().decode(T.self, from: Data(buffer: buffer))
        } catch {
            throw Abort(.badGateway, reason: "Stripe APIレスポンスの解析に失敗しました")
        }
    }

    private func jpyAmount(_ price: Decimal) throws -> Int {
        guard price > 0 else { throw Abort(.badRequest, reason: "決済金額は正の値である必要があります") }
        let number = NSDecimalNumber(decimal: price)
        let amount = number.intValue
        guard Decimal(amount) == price else {
            throw Abort(.badRequest, reason: "JPY決済額は小数を指定できません")
        }
        guard amount > 0, amount <= 100_000_000 else {
            throw Abort(.badRequest, reason: "決済金額が範囲外です")
        }
        return amount
    }

    private func formEncoded(_ pairs: [(String, String)]) -> String {
        pairs.map { "\(percentEncode($0.0))=\(percentEncode($0.1))" }.joined(separator: "&")
    }

    private func percentEncode(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

struct StripePaymentIntent: Codable, Sendable {
    let id: String
    let clientSecret: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case id
        case clientSecret = "client_secret"
        case status
    }
}
