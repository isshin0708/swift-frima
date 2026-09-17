import SwiftUI
import StripePaymentSheet
import StripePayments
import LocalAuthentication

struct CheckoutView: View {

    let item: Item

    let api: NetworkClient

    let authTokenProvider: () async throws -> String

    @State private var biometric = BiometricAuthManager()

    @State private var isProcessing = false
    @State private var errorMessage: String?

    @State private var paymentSheet: PaymentSheet?
    @State private var showPaymentSheet = false

    @State private var orderId: UUID?

    @State private var completed = false
    @State private var resultMessage = ""

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

            if biometric.biometryType != .faceID {
                Text("Face ID対応端末でのみ購入できます。")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

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
            .disabled(
                isProcessing ||
                biometric.biometryType != .faceID
            )
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
    }

    // MARK: - Stripe Checkout

    private func startCheckout() {

        guard let itemId = item.id else {
            errorMessage = "商品情報が不正です。"
            return
        }

        isProcessing = true
        errorMessage = nil

        Task {

            do {

                // Face ID
                guard await biometric.authenticate(
                    reason: "購入手続きの本人確認のためFace IDを使用します"
                ) else {

                    await MainActor.run {
                        isProcessing = false
                        errorMessage =
                            biometric.errorMessage ??
                            "Face ID認証に失敗しました。"
                    }

                    return
                }

                // Supabase JWT
                let token = try await authTokenProvider()

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

                    // Stripe Publishable Key設定
                    StripeConfig.configure()

                    var configuration =
                        PaymentSheet.Configuration()

                    configuration.merchantDisplayName =
                        "swift-frima"

                    configuration.allowsDelayedPaymentMethods =
                        false

                    // PaymentSheet生成
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
