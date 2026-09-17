import SwiftUI

struct ItemCardView: View {

    let item: Item

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

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
                .frame(height: 180)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            } else {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
                    .background(.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // 商品名
            Text(item.name)
                .font(.headline)
                .lineLimit(2)

            // 価格
            Text("¥" + NSDecimalNumber(decimal: item.price).stringValue)
                .font(.title3.bold())

            // 商品説明
            Text(item.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 8)
    }
}
