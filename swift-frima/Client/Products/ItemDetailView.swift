import SwiftUI

struct ItemDetailView: View {

    let item: Item

    let api: NetworkClient

    let auth: AuthViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var isLiked = false

    @State private var likeCount = 0

    @State private var isLikeLoading = false

    @State private var likeErrorMessage: String?

    @State private var showAuthSheet = false

    @State private var navigateToCheckout = false

    /// ログインシートが閉じた後にやりたかったことを覚えておくためのフラグ
    @State private var pendingActionAfterLogin: PendingAction?

    @State private var negotiationMessage = ""

    @State private var isSendingNegotiation = false

    @State private var negotiationErrorMessage: String?

    @State private var negotiationSentMessage: String?

    @State private var negotiationMessages: [NegotiationMessage] = []

    @State private var isLoadingMessages = false

    @State private var showDeleteAlert = false

    @State private var isDeleting = false

    @State private var deleteErrorMessage: String?

    private enum PendingAction {
        case checkout
        case like
    }

    var body: some View {

        ScrollView {

            VStack(alignment: .leading, spacing: 20) {

                // 商品画像

                // 商品画像
                if let imageUrl = item.imageUrl,
                   let url = URL(string: imageUrl) {

                    AsyncImage(url: url) { phase in
                        switch phase {

                        case .empty:
                            ZStack {
                                Color.gray.opacity(0.1)
                                ProgressView()
                            }
                            .frame(width: 280, height: 280)

                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 280, height: 280)
                                .clipped()

                        case .failure:
                            ZStack {
                                Color.gray.opacity(0.1)

                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 280, height: 280)

                        @unknown default:
                            EmptyView()
                        }
                    }
                    .clipShape(
                        RoundedRectangle(cornerRadius: 12)
                    )
                    .frame(maxWidth: .infinity)

                } else {

                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                        .frame(width: 280, height: 280)
                        .background(
                            Color.gray.opacity(0.1)
                        )
                        .clipShape(
                            RoundedRectangle(cornerRadius: 12)
                        )
                        .frame(maxWidth: .infinity)
                }
                // 出品者プロフィール

                NavigationLink {

                    ProfileDetailView(
                        userId: item.userId,
                        api: api,
                        auth: auth
                    )

                } label: {

                    HStack(spacing: 12) {

                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 4) {

                            Text("出品者")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text("プロフィールを見る")
                                .font(.headline)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)

                Divider()

                // 商品名

                Text(item.name)
                    .font(.title)
                    .fontWeight(.bold)

                // 価格

                Text("¥" + NSDecimalNumber(decimal: item.price).stringValue)
                    .font(.title2)
                    .fontWeight(.bold)

                // いいねボタン

                if item.userId != auth.currentUserId {

                    Button {

                        Task {
                            await likeItem()
                        }

                    } label: {

                        HStack {

                            Image(
                                systemName: isLiked
                                ? "heart.fill"
                                : "heart"
                            )

                            Text("いいね")

                            Text("\(likeCount)")
                        }
                        .font(.headline)
                    }
                    .disabled(isLikeLoading)

                    if let likeErrorMessage {

                        Text(likeErrorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

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

                // MARK: - 値段交渉・質問

                VStack(alignment: .leading, spacing: 12) {

                    Text(
                        item.userId == auth.currentUserId
                        ? "購入希望者とやり取り"
                        : "出品者に相談"
                    )
                    .font(.headline)

                    TextField(
                        item.userId == auth.currentUserId
                        ? "購入希望者への返信を入力"
                        : "価格交渉や質問を入力",
                        text: $negotiationMessage,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                    .textFieldStyle(.roundedBorder)

                    Button {

                        Task {
                            await sendNegotiationMessage()
                        }

                    } label: {

                        HStack {

                            if isSendingNegotiation {

                                ProgressView()
                            }

                            Text("送信")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        negotiationMessage
                            .trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )
                            .isEmpty
                        || isSendingNegotiation
                    )

                    if let negotiationSentMessage {

                        Text(negotiationSentMessage)
                            .font(.caption)
                            .foregroundStyle(.green)
                    }

                    if let negotiationErrorMessage {

                        Text(negotiationErrorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.vertical, 8)

                if !negotiationMessages.isEmpty {

                    VStack(alignment: .leading, spacing: 12) {

                        Text("やり取り")
                            .font(.headline)

                        VStack(spacing: 8) {

                            ForEach(
                                negotiationMessages,
                                id: \.id
                            ) { message in

                                let isMine =
                                    message.senderId == auth.currentUserId

                                HStack {

                                    if isMine {
                                        Spacer(minLength: 50)
                                    }

                                    VStack(
                                        alignment: isMine
                                        ? .trailing
                                        : .leading,
                                        spacing: 4
                                    ) {

                                        Text(
                                            isMine
                                            ? "あなた"
                                            : "出品者"
                                        )
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                        Text(message.message)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 9)
                                            .background(
                                                RoundedRectangle(
                                                    cornerRadius: 14
                                                )
                                                .fill(
                                                    isMine
                                                    ? Color.blue.opacity(0.15)
                                                    : Color.gray.opacity(0.15)
                                                )
                                            )
                                    }

                                    if !isMine {
                                        Spacer(minLength: 50)
                                    }
                                }
                            }
                        }
                    }
                }

                // 購入ボタン

                if item.userId != auth.currentUserId {

                    Button {

                        if auth.isAuthenticated {

                            navigateToCheckout = true

                        } else {

                            pendingActionAfterLogin = .checkout
                            showAuthSheet = true
                        }

                    } label: {

                        Text("購入する")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .navigationTitle("商品詳細")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {

            if isMyItem {

                ToolbarItem(placement: .topBarTrailing) {

                    Menu {

                        NavigationLink {

                            ItemEditView(
                                api: api,
                                auth: auth,
                                item: item
                            )

                        } label: {

                            Label("編集", systemImage: "pencil")
                        }

                        Button(role: .destructive) {

                            showDeleteAlert = true

                        } label: {

                            Label("削除", systemImage: "trash")
                        }

                    } label: {

                        Image(systemName: "ellipsis")
                            .font(.headline)
                    }
                }
            }
        }
        .navigationDestination(isPresented: $navigateToCheckout) {

            CheckoutView(
                item: item,
                api: api,
                auth: auth
            )
        }
        .sheet(
            isPresented: $showAuthSheet,
            onDismiss: handlePendingActionAfterSheetDismissed
        ) {

            AuthView(viewModel: auth)
        }
        .onChange(of: auth.isAuthenticated) { _, isAuthenticated in

            // ログインが完了したらシートを閉じる。
            // 続きの処理は onDismiss 側
            // (シートが完全に閉じ終わった後)で行う。

            if isAuthenticated && showAuthSheet {

                showAuthSheet = false
            }
        }
        // 商品詳細を開いたときにいいね状態を取得
        // (ログイン済みの場合のみ)
        .task {

            await loadLikeStatus()
        }
        .alert("商品を削除しますか？", isPresented: $showDeleteAlert) {

            Button("キャンセル", role: .cancel) {}

            Button("削除", role: .destructive) {

                Task {
                    await deleteItem()
                }
            }

        } message: {

            Text("削除した商品は元に戻せません。")
        }
        .alert(
            "削除に失敗しました",
            isPresented: Binding(
                get: { deleteErrorMessage != nil },
                set: {
                    if !$0 {
                        deleteErrorMessage = nil
                    }
                }
            )
        ) {

            Button("OK", role: .cancel) {}

        } message: {

            Text(deleteErrorMessage ?? "")
        }
    }

    // MARK: - ログインシートが閉じた後の続き処理

    private func handlePendingActionAfterSheetDismissed() {

        defer {
            pendingActionAfterLogin = nil
        }

        // ログインせずに手動でシートを閉じた場合は何もしない

        guard auth.isAuthenticated else {
            return
        }

        switch pendingActionAfterLogin {

        case .checkout:

            navigateToCheckout = true

        case .like:

            Task {
                await likeItem()
            }

        case .none:

            break
        }
    }

    // MARK: - いいね状態取得

    private func loadLikeStatus() async {

        guard let itemId = item.id else {
            return
        }

        // 未ログインならエラーにせず何もしない
        // (ログインしていないだけなので)

        guard auth.isAuthenticated else {
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

    // MARK: - いいね切り替え

    private func likeItem() async {

        guard let itemId = item.id else {
            return
        }

        // 未ログインならログイン画面へ

        guard auth.isAuthenticated else {

            pendingActionAfterLogin = .like
            showAuthSheet = true

            return
        }

        isLikeLoading = true
        likeErrorMessage = nil

        defer {

            isLikeLoading = false
        }

        do {

            let token = try await auth.accessToken()

            let response: LikeStatusResponse

            if isLiked {

                // ==========================================
                // すでにいいね済み → いいね解除
                // ==========================================

                response = try await api.delete(
                    "/api/items/\(itemId)/like",
                    authToken: token
                )

            } else {

                response = try await api.post(
                    "/api/items/\(itemId)/like",
                    body: EmptyRequest(),
                    authToken: token
                )
            }

            // サーバーから返された最新状態を反映

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

    private func sendNegotiationMessage() async {

        guard let itemId = item.id else {

            negotiationErrorMessage =
                "商品IDを取得できません。"

            return
        }

        let message = negotiationMessage
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !message.isEmpty else {
            return
        }

        isSendingNegotiation = true
        negotiationErrorMessage = nil
        negotiationSentMessage = nil

        do {

            let token = try await auth.accessToken()

            let request = SendNegotiationMessageRequest(
                message: message
            )

            let _: NegotiationMessage =
                try await api.post(
                    "/api/items/\(itemId.uuidString)/messages",
                    body: request,
                    authToken: token
                )

            negotiationMessage = ""

            negotiationSentMessage =
                "メッセージを送信しました。"

        } catch {

            negotiationErrorMessage =
                error.localizedDescription
        }

        isSendingNegotiation = false
    }

    private var isMyItem: Bool {

        guard let currentUserId = auth.currentUserId else {

            return false
        }

        return item.userId == currentUserId
    }

    private func deleteItem() async {

        guard !isDeleting else {
            return
        }

        guard let itemId = item.id else {

            deleteErrorMessage =
                "商品IDが取得できません。"

            return
        }

        isDeleting = true
        deleteErrorMessage = nil

        defer {

            isDeleting = false
        }

        do {

            let token = try await auth.accessToken()

            try await api.deleteNoContent(
                "/api/items/\(itemId.uuidString)",
                authToken: token
            )

            dismiss()

        } catch {

            deleteErrorMessage =
                error.localizedDescription
        }
    }
}
