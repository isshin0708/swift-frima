import SwiftUI

struct LikedItemsView: View {
    let api: NetworkClient
    let auth: AuthViewModel

    @State private var items: [Item] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("いいねした商品を読み込み中...")
            } else if let errorMessage {
                VStack(spacing: 12) {
                    Text("商品の取得に失敗しました")
                        .font(.headline)

                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("再読み込み") {
                        Task {
                            await loadLikedItems()
                        }
                    }
                }
                .padding()

            } else if items.isEmpty {
                ContentUnavailableView(
                    "いいねした商品はありません",
                    systemImage: "heart",
                    description: Text(
                        "気になる商品にいいねすると、ここに表示されます。"
                    )
                )

            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ],
                        spacing: 16
                    ) {
                        ForEach(items) { item in
                            NavigationLink {
                                ItemDetailView(
                                    item: item,
                                    api: api,
                                    auth: auth
                                )
                            } label: {
                                ItemCardView(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("いいねした商品")
        .task {
            await loadLikedItems()
        }
    }

    private func loadLikedItems() async {
        isLoading = true
        errorMessage = nil

        do {
            let token = try await auth.accessToken()

            let response: [Item] = try await api.get(
                "/api/users/me/likes",
                authToken: token
            )

            items = response
            isLoading = false

        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }
}
