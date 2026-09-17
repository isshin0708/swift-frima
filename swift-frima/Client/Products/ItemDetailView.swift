import SwiftUI

struct ItemDetailView: View {

    let item: Item
    let api: NetworkClient
    let auth: AuthViewModel

    @State private var isLiked = false
    @State private var likeCount = 0
    @State private var isLikeLoading = false
    @State private var likeErrorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // 商品画像
                if let imageUrl = item.imageUrl,
                   let url = URL(string: imageUrl) {

                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .clipped()
                    .clipShape(
                        RoundedRectangle(cornerRadius: 12)
                    )

                } else {

                    Image(systemName: "photo")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 300)
                        .background(.gray.opacity(0.1))
                        .clipShape(
                            RoundedRectangle(cornerRadius: 12)
                        )
                }

                // 商品名
                Text(item.name)
                    .font(.title)
                    .fontWeight(.bold)

                // 価格
                Text("¥" + NSDecimalNumber(decimal: item.price).stringValue)
                    .font(.title2)
                    .fontWeight(.bold)

                // いいねボタン
                Button {
                    Task {
                        await likeItem()
                    }
                } label: {
                    HStack {
                        Image(systemName: isLiked ? "heart.fill" : "heart")

                        Text("いいね")

                        Text("\(likeCount)")
                    }
                    .font(.headline)
                }
                .disabled(isLikeLoading)

                // いいねエラー
                if let likeErrorMessage {
                    Text(likeErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Divider()

                // 商品説明
                VStack(alignment: .leading, spacing: 8) {
                    Text("商品説明")
                        .font(.headline)

                    Text(item.description)
                        .foregroundStyle(.secondary)
                }

                // 参考価格
                if let referencePrice = item.referencePrice {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("参考価格")
                            .font(.headline)

                        Text(
                            "¥" + NSDecimalNumber(
                                decimal: referencePrice
                            ).stringValue
                        )
                        .foregroundStyle(.secondary)
                    }
                }

                // メーカー希望小売価格
                if let suggestedPrice = item.manufacturerSuggestedRetailPrice {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("メーカー希望小売価格")
                            .font(.headline)

                        Text(
                            "¥" + NSDecimalNumber(
                                decimal: suggestedPrice
                            ).stringValue
                        )
                        .foregroundStyle(.secondary)
                    }
                }

                // 商品状態
                VStack(alignment: .leading, spacing: 8) {
                    Text("商品状態")
                        .font(.headline)

                    Text(statusText)
                        .foregroundStyle(.secondary)
                }

                // 購入ボタン
                NavigationLink {
                    CheckoutView(
                        item: item,
                        api: api,
                        authTokenProvider: {
                            try await auth.accessToken()
                        }
                    )
                } label: {
                    Text("購入する")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .navigationTitle("商品詳細")
        .navigationBarTitleDisplayMode(.inline)

        // 商品詳細を開いたときにいいね状態を取得
        .task {
            await loadLikeStatus()
        }
    }

    // MARK: - いいね状態取得

    private func loadLikeStatus() async {

        guard let itemId = item.id else {
            return
        }

        likeErrorMessage = nil

        do {
            let token = try await auth.accessToken()

            let response: LikeStatusResponse = try await api.get(
                "/api/items/\(itemId)/like",
                authToken: token
            )

            isLiked = response.isLiked
            likeCount = response.likeCount

        } catch {
            likeErrorMessage = error.localizedDescription
        }
    }

    // MARK: - いいね登録

    private func likeItem() async {

        guard let itemId = item.id else {
            return
        }

        // すでにいいね済みなら何もしない
        guard !isLiked else {
            return
        }

        isLikeLoading = true
        likeErrorMessage = nil

        defer {
            isLikeLoading = false
        }

        do {
            let token = try await auth.accessToken()

            let response: LikeStatusResponse = try await api.post(
                "/api/items/\(itemId)/like",
                body: EmptyRequest(),
                authToken: token
            )

            isLiked = response.isLiked
            likeCount = response.likeCount

        } catch {
            likeErrorMessage = error.localizedDescription
        }
    }

    // MARK: - 商品状態

    private var statusText: String {
        switch item.status {
        case .onSale:
            return "販売中"

        case .soldOut:
            return "売り切れ"

        case .suspended:
            return "販売停止"

        case .pendingReview:
            return "審査中"

        case .reserved:
            return "取り置き中"
        }
    }
}
