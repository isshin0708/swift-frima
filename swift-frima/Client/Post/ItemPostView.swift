import SwiftUI
import PhotosUI
import UIKit
import Supabase

struct ItemPostView: View {

    let api: NetworkClient
    let authTokenProvider: @Sendable () async throws -> String

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var priceString = ""
    @State private var description = ""
    @State private var categoryId = 1

    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var resultMessage: String?

    @State private var market: MarketPriceService

    // 写真
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var isUploadingImage = false

    init(
        api: NetworkClient,
        authTokenProvider: @escaping @Sendable () async throws -> String
    ) {
        self.api = api
        self.authTokenProvider = authTokenProvider
        _market = State(initialValue: MarketPriceService(client: api))
    }

    private var price: Decimal? {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "ja_JP")

        return f.number(from: priceString)?.decimalValue
    }

    var body: some View {
        Form {

            // MARK: - 商品情報
            Section("商品情報") {

                // 写真
                VStack(spacing: 12) {

                    if let selectedImageData,
                       let uiImage = UIImage(data: selectedImageData) {

                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                    } else {

                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.15))
                            .frame(height: 220)
                            .overlay {
                                VStack(spacing: 8) {
                                    Image(systemName: "photo")
                                        .font(.system(size: 40))
                                        .foregroundStyle(.secondary)

                                    Text("商品写真")
                                        .foregroundStyle(.secondary)
                                }
                            }
                    }

                    PhotosPicker(
                        selection: $selectedPhoto,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label(
                            selectedImageData == nil ? "写真を選択" : "写真を変更",
                            systemImage: "photo.on.rectangle"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .onChange(of: selectedPhoto) { _, newPhoto in
                        guard let newPhoto else { return }

                        Task {
                            await loadPhoto(from: newPhoto)
                        }
                    }
                }

                TextField("商品名", text: $name)
                    .onChange(of: name) { _, value in
                        market.scheduleSearch(
                            query: value,
                            sellingPrice: price
                        )
                    }

                TextField("販売価格(円)", text: $priceString)
                    .keyboardType(.numberPad)
                    .onChange(of: priceString) { _, _ in
                        market.scheduleSearch(
                            query: name,
                            sellingPrice: price
                        )
                    }

                Picker("カテゴリ", selection: $categoryId) {
                    Text("ゲーム").tag(1)
                    Text("家電").tag(2)
                    Text("ファッション").tag(3)
                    Text("その他").tag(4)
                }

                TextEditor(text: $description)
                    .frame(minHeight: 100)
            }

            // MARK: - 市場調査
            Section("市場調査") {

                if market.isSearching {

                    ProgressView("検索中...")

                } else if let r = market.result {

                    if let fixed = r.manufacturerSuggestedRetailPrice {
                        Text(
                            "メーカー希望小売価格: ¥\(NSDecimalNumber(decimal: fixed).intValue)"
                        )
                    }

                    if let median = r.medianMarketPrice {
                        Text(
                            "実売相場中央値: ¥\(NSDecimalNumber(decimal: median).intValue)"
                        )
                        .bold()
                    }

                    Text("サンプル: \(r.sampleCount)件")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if market.isLikelyResalePriced {
                        Label(
                            "相場の1.8倍以上です。サーバー審査対象になります。",
                            systemImage: "exclamationmark.triangle"
                        )
                        .foregroundStyle(.red)
                    }

                } else if let e = market.errorMessage {

                    Text(e)
                        .foregroundStyle(.orange)

                } else {

                    Text("商品名を2文字以上入力すると自動検索します。")
                        .font(.caption)
                }
            }

            if isUploadingImage {
                Section {
                    ProgressView("写真をアップロード中...")
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }

            if let resultMessage {
                Text(resultMessage)
                    .foregroundStyle(.orange)
            }

            // MARK: - 出品
            Button {
                submit()
            } label: {
                if isSubmitting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("出品する")
                        .frame(maxWidth: .infinity)
                }
            }
            .disabled(
                isSubmitting ||
                isUploadingImage ||
                name.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 ||
                price == nil
            )
        }
        .navigationTitle("商品を出品")
    }

    // MARK: - 写真読み込み

    private func loadPhoto(from item: PhotosPickerItem) async {

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                return
            }

            guard let image = UIImage(data: data) else {
                return
            }

            // JPEGに圧縮
            guard let compressedData = image.jpegData(
                compressionQuality: 0.7
            ) else {
                return
            }

            selectedImageData = compressedData

        } catch {
            errorMessage = "写真の読み込みに失敗しました。"
        }
    }

    // MARK: - 出品

    private func submit() {

        guard let price, price > 0 else {
            return
        }

        isSubmitting = true
        errorMessage = nil
        resultMessage = nil

        Task {

            do {

                // Supabase JWT
                let token = try await authTokenProvider()

                // 画像URL
                var imageURL: String?

                // 写真が選択されている場合だけアップロード
                if let selectedImageData {

                    isUploadingImage = true

                    imageURL = try await uploadImage(
                        data: selectedImageData
                    )

                    isUploadingImage = false
                }

                // 商品登録
                let body = ItemCreateRequest(
                    name: name.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ),
                    description: description,
                    price: price,
                    categoryId: categoryId,
                    imageUrl: imageURL
                )

                let response: ItemCreateResponse =
                    try await api.post(
                        "/api/items",
                        body: body,
                        authToken: token
                    )

                await MainActor.run {

                    isSubmitting = false
                    isUploadingImage = false

                    if response.isSuspiciousResale {

                        resultMessage =
                            response.message ??
                            "審査待ちになりました。"

                    } else {

                        dismiss()
                    }
                }

            } catch {

                await MainActor.run {

                    isSubmitting = false
                    isUploadingImage = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Supabase Storageへ画像アップロード

    private func uploadImage(data: Data) async throws -> String {

        let fileName = "\(UUID().uuidString).jpg"
        let path = "items/\(fileName)"

        try await supabase.storage
            .from("item-images")
            .upload(
                path,
                data: data
            )

        let publicURL = try supabase.storage
            .from("item-images")
            .getPublicURL(path: path)

        return publicURL.absoluteString
    }
}
