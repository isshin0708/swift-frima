import SwiftUI

struct ItemDetailView: View {
    let item: Item
    let api: NetworkClient
    let auth: AuthViewModel

    @State private var isLiked = false
    @State private var likeCount = 0


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

                Button {
                    // 次のステップでAPI処理を追加
                } label: {
                    HStack {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                        Text("いいね")
                        Text("\(likeCount)")
                    }
                    .font(.headline)
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
                            "¥" + NSDecimalNumber(decimal: referencePrice).stringValue
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
                            "¥" + NSDecimalNumber(decimal: suggestedPrice).stringValue
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
    }

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
