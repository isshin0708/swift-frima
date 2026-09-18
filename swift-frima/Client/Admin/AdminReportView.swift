import SwiftUI

struct AdminReportView: View {
    let api: NetworkClient
    let auth: AuthViewModel

    var body: some View {
        ContentUnavailableView(
            "通報・審査",
            systemImage: "exclamationmark.triangle",
            description: Text("通報・審査機能を準備中です。")
        )
        .navigationTitle("通報・審査")
    }
}
