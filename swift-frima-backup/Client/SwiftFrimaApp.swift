import SwiftUI

@main
struct SwiftFrimaApp: App {
    private let api = NetworkClient(baseURL: URL(string: "http://127.0.0.1:8080")!)

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                HomeView(api: api)
            }
        }
    }
}

private struct HomeView: View {
    let api: NetworkClient
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
                Text("ローカル起動OK")
                    .font(.title2.bold())
                Text("Vapor API: http://127.0.0.1:8080")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("画面確認") {
                NavigationLink("商品を出品") {
                    ItemPostView(api: api, authTokenProvider: { "" })
                }
                NavigationLink("購入画面") {
                    CheckoutView(item: demoItem, api: api, authTokenProvider: { "" })
                }
            }

            Section {
                Text("※ 現在のClientにはSupabaseログイン画面がまだ含まれていません。上記画面の通信には認証トークンが必要です。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("swift-frima")
    }
}
