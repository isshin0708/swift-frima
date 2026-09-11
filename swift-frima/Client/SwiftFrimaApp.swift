import SwiftUI

@main
struct SwiftFrimaApp: App {
    private let api = NetworkClient(baseURL: URL(string: "http://127.0.0.1:8080")!)
    @State private var auth = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                if auth.isAuthenticated {
                    HomeView(api: api, auth: auth)
                } else {
                    AuthView(viewModel: auth)
                }
            }
        }
    }
}

private struct HomeView: View {
    let api: NetworkClient
    let auth: AuthViewModel

    private let demoItem = Item(
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
    )

    var body: some View {
        List {
            Section("swift-frima") {
                Text("ログイン中: \(auth.currentUserEmail ?? "不明")")
                    .font(.subheadline.bold())
                Text("Vapor API: http://127.0.0.1:8080")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("画面確認") {
                NavigationLink("商品を出品") {
                    ItemPostView(api: api, authTokenProvider: { try await auth.accessToken() })
                }
                NavigationLink("購入画面") {
                    CheckoutView(item: demoItem, api: api, authTokenProvider: { try await auth.accessToken() })
                }
            }

            Section {
                Button("ログアウト", role: .destructive) {
                    Task { await auth.signOut() }
                }
            }
        }
        .navigationTitle("swift-frima")
    }
}
