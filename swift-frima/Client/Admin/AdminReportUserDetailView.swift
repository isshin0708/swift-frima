import SwiftUI

struct AdminReportUserDetailView: View {

    let api: NetworkClient
    let auth: AuthViewModel
    let user: AdminReportedUser

    @State private var reports: [AdminReport] = []

    @State private var accountStatus = "active"

    @State private var isLoading = true
    @State private var isUpdatingStatus = false

    @State private var errorMessage: String?
    @State private var showSuccess = false

    var body: some View {

        Group {

            if isLoading {

                ProgressView("情報を読み込み中...")

            } else if let errorMessage {

                VStack(spacing: 12) {

                    Text("情報の取得に失敗しました")
                        .font(.headline)

                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("再読み込み") {
                        Task {
                            await loadData()
                        }
                    }
                }
                .padding()

            } else {

                List {

                    // MARK: - User Information

                    Section("アカウント情報") {

                        VStack(
                            alignment: .leading,
                            spacing: 8
                        ) {

                            Text(user.userName)
                                .font(.title2)
                                .fontWeight(.bold)

                            Text("ユーザーID")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(user.id.uuidString)
                                .font(.caption)
                                .textSelection(.enabled)
                        }

                        // アカウント状態
                        Picker(
                            "アカウント状態",
                            selection: $accountStatus
                        ) {

                            Text("通常")
                                .tag("active")

                            Text("一時停止")
                                .tag("suspended")

                            Text("BAN")
                                .tag("banned")
                        }

                        Button {

                            Task {
                                await updateAccountStatus()
                            }

                        } label: {

                            if isUpdatingStatus {

                                HStack {
                                    Spacer()
                                    ProgressView()
                                    Spacer()
                                }

                            } else {

                                Text("アカウント状態を変更")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .disabled(isUpdatingStatus)
                    }

                    // MARK: - Report Count

                    Section("通報情報") {

                        HStack {

                            Text("通報件数")

                            Spacer()

                            Text("\(user.reportCount) 件")
                                .fontWeight(.bold)
                        }
                    }

                    // MARK: - Reports

                    Section("通報内容") {

                        ForEach(reports) { report in

                            VStack(
                                alignment: .leading,
                                spacing: 8
                            ) {

                                HStack {

                                    Text(report.reason)
                                        .font(.headline)

                                    Spacer()

                                    Text(
                                        statusText(
                                            report.status
                                        )
                                    )
                                    .font(.caption)
                                    .padding(
                                        .horizontal,
                                        8
                                    )
                                    .padding(
                                        .vertical,
                                        4
                                    )
                                    .background(
                                        Color.secondary
                                            .opacity(0.15)
                                    )
                                    .clipShape(
                                        Capsule()
                                    )
                                }

                                if let description = report.description,
                                   !description.isEmpty {

                                    Text(description)
                                        .font(.body)
                                }

                                if let createdAt = report.createdAt {

                                    Text(
                                        createdAt.formatted(
                                            date: .abbreviated,
                                            time: .shortened
                                        )
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }

                    if let errorMessage {

                        Section {

                            Text(errorMessage)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
        }
        .navigationTitle("通報内容")
        .alert(
            "変更しました",
            isPresented: $showSuccess
        ) {

            Button("OK") {}

        } message: {

            Text(
                "アカウント状態を変更しました。"
            )
        }
        .task {
            await loadData()
        }
    }

    // MARK: - Load Data

    private func loadData() async {

        isLoading = true
        errorMessage = nil

        do {

            let token = try await auth.accessToken()

            let response: [AdminReport] = try await api.get(
                "/api/admin/reports/users/\(user.id.uuidString)",
                authToken: token
            )

            reports = response

            // 通報ユーザー一覧APIから取得済みの状態を使用
            accountStatus = user.accountStatus

            isLoading = false

        } catch {

            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Update Account Status

    private func updateAccountStatus() async {

        guard !isUpdatingStatus else {
            return
        }

        isUpdatingStatus = true
        errorMessage = nil

        do {

            let token = try await auth.accessToken()

            let request = UpdateAccountStatusRequest(
                status: accountStatus
            )

            let _: AdminUser = try await api.patch(
                "/api/admin/users/\(user.id.uuidString)/status",
                body: request,
                authToken: token
            )

            isUpdatingStatus = false
            showSuccess = true

        } catch {

            isUpdatingStatus = false
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Status Text

    private func statusText(
        _ status: String
    ) -> String {

        switch status {

        case "pending":
            return "未対応"

        case "reviewing":
            return "審査中"

        case "resolved":
            return "対応済み"

        case "rejected":
            return "却下"

        default:
            return status
        }
    }
}

struct AdminReport: Codable, Identifiable, Sendable {

    let id: UUID
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
