import SwiftUI
import StripePaymentSheet
import StripePayments
import LocalAuthentication

struct CheckoutView: View {

    let item: Item

    let api: NetworkClient

    let auth: AuthViewModel
    
    @State private var biometric = BiometricAuthManager()

    @State private var isProcessing = false
    @State private var errorMessage: String?

    @State private var paymentSheet: PaymentSheet?
    @State private var showPaymentSheet = false

    @State private var orderId: UUID?

    @State private var completed = false
    @State private var resultMessage = ""
    
    @State private var showPasswordFallback = false
    @State private var password = ""
    @State private var isPasswordProcessing = false

    var body: some View {
        Group {
            if let paymentSheet {
                checkoutContent
                    .paymentSheet(
                        isPresented: $showPaymentSheet,
                        paymentSheet: paymentSheet,
                        onCompletion: handlePaymentResult
                    )
            } else {
                checkoutContent
            }
        }
    }
    
    private func startPaymentProcess() {

        guard let itemId = item.id else {
            errorMessage = "商品情報が不正です。"
            return
        }

        isProcessing = true
        errorMessage = nil

        Task {
            do {
                let token = try await auth.accessToken()

                // ① 注文作成
                let order: OrderResponse =
                    try await api.post(
                        "/api/orders",
                        body: CreateOrderRequest(
                            itemId: itemId,
                            price: item.price
                        ),
                        authToken: token
                    )

                // ② Stripe PaymentIntent作成
                let intent: PaymentIntentResponse =
                    try await api.post(
                        "/api/orders/\(order.id.uuidString)/payment-intent",
                        body: EmptyBody(),
                        authToken: token
                    )

                await MainActor.run {

                    StripeConfig.configure()

                    var configuration =
                        PaymentSheet.Configuration()

                    configuration.merchantDisplayName =
                        "swift-frima"

                    configuration.allowsDelayedPaymentMethods =
                        false

                    paymentSheet = PaymentSheet(
                        paymentIntentClientSecret:
                            intent.clientSecret,
                        configuration: configuration
                    )

                    orderId = order.id
                    isProcessing = false
                    showPaymentSheet = true
                }

            } catch {

                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - View

    private var checkoutContent: some View {
        VStack(spacing: 20) {

            Text(item.name)
                .font(.title2)
                .bold()

            Text(
                "¥\(NSDecimalNumber(decimal: item.price).intValue)"
            )
            .font(.largeTitle)
            .bold()

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Button {
                startCheckout()
            } label: {
                if isProcessing {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    Label(
                        "Face IDで購入して支払う",
                        systemImage: "faceid"
                    )
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isProcessing)
        }
        .padding()
        .navigationTitle("購入確認")
        .alert(
            "購入結果",
            isPresented: $completed
        ) {
            Button("OK") {}
        } message: {
            Text(resultMessage)
        }
        .sheet(isPresented: $showPasswordFallback) {
            passwordFallbackView
        }
    }
    
    private var passwordFallbackView: some View {
        NavigationStack {
            VStack(spacing: 20) {

                Image(systemName: "lock.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.blue)

                Text("パスワード認証")
                    .font(.title2)
                    .bold()

                Text("Face ID認証に失敗しました。\nログインパスワードを入力してください。")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                SecureField("パスワード", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                Button {
                    authenticateWithPassword()
                } label: {
                    if isPasswordProcessing {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text("パスワードで認証")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    password.isEmpty ||
                    isPasswordProcessing
                )

                Button("キャンセル") {
                    password = ""
                    showPasswordFallback = false
                }
                .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("本人確認")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Stripe Checkout

    private func startCheckout() {

        guard item.id != nil else {
            errorMessage = "商品情報が不正です。"
            return
        }

        isProcessing = true
        errorMessage = nil

        Task {
            let authenticated = await biometric.authenticate(
                reason: "購入手続きの本人確認のためFace IDを使用します"
            )

            await MainActor.run {
                isProcessing = false

                if authenticated {
                    startPaymentProcess()
                } else {
                    showPasswordFallback = true
                }
            }
        }
    }
    
    private func authenticateWithPassword() {

        guard let email = auth.currentUserEmail else {
            errorMessage = "ログイン中のメールアドレスを取得できません。"
            return
        }

        isPasswordProcessing = true
        errorMessage = nil

        Task {
            await auth.signIn(
                email: email,
                password: password
            )

            await MainActor.run {
                isPasswordProcessing = false

                if auth.isAuthenticated {
                    password = ""
                    showPasswordFallback = false
                    startPaymentProcess()
                } else {
                    errorMessage = "パスワードが正しくありません。"
                }
            }
        }
    }
    
    

    // MARK: - Payment Result

    private func handlePaymentResult(
        _ result: PaymentSheetResult
    ) {

        switch result {

        case .completed:

            resultMessage =
                "決済を受け付けました。サーバーで決済確定を確認しています。"

            completed = true

            pollOrderStatus()

        case .canceled:

            cancelCurrentOrder()

            resultMessage =
                "決済をキャンセルしました。"

            completed = true

        case .failed(let error):

            errorMessage = error.localizedDescription

            cancelCurrentOrder()
        }
    }

    // MARK: - Order Status

    private func pollOrderStatus() {

        guard let orderId else {
            return
        }

        Task {

            for _ in 0..<10 {

                do {

                    let token =
                        try await authTokenProvider()

                    let status: PaymentStatusResponse =
                        try await api.get(
                            "/api/orders/\(orderId.uuidString)/status",
                            authToken: token
                        )

                    if status.status == "paid" {

                        await MainActor.run {
                            resultMessage =
                                "購入が確定しました。"
                            completed = true
                        }

                        return
                    }

                    if status.status == "canceled" {

                        await MainActor.run {
                            resultMessage =
                                "決済がキャンセルされました。"
                            completed = true
                        }

                        return
                    }

                } catch {

                    // Webhook反映待ちなので無視して再試行
                }

                try? await Task.sleep(
                    for: .seconds(1)
                )
            }

            await MainActor.run {

                resultMessage =
                    "決済処理の確認に時間がかかっています。"

                completed = true
            }
        }
    }

    // MARK: - Cancel

    private func cancelCurrentOrder() {

        guard let orderId else {
            return
        }

        Task {

            guard
                let token =
                    try? await authTokenProvider()
            else {
                return
            }

            try? await api.postNoContent(
                "/api/orders/\(orderId.uuidString)/cancel",
                body: EmptyBody(),
                authToken: token
            )
        }
    }
}

// MARK: - Empty Request

private struct EmptyBody: Encodable, Sendable {}

// MARK: - Stripe Configuration

private enum StripeConfig {

    static func configure() {

        guard
            let key =
                Bundle.main.object(
                    forInfoDictionaryKey:
                        "STRIPE_PUBLISHABLE_KEY"
                ) as? String,
            !key.isEmpty
        else {
            return
        }

        STPAPIClient.shared.publishableKey = key
    }
}
