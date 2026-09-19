import SwiftUI

struct ItemEditView: View {

    let api: NetworkClient
    let auth: AuthViewModel
    let item: Item

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var description: String
    @State private var price: String
    @State private var categoryId: Int
    @State private var imageUrl: String?

    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        api: NetworkClient,
        auth: AuthViewModel,
        item: Item
    ) {
        self.api = api
        self.auth = auth
        self.item = item

        _name = State(initialValue: item.name)
        _description = State(initialValue: item.description)
        _price = State(
            initialValue: NSDecimalNumber(decimal: item.price).stringValue
        )
        _categoryId = State(initialValue: item.categoryId)
        _imageUrl = State(initialValue: item.imageUrl)
    }

    var body: some View {
        Form {

            // MARK: - 商品画像

            Section {
                if let imageUrl,
                   let url = URL(string: imageUrl) {

                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .frame(height: 180)

                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 180)
                                .clipped()
                                .clipShape(
                                    RoundedRectangle(cornerRadius: 12)
                                )

                        case .failure:
                            imagePlaceholder

                        @unknown default:
                            imagePlaceholder
                        }
                    }
                } else {
                    imagePlaceholder
                }
            } header: {
                Text("商品画像")
            }


            // MARK: - 商品情報

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("商品名")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextField(
                        "商品名を入力",
                        text: $name
                    )
                    .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("商品説明")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextEditor(text: $description)
                        .frame(minHeight: 140)
                        .padding(6)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    Color.gray.opacity(0.3),
                                    lineWidth: 1
                                )
                        }
                }
            } header: {
                Text("商品情報")
            }


            // MARK: - 価格

            Section {
                HStack {
                    Text("¥")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    TextField(
                        "価格を入力",
                        text: $price
                    )
                    .keyboardType(.numberPad)
                    .font(.title3)
                }

                if let referencePrice = item.referencePrice,
                   let maximumPrice {

                    Text(
                        "参考価格：¥" +
                        NSDecimalNumber(
                            decimal: referencePrice
                        ).stringValue
                    )

                    Text(
                        "設定可能な上限：¥" +
                        NSDecimalNumber(
                            decimal: maximumPrice
                        ).rounding(
                            accordingToBehavior: NSDecimalNumberHandler(
                                roundingMode: .down,
                                scale: 0,
                                raiseOnExactness: false,
                                raiseOnOverflow: false,
                                raiseOnUnderflow: false,
                                raiseOnDivideByZero: false
                            )
                        ).stringValue
                    )
                    .foregroundStyle(
                        isPriceOverLimit ? .red : .secondary
                    )

                    if isPriceOverLimit {
                        Label(
                            "設定可能な上限を超えています。",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(.red)
                    }
                }
            } header: {
                Text("価格")
            }

            // MARK: - カテゴリ

            Section("カテゴリ") {
                Picker("カテゴリ", selection: $categoryId) {
                    Text("ゲーム").tag(1)
                    Text("家電").tag(2)
                    Text("ファッション").tag(3)
                    Text("その他").tag(4)
                }
            }


            // MARK: - エラー

            if let errorMessage {
                Section {
                    Label {
                        Text(errorMessage)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                    .foregroundStyle(.red)
                }
            }


            // MARK: - 保存

            Section {
                Button {
                    Task {
                        await save()
                    }
                } label: {
                    HStack {
                        Spacer()

                        if isSaving {
                            ProgressView()
                        } else {
                            Image(systemName: "checkmark.circle.fill")

                            Text("変更を保存")
                                .fontWeight(.semibold)
                        }

                        Spacer()
                    }
                }
                .disabled(
                    isSaving ||
                    isPriceOverLimit
                )
            }
        }
        .navigationTitle("商品を編集")
        .navigationBarTitleDisplayMode(.inline)
    }


    // MARK: - 画像プレースホルダー

    private var imagePlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))

            VStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.system(size: 40))

                Text("画像なし")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
    }


    // MARK: - 保存

    private func save() async {

        guard !isSaving else {
            return
        }

        errorMessage = nil

        // 商品名
        let trimmedName = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard trimmedName.count >= 2 else {
            errorMessage = "商品名は2文字以上で入力してください。"
            return
        }

        guard trimmedName.count <= 100 else {
            errorMessage = "商品名は100文字以内で入力してください。"
            return
        }


        // 説明
        let trimmedDescription = description.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard trimmedDescription.count <= 2_000 else {
            errorMessage = "商品説明は2,000文字以内で入力してください。"
            return
        }


        // 価格
        guard let decimalPrice = Decimal(
            string: price
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
        ) else {
            errorMessage = "価格を正しく入力してください。"
            return
        }

        guard decimalPrice > 0 else {
            errorMessage = "価格は1円以上で入力してください。"
            return
        }

        guard decimalPrice <= 10_000_000 else {
            errorMessage = "価格は10,000,000円以下で入力してください。"
            return
        }
        
        if let maximumPrice,
           decimalPrice > maximumPrice {
            errorMessage = "設定可能な上限を超えています。"
            return
        }


        // 商品ID
        guard let itemId = item.id else {
            errorMessage = "商品IDを取得できませんでした。"
            return
        }


        isSaving = true

        defer {
            isSaving = false
        }


        do {

            let token = try await auth.accessToken()

            let request = ItemUpdateRequest(
                name: trimmedName,
                description: trimmedDescription,
                price: decimalPrice,
                categoryId: categoryId,
                imageUrl: imageUrl
            )

            let _: Item = try await api.patch(
                "/api/items/\(itemId.uuidString)",
                body: request,
                authToken: token
            )

            dismiss()

        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private var maximumPrice: Decimal? {
        guard let referencePrice = item.referencePrice,
              referencePrice > 0 else {
            return nil
        }

        return referencePrice * Decimal(string: "1.8")!
    }
    
    private var isPriceOverLimit: Bool {
        guard let price = Decimal(
            string: price.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        ),
        let maximumPrice else {
            return false
        }

        return price > maximumPrice
    }
}
