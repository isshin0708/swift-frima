import SwiftUI

struct AdminUser: Codable, Identifiable, Sendable {
    let id: UUID?
    let userName: String
    let role: String
    let accountStatus: String
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userName = "user_name"
        case role
        case accountStatus = "account_status"
        case createdAt = "created_at"
    }
}

struct AdminUserListView: View {
    let api: NetworkClient
    let auth: AuthViewModel

    @State private var users: [AdminUser] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("ユーザーを読み込み中...")
            } else if let errorMessage {
                VStack(spacing: 12) {
                    Text("ユーザーの取得に失敗しました")
                        .font(.headline)

                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("再読み込み") {
                        Task {
                            await loadUsers()
                        }
                    }
                }
                .padding()
            } else {
                List(users) { user in
                    userRow(user)
                }
            }
        }
        .navigationTitle("ユーザー管理")
        .task {
            await loadUsers()
        }
    }

    private func userRow(_ user: AdminUser) -> some View {
        VStack(alignment: .leading, spacing: 10) {

            Text(user.userName)
                .font(.headline)

            Text(user.id?.uuidString ?? "IDなし")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(statusText(user.accountStatus))
                .font(.subheadline)

            Menu {
                Button("通常に戻す") {
                    Task {
                        await updateStatus(
                            user: user,
                            status: "active"
                        )
                    }
                }

                Button("一時停止") {
                    Task {
                        await updateStatus(
                            user: user,
                            status: "suspended"
                        )
                    }
                }

                Button("BAN", role: .destructive) {
                    Task {
                        await updateStatus(
                            user: user,
                            status: "banned"
                        )
                    }
                }

            } label: {
                Label(
                    "アカウント状態を変更",
                    systemImage: "person.crop.circle.badge.checkmark"
                )
            }
        }
        .padding(.vertical, 6)
    }

    private func statusText(_ status: String) -> String {
        switch status {
        case "active":
            return "状態：通常"

        case "suspended":
            return "状態：一時停止"

        case "banned":
            return "状態：BAN"

        default:
            return "状態：不明"
        }
    }

    private func loadUsers() async {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            let token = try await auth.accessToken()

            users = try await api.get(
                "/api/admin/users",
                authToken: token
            )

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateStatus(
        user: AdminUser,
        status: String
    ) async {

        guard let userId = user.id else {
            return
        }

        do {
            let token = try await auth.accessToken()

            let request = UpdateAccountStatusRequest(
                status: status
            )

            let _: AdminUser = try await api.patch(
                "/api/admin/users/\(userId.uuidString)/status",
                body: request,
                authToken: token
            )

            await loadUsers()

        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct UpdateAccountStatusRequest: Codable, Sendable {
    let status: String
}
