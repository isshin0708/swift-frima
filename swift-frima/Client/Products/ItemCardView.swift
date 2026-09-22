import SwiftUI

struct ItemCardView: View {

    let item: Item

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            // 商品画像
            if let imageUrl = item.imageUrl,
               let url = URL(string: imageUrl) {

                GeometryReader { geometry in
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ZStack {
                                Color.gray.opacity(0.1)
                                ProgressView()
                            }

                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()

                        case .failure:
                            ZStack {
                                Color.gray.opacity(0.1)

                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)
                            }

                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.width
                    )
                    .clipped()
                    .clipShape(
                        RoundedRectangle(cornerRadius: 12)
                    )
                }
                .aspectRatio(1, contentMode: .fit)

            } else {

                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .background(
                        Color.gray.opacity(0.1)
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: 12)
                    )
            }

            // 商品名
            Text(item.name)
                .font(.headline)
                .lineLimit(2)

            // 価格
            Text(
                "¥" + NSDecimalNumber(
                    decimal: item.price
                ).stringValue
            )
            .font(.title3.bold())

            // 商品説明
            Text(item.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
}
