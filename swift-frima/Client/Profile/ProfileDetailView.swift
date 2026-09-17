import SwiftUI

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

                // アイコン
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundStyle(.secondary)

                // ユーザー名
                Text(userName)
                    .font(.title2)
                    .bold()

                // role
                if !role.isEmpty {
                    Text(role)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // 登録日
                if let createdAt {
                    Text("登録日：\(createdAt.formatted(date: .long, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // 出品商品
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
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
    }

    private func loadProfile() async {
        isLoading = true
        errorMessage = nil

        do {
            let profile: ProfileResponse =
                try await api.get("/api/profiles/\(userId.uuidString)")

            userName = profile.userName
            role = profile.role
            createdAt = profile.createdAt

            items = try await api.get(
                "/api/items",
                queryItems: [
                    URLQueryItem(
                        name: "user_id",
                        value: userId.uuidString
                    )
                ]
            )

            isLoading = false

        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }
}

private struct ProfileResponse: Codable, Sendable {
    let id: UUID
    let userName: String
    let role: String
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userName = "user_name"
        case role
        case createdAt = "created_at"
    }
}
