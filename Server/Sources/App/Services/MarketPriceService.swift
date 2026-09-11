import Vapor

struct MarketPriceService: Sendable {
    func search(query: String, on req: Request) async throws -> MarketPriceResult {
        guard let appId = Environment.get("YAHOO_APP_ID"), !appId.isEmpty else {
            req.logger.error("YAHOO_APP_ID is missing")
            throw Abort(.internalServerError, reason: "市場価格APIが設定されていません")
        }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2, q.count <= 100 else { throw Abort(.badRequest, reason: "検索語は2〜100文字で入力してください") }

        let uri = URI(string: "https://shopping.yahooapis.jp/ShoppingWebService/V3/itemSearch")
        let response = try await req.client.get(uri) { clientReq in
            try clientReq.query.encode(YahooSearchQuery(
                appId: appId,
                query: q,
                results: 20,
                condition: "new",
                inStock: true,
                sort: "-score"
            ))
        }
        guard response.status == .ok else { throw Abort(.badGateway, reason: "Yahoo!ショッピングAPIがエラーを返しました") }
        let decoded = try response.content.decode(YahooShoppingResponse.self)
        let prices = decoded.hits.compactMap(\.price).filter { $0 > 0 }
        let fixedPrices = decoded.hits.compactMap { $0.priceLabel?.fixedPrice }.filter { $0 > 0 }
        guard !prices.isEmpty else { return MarketPriceResult(sampleCount: 0, averageMarketPrice: nil, medianMarketPrice: nil, minPrice: nil, maxPrice: nil, manufacturerSuggestedRetailPrice: median(fixedPrices)) }
        let filtered = removeOutliers(prices)
        let average = filtered.reduce(Decimal(0), +) / Decimal(filtered.count)
        return MarketPriceResult(sampleCount: filtered.count, averageMarketPrice: average, medianMarketPrice: median(filtered), minPrice: filtered.min(), maxPrice: filtered.max(), manufacturerSuggestedRetailPrice: median(fixedPrices))
    }

    private func removeOutliers(_ values: [Decimal]) -> [Decimal] {
        guard values.count >= 5, let med = median(values) else { return values }
        let deviations = values.map { absDecimal($0 - med) }
        guard let mad = median(deviations), mad > 0 else { return values }
        let limit = mad * Decimal(3)
        return values.filter { absDecimal($0 - med) <= limit }
    }
    private func median(_ values: [Decimal]) -> Decimal? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let i = sorted.count / 2
        if sorted.count % 2 == 1 { return sorted[i] }
        return (sorted[i - 1] + sorted[i]) / Decimal(2)
    }
    private func absDecimal(_ value: Decimal) -> Decimal { value < 0 ? -value : value }
}

private struct YahooSearchQuery: Encodable {
    let appId: String
    let query: String
    let results: Int
    let condition: String
    let inStock: Bool
    let sort: String

    enum CodingKeys: String, CodingKey {
        case appId = "appid"
        case query
        case results
        case condition
        case inStock = "in_stock"
        case sort
    }
}

private struct YahooShoppingResponse: Content { let hits: [YahooHit] }
private struct YahooHit: Content {
    let price: Decimal
    let priceLabel: PriceLabel?
}
private struct PriceLabel: Content { let fixedPrice: Decimal? }

// MarketPriceResult は Models/SharedModels.swift で定義されたものを使用する
// (このファイルで再定義すると同一モジュール内での型の重複定義となりビルドエラーになるため削除)
