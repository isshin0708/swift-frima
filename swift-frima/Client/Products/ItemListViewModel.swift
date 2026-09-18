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
        let searchedItems: [Item]
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        if keyword.isEmpty {
            searchedItems = items
        } else {
            searchedItems = items.filter {
                $0.name.localizedCaseInsensitiveContains(keyword)
            }
        }

        // カテゴリで絞り込み
        let categoryFilteredItems: [Item]

        if selectedCategory == .all {
            categoryFilteredItems = searchedItems
        } else {
            categoryFilteredItems = searchedItems.filter {
                $0.categoryId == selectedCategory.rawValue
            }
        }

        // 並び順
        switch sortOption {
        case .newest:
            return categoryFilteredItems.sorted {
                ($0.createdAt ?? .distantPast) >
                ($1.createdAt ?? .distantPast)
            }

        case .priceLowToHigh:
            return categoryFilteredItems.sorted {
                $0.price < $1.price
            }

        case .priceHighToLow:
            return categoryFilteredItems.sorted {
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
    
    enum CategoryOption: Int, CaseIterable, Identifiable {
        case all = 0
        case game = 1
        case electronics = 2
        case fashion = 3
        case other = 4

        var id: Int { rawValue }

        var name: String {
            switch self {
            case .all:
                return "すべて"
            case .game:
                return "ゲーム"
            case .electronics:
                return "家電"
            case .fashion:
                return "ファッション"
            case .other:
                return "その他"
            }
        }
    }

    var selectedCategory: CategoryOption = .all
}
