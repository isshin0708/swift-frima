import SwiftUI

struct ItemPostView: View {
    let api: NetworkClient
    let authTokenProvider: () async throws -> String
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var priceString = ""
    @State private var description = ""
    @State private var categoryId = 1
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var resultMessage: String?
    @State private var market: MarketPriceService

    init(api: NetworkClient, authTokenProvider: @escaping () async throws -> String) {
        self.api = api; self.authTokenProvider = authTokenProvider
        _market = State(initialValue: MarketPriceService(client: api))
    }

    private var price: Decimal? {
        let f = NumberFormatter(); f.numberStyle = .decimal; f.locale = Locale(identifier: "ja_JP")
        return f.number(from: priceString)?.decimalValue
    }

    var body: some View {
        Form {
            Section("商品情報") {
                TextField("商品名", text: $name)
                    .onChange(of: name) { _, v in market.scheduleSearch(query: v, sellingPrice: price) }
                TextField("販売価格(円)", text: $priceString).keyboardType(.numberPad)
                    .onChange(of: priceString) { _, _ in market.scheduleSearch(query: name, sellingPrice: price) }
                Picker("カテゴリ", selection: $categoryId) {
                    Text("ゲーム").tag(1); Text("家電").tag(2); Text("ファッション").tag(3); Text("その他").tag(4)
                }
                TextEditor(text: $description).frame(minHeight: 100)
            }
            Section("市場調査") {
                if market.isSearching { ProgressView("検索中...") }
                else if let r = market.result {
                    if let fixed = r.manufacturerSuggestedRetailPrice { Text("メーカー希望小売価格: ¥\(NSDecimalNumber(decimal: fixed).intValue)") }
                    if let median = r.medianMarketPrice { Text("実売相場中央値: ¥\(NSDecimalNumber(decimal: median).intValue)").bold() }
                    Text("サンプル: \(r.sampleCount)件").font(.caption).foregroundStyle(.secondary)
                    if market.isLikelyResalePriced { Label("相場の1.8倍以上です。サーバー審査対象になります。", systemImage: "exclamationmark.triangle").foregroundStyle(.red) }
                } else if let e = market.errorMessage { Text(e).foregroundStyle(.orange) }
                else { Text("商品名を2文字以上入力すると自動検索します。").font(.caption) }
            }
            if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            if let resultMessage { Text(resultMessage).foregroundStyle(.orange) }
            Button("出品する") { submit() }.disabled(isSubmitting || name.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 || price == nil)
        }
        .navigationTitle("商品を出品")
    }

    private func submit() {
        guard let price, price > 0 else { return }
        isSubmitting = true; errorMessage = nil; resultMessage = nil
        Task {
            do {
                let token = try await authTokenProvider()
                let body = ItemCreateRequest(name: name.trimmingCharacters(in: .whitespacesAndNewlines), description: description, price: price, categoryId: categoryId, imageUrl: nil)
                let response: ItemCreateResponse = try await api.post("/api/items", body: body, authToken: token)
                await MainActor.run {
                    isSubmitting = false
                    if response.isSuspiciousResale { resultMessage = response.message ?? "審査待ちになりました。" }
                    else { dismiss() }
                }
            } catch { await MainActor.run { isSubmitting = false; errorMessage = error.localizedDescription } }
        }
    }
}
