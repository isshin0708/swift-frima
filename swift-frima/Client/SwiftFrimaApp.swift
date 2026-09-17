import SwiftUI

@main
struct SwiftFrimaApp: App {

    private let api = NetworkClient(
        baseURL: URL(string: "http://127.0.0.1:8080")!
    )

    @State private var auth = AuthViewModel()

    var body: some Scene {

        WindowGroup {

            NavigationStack {

                if auth.isAuthenticated {

                    HomeView(
                        api: api,
                        auth: auth
                    )

                } else {

                    AuthView(
                        viewModel: auth
                    )
                }
            }
        }
    }
}

private struct HomeView: View {

    let api: NetworkClient
    let auth: AuthViewModel

    var body: some View {

        List {

            // MARK: - ユーザー情報

            Section {

                VStack(alignment: .leading, spacing: 6) {

                    Text("swift-frima")
                        .font(.largeTitle.bold())

                    Text("ようこそ")
                        .font(.headline)

                    Text(auth.currentUserEmail ?? "ユーザー")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            // MARK: - メインメニュー

            Section("メニュー") {

                NavigationLink {
                    ItemListView(
                        api: api,
                        auth: auth
                    )
                } label: {
                    Label(
                        "商品を探す",
                        systemImage: "magnifyingglass"
                    )
                }

                NavigationLink {
                    ItemPostView(
                        api: api,
                        authTokenProvider: {
                            try await auth.accessToken()
                        }
                    )
                } label: {
                    Label(
                        "商品を出品",
                        systemImage: "plus.circle"
                    )
                }

                NavigationLink {
                    CheckoutView(
                        item: Item(
                            id: UUID(),
                            userId: UUID(),
                            name: "swift-frima テスト商品",
                            description: "ローカル起動確認用の商品です。",
                            price: Decimal(1800),
                            manufacturerSuggestedRetailPrice: nil,
                            referencePrice: Decimal(1200),
                            categoryId: 1,
                            status: .onSale,
                            imageUrl: nil,
                            createdAt: Date()
                        ),
                        api: api,
                        authTokenProvider: {
                            try await auth.accessToken()
                        }
                    )
                } label: {
                    Label(
                        "購入画面",
                        systemImage: "cart"
                    )
                }
            }

            // MARK: - アカウント

            Section("アカウント") {

                NavigationLink {
                    Text("プロフィール画面")
                        .navigationTitle("プロフィール")
                } label: {
                    Label(
                        "プロフィール",
                        systemImage: "person.circle"
                    )
                }

                NavigationLink {
                    Text("購入履歴")
                        .navigationTitle("購入履歴")
                } label: {
                    Label(
                        "購入履歴",
                        systemImage: "clock.arrow.circlepath"
                    )
                }
            }

            // MARK: - ログアウト

            Section {

                Button(
                    "ログアウト",
                    role: .destructive
                ) {

                    Task {
                        await auth.signOut()
                    }
                }
            }
        }
        .navigationTitle("ホーム")
    }
}
