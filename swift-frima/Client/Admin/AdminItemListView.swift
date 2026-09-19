import SwiftUI

struct AdminItemListView: View {

    let api: NetworkClient
    let auth: AuthViewModel

    @State private var items: [Item] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedTab = 0

    var body: some View {

        VStack {

            Picker(
                "表示",
                selection: $selectedTab
            ) {
                Text("全商品").tag(0)
                Text("転売疑い").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

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

                } else if items.isEmpty {

                    ContentUnavailableView(
                        selectedTab == 0
                            ? "商品がありません"
                            : "転売疑いの商品はありません",
                        systemImage:
                            selectedTab == 0
                                ? "shippingbox"
                                : "checkmark.shield"
                    )

                } else {

                    List {

                        ForEach(items.indices, id: \.self) { index in
                            itemRow(items[index])
                        }

                    }
                }
            }
        }
        .navigationTitle(
            selectedTab == 0
                ? "商品管理"
                : "転売疑い商品審査"
        )
        .task {
            await loadItems()
        }
        .onChange(of: selectedTab) {
            Task {
                await loadItems()
            }
        }
    }

    // MARK: - 商品行

    @ViewBuilder
    private func itemRow(_ item: Item) -> some View {

        VStack(
            alignment: .leading,
            spacing: 8
        ) {

            Text(item.name)
                .font(.headline)

            Text(
                "価格：\(NSDecimalNumber(decimal: item.price).stringValue)円"
            )
            .font(.subheadline)

            Text(
                "カテゴリID：\(item.categoryId)"
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack {

                Text(
                    "ステータス：\(item.status.rawValue)"
                )
                .font(.caption)

                Spacer()

                if item.status == .pendingReview {

                    Text("要審査")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            // 転売疑い商品の審査ボタン
            if item.status == .pendingReview {

                HStack(spacing: 12) {

                    Button("承認") {
                        Task {
                            await approve(
                                itemId: item.id
                            )
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Button(
                        "削除",
                        role: .destructive
                    ) {
                        Task {
                            await delete(
                                itemId: item.id
                            )
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }

        }
        .padding(.vertical, 6)
    }

    // MARK: - Load

    private func loadItems() async {

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {

            let token = try await auth.accessToken()

            if selectedTab == 0 {

                items = try await api.get(
                    "/api/admin/items",
                    authToken: token
                )

            } else {

                items = try await api.get(
                    "/api/admin/suspicious",
                    authToken: token
                )
            }

        } catch {

            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Approve

    private func approve(
        itemId: UUID?
    ) async {

        guard let itemId else {
            return
        }

        do {

            let token = try await auth.accessToken()

            let _: Item = try await api.post(
                "/api/admin/suspicious/\(itemId.uuidString)/approve",
                body: EmptyRequest(),
                authToken: token
            )

            await loadItems()

        } catch {

            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Delete

    private func delete(
        itemId: UUID?
    ) async {

        guard let itemId else {
            return
        }

        do {

            let token = try await auth.accessToken()

            let _: Item = try await api.delete(
                "/api/admin/items/\(itemId.uuidString)",
                authToken: token
            )

            await loadItems()

        } catch {

            errorMessage = error.localizedDescription
        }
    }
}
