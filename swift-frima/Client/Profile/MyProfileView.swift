import SwiftUI
import Supabase

struct MyProfileView: View {

    let api: NetworkClient
    let auth: AuthViewModel

    @State private var userName = ""
    @State private var role = ""
    @State private var createdAt: Date?
    @State private var items: [Item] = []

    @State private var isLoading = true
    @State private var errorMessage: String?

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
        .navigationTitle("マイプロフィール")
        .task {
            await loadProfile()
        }
    }

    // MARK: - Profile Content

    private var profileContent: some View {

        ScrollView {

            VStack(spacing: 20) {

                // MARK: - Icon

                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: 100,
                        height: 100
                    )
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

                // MARK: - Created At

                if let createdAt {

                    Text("登録日：\(createdAt.formatted(date: .long,time: .omitted))"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Divider()

                // MARK: - 本人確認

                VStack(alignment: .leading, spacing: 12) {

                    Text("本人確認")
                        .font(.title3)
                        .bold()

                    NavigationLink {
                        IdentityVerificationView(
                            api: api,
                            auth: auth
                        )
                    } label: {

                        HStack(spacing: 12) {

                            Image(
                                systemName:
                                    "person.text.rectangle"
                            )
                            .font(.title3)
                            .foregroundStyle(.blue)

                            VStack(
                                alignment: .leading,
                                spacing: 4
                            ) {

                                Text("本人確認を申請")
                                    .font(.headline)

                                Text(
                                    "運転免許証・マイナンバーカードを提出"
                                )
                                .font(.caption)
                                .foregroundStyle(
                                    .secondary
                                )
                            }

                            Spacer()

                            Image(
                                systemName:
                                    "chevron.right"
                            )
                            .foregroundStyle(
                                .secondary
                            )
                        }
                        .padding()
                        .background(
                            RoundedRectangle(
                                cornerRadius: 12
                            )
                            .fill(
                                Color.gray.opacity(0.1)
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )

                Divider()

                // MARK: - Items

                VStack(
                    alignment: .leading,
                    spacing: 12
                ) {

                    Text("自分の出品商品")
                        .font(.title3)
                        .bold()

                    if items.isEmpty {

                        Text(
                            "出品している商品はありません。"
                        )
                        .foregroundStyle(.secondary)
                        .frame(
                            maxWidth: .infinity
                        )
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

                                    ItemCardView(
                                        item: item
                                    )
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

    // MARK: - Load Profile

    private func loadProfile() async {

        isLoading = true
        errorMessage = nil

        do {

            // MARK: - Current User

            let token = try await auth.accessToken()

            let userId = try await getCurrentUserId()

            // MARK: - Profile

            let profile: ProfileResponse =
                try await api.get(
                    "/api/profiles/\(userId.uuidString)",
                    authToken: token
                )

            userName = profile.username
            role = profile.role
            createdAt = profile.createdAt

            // プロフィール自体は取得できたので、
            // ここで表示可能にする
            isLoading = false

            // MARK: - Items

            // 現在のItemControllerには
            // GET /api/items がまだないため、
            // 商品取得に失敗してもプロフィール表示は維持する。

            do {

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

            } catch {

                items = []
            }

        } catch {

            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Current User ID

    private func getCurrentUserId() async throws -> UUID {

        let session = try await supabase.auth.session

        return session.user.id
    }
}

// MARK: - Profile Response

private struct ProfileResponse: Codable, Sendable {

    let id: UUID
    let username: String
    let role: String
    let createdAt: Date?
}
