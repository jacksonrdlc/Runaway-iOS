import SwiftUI
import Foundation
import Supabase
import WidgetKit

/// Unified user session manager combining authentication and profile management
/// Replaces the previous AuthManager + UserManager pattern for clearer state management
@MainActor
public final class UserSession: ObservableObject {
    // MARK: - Published Properties

    /// Authentication state
    @Published public var isAuthenticated = false

    /// Supabase authentication user
    @Published public var currentUser: Supabase.User?

    /// User profile from custom User model
    @Published public var profileUser: User?

    // MARK: - Singleton

    public static let shared = UserSession()

    // MARK: - Computed Properties

    /// Convenience accessor for user ID from profile
    public var userId: Int? {
        return profileUser?.userId
    }

    /// User's email from authentication
    public var email: String? {
        return currentUser?.email
    }

    // MARK: - Initialization

    private init() {
        print("UserSession initialized")
        Task {
            await checkAuthState()
            await listenForAuthChanges()
        }
    }

    // MARK: - Authentication State Management

    private func checkAuthState() async {
        do {
            let session = try await supabase.auth.session
            await updateAuthState(with: session.user)
        } catch {
            print("No existing session found: \(error)")
        }
    }

    private func listenForAuthChanges() async {
        for await (event, session) in supabase.auth.authStateChanges {
            await handleAuthStateChange(event: event, session: session)
        }
    }

    private func handleAuthStateChange(event: AuthChangeEvent, session: Session?) async {
        switch event {
        case .signedIn:
            if let user = session?.user {
                await updateAuthState(with: user)
            }
        case .signedOut:
            await clearSession()
            // Refresh widgets after sign out
            WidgetRefreshService.refreshForAuthUpdate()
        case .tokenRefreshed:
            if let user = session?.user {
                await updateAuthState(with: user)
            }
        default:
            break
        }
    }

    private func updateAuthState(with user: Supabase.User) async {
        await MainActor.run {
            self.currentUser = user
            self.isAuthenticated = true
        }
        // Refresh widgets after authentication state update
        WidgetRefreshService.refreshForAuthUpdate()
    }

    // MARK: - Profile Management

    /// Set the user profile
    public func setProfile(_ user: User) {
        self.profileUser = user
    }

    /// Clear both auth and profile data
    private func clearSession() async {
        await MainActor.run {
            self.currentUser = nil
            self.isAuthenticated = false
            self.profileUser = nil
        }
    }

    // MARK: - Authentication Methods

    func signUp(email: String, password: String) async throws {
        _ = try await supabase.auth.signUp(
            email: email,
            password: password
        )
        // Auth state will be updated automatically via listener
    }

    func signIn(email: String, password: String) async throws {
        _ = try await supabase.auth.signIn(
            email: email,
            password: password
        )
        // Auth state will be updated automatically via listener
    }

    func signOut() async throws {
        try await supabase.auth.signOut()
        await clearSession()
    }
}
