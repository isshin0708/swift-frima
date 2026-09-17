import SwiftUI

struct ItemListView: View {

    let api: NetworkClient
    let auth: AuthViewModel

    @State private var viewModel: ItemListViewModel

    init(api: NetworkClient, auth: AuthViewModel) {
        self.api = api
        self.auth = auth

        _viewModel = State(
            initialValue: ItemListViewModel(api: api)
        )
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("商品を読み込み中...")

            } else if let errorMessage = viewModel.errorMessage {
                VStack(spacing: 12) {
                    Text("商品の取得に失敗しました")
                        .font(.headline)

                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("再読み込み") {
                        Task {
                            await viewModel.fetchItems()
                        }
                    }
                }
                .padding()

            } else if viewModel.items.isEmpty {
                ContentUnavailableView(
                    "商品がありません",
                    systemImage: "bag",
                    description: Text("現在出品されている商品はありません。")
                )

            } else {
                List(viewModel.items) { item in
                    NavigationLink {
                        ItemDetailView(
                            item: item,
                            api: api,
                            authTokenProvider: {
                                try await auth.accessToken()
                            }
                        )
                    } label: {
                        ItemCardView(item: item)
                    }
                }
            }
        }
        .navigationTitle("商品一覧")
        .task {
            await viewModel.fetchItems()
        }
    }
}
