import Foundation
import Observation
import Supabase

@MainActor
@Observable
final class AuthViewModel {
    // MARK: - Properties
    private(set) var session: Session?

    var errorMessage: String?
    var isBusy = false

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
        } catch {
            session = nil
        }
    }

    // MARK: - Observe Authentication Changes
    private func observeAuthChanges() async {
        for await (_, newSession) in supabase.auth.authStateChanges {
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
            // メール確認が有効な設定の場合、確認が完了するまでセッションは発行されない
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
}
