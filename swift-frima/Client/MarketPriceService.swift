import Foundation
import Observation

@MainActor
@Observable
public final class MarketPriceService {
    private let client: NetworkClient
    public private(set) var isSearching = false
    public private(set) var result: MarketPriceResult?
    public private(set) var errorMessage: String?
    public private(set) var isLikelyResalePriced = false
    private var task: Task<Void, Never>?

    public init(client: NetworkClient) { self.client = client }

    public func scheduleSearch(query: String, sellingPrice: Decimal?, debounce: Duration = .milliseconds(700)) {
        task?.cancel()
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else { result = nil; errorMessage = nil; isLikelyResalePriced = false; return }
        task = Task { [weak self] in
            do { try await Task.sleep(for: debounce) } catch { return }
            guard !Task.isCancelled, let self else { return }
            await self.search(query: q, sellingPrice: sellingPrice)
        }
    }

    private static let resaleMultiplier: Decimal = Decimal(18) / Decimal(10)

    private func search(query: String, sellingPrice: Decimal?) async {
        isSearching = true; errorMessage = nil
        defer { isSearching = false }
        do {
            let value: MarketPriceResult = try await client.get("/api/market-price", queryItems: [URLQueryItem(name: "query", value: query)])
            guard !Task.isCancelled else { return }
            result = value
            let reference = value.medianMarketPrice ?? value.averageMarketPrice
            isLikelyResalePriced = if let sellingPrice, let reference, reference > 0 { sellingPrice >= reference * Self.resaleMultiplier } else { false }
        } catch let error as APIError {
            if case .cancelled = error { return }
            errorMessage = error.localizedDescription; result = nil; isLikelyResalePriced = false
        } catch { errorMessage = error.localizedDescription; result = nil; isLikelyResalePriced = false }
    }
}
