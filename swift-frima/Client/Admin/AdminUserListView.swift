import SwiftUI

struct AdminUserListView: View {
    let api: NetworkClient
    let auth: AuthViewModel

    var body: some View {
        ContentUnavailableView(
            "ユーザー管理",
            systemImage: "person.2",
            description: Text("ユーザー管理機能を準備中です。")
        )
        .navigationTitle("ユーザー管理")
    }
}
