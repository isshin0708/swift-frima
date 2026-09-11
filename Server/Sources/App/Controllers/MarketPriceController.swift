import Vapor

struct MarketPriceController: RouteCollection {
    let service = MarketPriceService()
    func boot(routes: RoutesBuilder) throws {
        routes.get("api", "market-price", use: search)
    }
    func search(req: Request) async throws -> MarketPriceResult {
        guard let query = req.query[String.self, at: "query"] else { throw Abort(.badRequest, reason: "queryが必要です") }
        return try await service.search(query: query, on: req)
    }
}
