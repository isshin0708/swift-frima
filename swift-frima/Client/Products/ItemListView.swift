import SwiftUI

struct ItemListView: View {

    let api: NetworkClient
    let auth: AuthViewModel

    @State private var viewModel: ItemListViewModel

    init(
        api: NetworkClient,
        auth: AuthViewModel
    ) {
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

            } else {

                productList
            }
        }
        .navigationTitle("商品一覧")
        .searchable(
            text: $viewModel.searchText,
            prompt: "商品名で検索"
        )
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker(
                        "並び順",
                        selection: $viewModel.sortOption
                    ) {
                        ForEach(
                            ItemListViewModel.SortOption.allCases
                        ) { option in
                            Text(option.rawValue)
                                .tag(option)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
            }
        }
        .task {
            await viewModel.fetchItems()
        }
    }

    private var productList: some View {

        if viewModel.filteredItems.isEmpty {

            return AnyView(
                ContentUnavailableView(
                    "商品がありません",
                    systemImage: "bag",
                    description: Text(
                        viewModel.searchText.isEmpty
                        ? "現在出品されている商品はありません。"
                        : "「\(viewModel.searchText)」に一致する商品がありません。"
                    )
                )
            )

        } else {

            return AnyView(
                List(viewModel.filteredItems) { item in

                    NavigationLink {

                        ItemDetailView(
                            item: item,
                            api: api,
                            auth: auth
                        )

                    } label: {

                        ItemCardView(item: item)
                    }
                }
            )
        }
    }
}
