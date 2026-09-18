import SwiftUI
import Supabase

struct ProfileDetailView: View {

    let userId: UUID
    let api: NetworkClient
    let auth: AuthViewModel

    @State private var userName = ""
    @State private var role = ""
    @State private var createdAt: Date?
    @State private var items: [Item] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isReported = false

    var body: some View {

        Group {

            if isLoading {

                ProgressView("プロフィールを読み込み中...")

            } else if let errorMessage {

                VStack(spacing: 12) {

                    Text("プロフィールの取得に失敗しました")
                        .font(.headline)

                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("再読み込み") {

                        Task {
                            await loadProfile()
                        }
                    }
                }
                .padding()

            } else {

                profileContent
            }
        }
        .navigationTitle("プロフィール")
        .task {
            await loadProfile()
        }
    }

    private var profileContent: some View {

        ScrollView {

            VStack(spacing: 20) {

                // MARK: - Icon

                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundStyle(.secondary)

                // MARK: - Username

                Text(userName)
                    .font(.title2)
                    .bold()

                // MARK: - Role

                if !role.isEmpty {

                    Text(role)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                // MARK: - Report

                if auth.currentUserId != userId {

                    if isReported {

                        Label(
                            "通報済み",
                            systemImage: "checkmark.circle"
                        )
                        .foregroundStyle(.secondary)

                    } else {

                        NavigationLink {
                            UserReportView(
                                api: api,
                                auth: auth,
                                reportedUserId: userId
                            )
                        } label: {
                            Label(
                                "このユーザーを通報",
                                systemImage: "exclamationmark.triangle"
                            )
                        }
                        .foregroundStyle(.red)
                    }
                }


                // MARK: - Created At

                if let createdAt {

                    Text("登録日：\(createdAt.formatted(date: .long,time: .omitted))"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Divider()

                // MARK: - Items

                VStack(alignment: .leading, spacing: 12) {

                    Text("出品商品")
                        .font(.title3)
                        .bold()

                    if items.isEmpty {

                        Text("出品している商品はありません。")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding()

                    } else {

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ],
                            spacing: 12
                        ) {

                            ForEach(items) { item in

                                NavigationLink {

                                    ItemDetailView(
                                        item: item,
                                        api: api,
                                        auth: auth
                                    )

                                } label: {

                                    ItemCardView(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
            }
            .padding()
        }
    }

    private func loadProfile() async {

        isLoading = true
        errorMessage = nil

        do {

            let token = try await auth.accessToken()

            // MARK: - Profile

            let profile: ProfileResponse =
                try await api.get(
                    "/api/profiles/\(userId.uuidString)",
                    authToken: token
                )

            userName = profile.username
            role = profile.role
            createdAt = profile.createdAt

            // MARK: - Items

            items = try await api.get(
                "/api/items",
                queryItems: [
                    URLQueryItem(
                        name: "user_id",
                        value: userId.uuidString
                    )
                ],
                authToken: token
            )

            // MARK: - Report Status

            // 自分自身のプロフィールでは確認不要
            if auth.currentUserId != userId {

                do {

                    let reportStatus: UserReportStatusResponse =
                        try await api.get(
                            "/api/reports/users/\(userId.uuidString)/status",
                            authToken: token
                        )

                    isReported = reportStatus.reported

                } catch {

                    // 通報状態の取得に失敗しても
                    // プロフィール自体は表示する
                    isReported = false
                }

            } else {

                isReported = false
            }

            isLoading = false

        } catch {

            isLoading = false
            errorMessage = error.localizedDescription
        }
    }
}

private struct ProfileResponse: Codable, Sendable {

    let id: UUID
    let username: String
    let role: String
    let createdAt: Date?
}
