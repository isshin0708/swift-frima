import Foundation
import Observation

@MainActor
@Observable
final class ItemListViewModel {

    var items: [Item] = []
    var isLoading = false
    var errorMessage: String?

    // 検索文字
    var searchText = ""

    // ソート方法
    enum SortOption: String, CaseIterable, Identifiable {
        case newest = "新着順"
        case priceLowToHigh = "価格が安い順"
        case priceHighToLow = "価格が高い順"

        var id: String {
            rawValue
        }
    }

    var sortOption: SortOption = .newest

    private let api: NetworkClient

    init(api: NetworkClient) {
        self.api = api
    }

    // 検索・ソート後の商品
    var filteredItems: [Item] {

        // 商品名で検索
        let searchedItems: [Item]

        let keyword = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if keyword.isEmpty {
            searchedItems = items
        } else {
            searchedItems = items.filter {
                $0.name.localizedCaseInsensitiveContains(keyword)
            }
        }

        // ソート
        switch sortOption {

        case .newest:
            return searchedItems.sorted {
                ($0.createdAt ?? .distantPast) >
                ($1.createdAt ?? .distantPast)
            }

        case .priceLowToHigh:
            return searchedItems.sorted {
                $0.price < $1.price
            }

        case .priceHighToLow:
            return searchedItems.sorted {
                $0.price > $1.price
            }
        }
    }

    func fetchItems() async {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            items = try await api.get("/api/items")
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
