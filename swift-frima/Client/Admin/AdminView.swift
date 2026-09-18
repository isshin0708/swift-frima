import SwiftUI

struct AdminView: View {
    let api: NetworkClient
    let auth: AuthViewModel

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("管理者画面")
                        .font(.largeTitle.bold())

                    Text("swift-frima 管理システム")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section("管理") {
                NavigationLink {
                    AdminItemListView(
                        api: api,
                        auth: auth
                    )
                } label: {
                    Label(
                        "商品管理",
                        systemImage: "bag"
                    )
                }

                NavigationLink {
                    AdminUserListView(
                        api: api,
                        auth: auth
                    )
                } label: {
                    Label(
                        "ユーザー管理",
                        systemImage: "person.2"
                    )
                }

                NavigationLink {
                    AdminReportView(
                        api: api,
                        auth: auth
                    )
                } label: {
                    Label(
                        "通報・審査",
                        systemImage: "exclamationmark.triangle"
                    )
                }
            }
        }
        .navigationTitle("管理者")
    }
}
