import SwiftUI

struct AdminReportView: View {

    let api: NetworkClient
    let auth: AuthViewModel

    @State private var users: [AdminReportedUser] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {

        Group {

            if isLoading {

                ProgressView("通報情報を読み込み中...")

            } else if let errorMessage {

                VStack(spacing: 12) {

                    Text("通報情報の取得に失敗しました")
                        .font(.headline)

                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("再読み込み") {
                        Task {
                            await loadReports()
                        }
                    }
                }
                .padding()

            } else if users.isEmpty {

                ContentUnavailableView(
                    "通報はありません",
                    systemImage: "checkmark.circle",
                    description: Text(
                        "現在、通報されているユーザーはいません。"
                    )
                )

            } else {

                List {

                    Section("通報されたユーザー") {

                        ForEach(users) { user in

                            NavigationLink {

                                AdminReportUserDetailView(
                                    api: api,
                                    auth: auth,
                                    user: user
                                )

                            } label: {

                                HStack(spacing: 12) {

                                    Image(
                                        systemName: "person.circle.fill"
                                    )
                                    .font(.system(size: 36))
                                    .foregroundStyle(.secondary)

                                    VStack(
                                        alignment: .leading,
                                        spacing: 4
                                    ) {

                                        Text(user.userName)
                                            .font(.headline)

                                        Text(
                                            "通報 \(user.reportCount) 件"
                                        )
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Text(
                                        "\(user.reportCount)"
                                    )
                                    .font(.headline)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("通報・審査")
        .task {
            await loadReports()
        }
    }

    // MARK: - Load Reports

    private func loadReports() async {

        isLoading = true
        errorMessage = nil

        do {

            let token = try await auth.accessToken()

            users = try await api.get(
                "/api/admin/reports/users",
                authToken: token
            )

            isLoading = false

        } catch {

            isLoading = false
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Admin Reported User

struct AdminReportedUser: Codable, Identifiable, Sendable {

    let id: UUID
    let userName: String
    let reportCount: Int
    let accountStatus: String

    enum CodingKeys: String, CodingKey {
        case id
        case userName = "user_name"
        case reportCount = "report_count"
        case accountStatus = "account_status"
    }
}

