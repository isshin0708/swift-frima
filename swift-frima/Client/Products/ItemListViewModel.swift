import Foundation
import Observation

@MainActor
@Observable
final class ItemListViewModel {

    var items: [Item] = []
    var isLoading = false
    var errorMessage: String?

    private let api: NetworkClient

    init(api: NetworkClient) {
        self.api = api
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
