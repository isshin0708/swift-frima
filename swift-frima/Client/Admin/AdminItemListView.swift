import SwiftUI

struct AdminItemListView: View {
    let api: NetworkClient
    let auth: AuthViewModel

    @State private var items: [Item] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("商品を読み込み中...")
            } else if let errorMessage {
                VStack(spacing: 12) {
                    Text("商品の取得に失敗しました")
                        .font(.headline)

                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("再読み込み") {
                        Task {
                            await loadItems()
                        }
                    }
                }
                .padding()
            } else {
                List(items) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.name)
                            .font(.headline)

                        Text("価格：\(String(describing: item.price))")
                            .font(.subheadline)

                        Text("カテゴリID：\(item.categoryId)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("ステータス：\(item.status.rawValue)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("商品管理")
        .task {
            await loadItems()
        }
    }

    private func loadItems() async {
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
