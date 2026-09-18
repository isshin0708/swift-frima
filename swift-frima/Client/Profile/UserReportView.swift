import SwiftUI

struct UserReportView: View {

    let api: NetworkClient
    let auth: AuthViewModel
    let reportedUserId: UUID

    @Environment(\.dismiss) private var dismiss

    @State private var selectedReason = "迷惑行為"
    @State private var description = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    private let reasons = [
        "迷惑行為",
        "詐欺・不正行為",
        "不適切な内容",
        "規約違反",
        "その他"
    ]

    var body: some View {

        Form {

            // MARK: - Report Reason

            Section("通報理由") {

                Picker(
                    "理由",
                    selection: $selectedReason
                ) {

                    ForEach(reasons, id: \.self) { reason in
                        Text(reason)
                    }
                }
            }

            // MARK: - Description

            Section("詳細") {

                TextEditor(text: $description)
                    .frame(minHeight: 120)
            }

            // MARK: - Send

            Section {

                Button {

                    Task {
                        await sendReport()
                    }

                } label: {

                    if isSending {

                        ProgressView()
                            .frame(maxWidth: .infinity)

                    } else {

                        Text("通報する")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isSending)
            }

            // MARK: - Error

            if let errorMessage {

                Section {

                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("ユーザーを通報")

        // MARK: - Success Alert

        .alert(
            "通報しました",
            isPresented: $showSuccess
        ) {

            Button("OK") {
                dismiss()
            }

        } message: {

            Text("通報を受け付けました。")
        }
    }

    // MARK: - Send Report

    private func sendReport() async {

        // 二重送信防止
        guard !isSending else {
            return
        }

        isSending = true
        errorMessage = nil

        defer {
            isSending = false
        }

        do {

            // 認証トークン取得
            let token = try await auth.accessToken()

            // 通報リクエスト
            let request = CreateUserReportRequest(
                reportedUserId: reportedUserId,
                reason: selectedReason,
                description: description.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty
                    ? nil
                    : description.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
            )

            // APIへ送信
            let _: ReportResponse = try await api.post(
                "/api/reports/users",
                body: request,
                authToken: token
            )

            // 成功
            showSuccess = true

        } catch {

            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Create User Report Request

struct CreateUserReportRequest: Codable, Sendable {

    let reportedUserId: UUID
    let reason: String
    let description: String?

    enum CodingKeys: String, CodingKey {

        case reportedUserId = "reported_user_id"
        case reason
        case description
    }
}

// MARK: - Report Response

struct ReportResponse: Codable, Sendable {

    let id: UUID?
    let reporterId: UUID
    let reportedUserId: UUID
    let reason: String
    let description: String?
    let status: String
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {

        case id
        case reporterId = "reporter_id"
        case reportedUserId = "reported_user_id"
        case reason
        case description
        case status
        case createdAt = "created_at"
    }
}

// MARK: - Report Status Response

struct UserReportStatusResponse: Codable, Sendable {

    let reported: Bool
}
