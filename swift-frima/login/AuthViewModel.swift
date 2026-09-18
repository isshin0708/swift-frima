import Foundation
import Observation
import Supabase

@MainActor
@Observable
final class AuthViewModel {
    // MARK: - Properties
    /// アプリ起動直後、保存済みセッションの確認が終わるまで true。
    private(set) var isLoadingSession = true
    
    private(set) var session: Session?
    private(set) var currentUserRole: String?

    var errorMessage: String?
    var isBusy = false
    
    var isAdmin: Bool {
        currentUserRole == "admin"
    }

    // MARK: - Initialization
    init() {
        Task {
            await loadInitialSession()
        }
        Task {
            await observeAuthChanges()
        }
    }

    // MARK: - Authentication State
    var isAuthenticated: Bool {
        session != nil
    }

    var currentUserEmail: String? {
        session?.user.email
    }

    // MARK: - Load Session
    private func loadInitialSession() async {
        do {
            session = try await supabase.auth.session
            await loadUserRole()
        } catch {
            session = nil
            currentUserRole = nil
        }

        isLoadingSession = false
    }
    
    private func loadUserRole() async {
        guard let userId = session?.user.id else {
            currentUserRole = nil
            return
        }

        do {
            let response: ProfileResponse = try await supabase
                .from("profiles")
                .select("role")
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value

            currentUserRole = response.role
        } catch {
            currentUserRole = nil
        }
    }

    // MARK: - Observe Authentication Changes
    private func observeAuthChanges() async {
        for await (event, newSession) in supabase.auth.authStateChanges {
            // .initialSession は supabase-swift の既知の挙動で、保存済みセッションの
            // リフレッシュに失敗すると nil が流れてくることがある。
            // 初期状態は loadInitialSession() 側ですでに正しく取得済みなので、
            // ここでは無視して上書きされないようにする。
            if event == .initialSession { continue }
            session = newSession
        }
    }

    // MARK: - Sign Up
    func signUp(email: String, password: String) async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

        do {
            _ = try await supabase.auth.signUp(email: email, password: password)
            session = try? await supabase.auth.session
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Sign In
    func signIn(email: String, password: String) async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

        do {
            try await supabase.auth.signIn(email: email, password: password)
            session = try? await supabase.auth.session
            if session != nil {
                await loadUserRole()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Sign Out
    func signOut() async {
        do {
            try await supabase.auth.signOut()
            session = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Access Token
    func accessToken() async throws -> String {
        let currentSession = try await supabase.auth.session
        return currentSession.accessToken
    }
    
    func authenticateWithPassword(
        email: String,
        password: String
    ) async -> Bool {

        do {
            try await supabase.auth.signIn(
                email: email,
                password: password
            )

            session = try? await supabase.auth.session
            errorMessage = nil

            return true

        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
    
}

private struct ProfileResponse: Decodable {
    let role: String
}

