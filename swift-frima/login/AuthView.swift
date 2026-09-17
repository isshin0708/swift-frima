import SwiftUI

struct AuthView: View {
    @Bindable var viewModel: AuthViewModel

    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var showEmailConfirmationNotice = false
    /// プログラムからmodeを変更する際に、onChangeによるリセットを抑止するためのフラグ
    @State private var isSwitchingModeProgrammatically = false

    enum Mode: String, CaseIterable {
        case signIn = "ログイン"
        case signUp = "会員登録"
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Login / Sign Up Switch
                Section {
                    Picker("認証", selection: $mode) {
                        ForEach(Mode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: mode) { _, _ in
                        // 登録成功後の自動切替では、確認メールの案内を消さない
                        guard !isSwitchingModeProgrammatically else {
                            isSwitchingModeProgrammatically = false
                            return
                        }
                        viewModel.errorMessage = nil
                        showEmailConfirmationNotice = false
                    }
                }

                // MARK: - Account Information
                Section("アカウント情報") {
                    TextField("メールアドレス", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField("パスワード", text: $password)
                        .textContentType(mode == .signUp ? .newPassword : .password)
                }

                // MARK: - Error
                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                // MARK: - Email Confirmation Notice
                if showEmailConfirmationNotice {
                    Section {
                        Label(
                            "確認メールを送信しました。メール内のリンクを開いてからログインしてください。",
                            systemImage: "envelope"
                        )
                        .font(.caption)
                        .foregroundStyle(.blue)
                    }
                }

                // MARK: - Submit Button
                Section {
                    Button {
                        submit()
                    } label: {
                        if viewModel.isBusy {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(mode == .signIn ? "ログイン" : "会員登録")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(
                        viewModel.isBusy ||
                        email.isEmpty ||
                        password.count < 6
                    )
                }
            }
            .navigationTitle("swift-frima")
        }
    }

    // MARK: - Submit Logic
    private func submit() {
        showEmailConfirmationNotice = false

        Task {
            switch mode {
            case .signIn:
                await viewModel.signIn(email: email, password: password)

            case .signUp:
                await viewModel.signUp(email: email, password: password)

                if viewModel.errorMessage == nil && !viewModel.isAuthenticated {
                    // 先にフラグを立ててからmodeを変更することで、onChangeでのリセットを回避する
                    isSwitchingModeProgrammatically = true
                    mode = .signIn
                    showEmailConfirmationNotice = true
                    // パスワードは残さずクリアし、ログインし直してもらう
                    password = ""
                }
            }
        }
    }
}
