import SwiftUI
import Foundation
import Supabase
import WidgetKit

// Import User model from the same directory
@MainActor
public final class AuthManager: ObservableObject {
    @Published public var isAuthenticated = false
    @Published public var currentUser: Supabase.User?
    
    public static let shared = AuthManager()
    
    private init() {
        print("AuthManager initialized")
        Task {
            await checkAuthState()
            await listenForAuthChanges()
        }
    }
    
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
            await MainActor.run {
                self.currentUser = nil
                self.isAuthenticated = false
            }
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

    func signUp(email: String, password: String) async throws {
        AnalyticsService.shared.track(.signupStarted, category: .authentication)

        do {
            _ = try await supabase.auth.signUp(
                email: email,
                password: password
            )
            // Auth state will be updated automatically via listener
            AnalyticsService.shared.track(.signupCompleted, category: .authentication)
        } catch {
            AnalyticsService.shared.track(.loginFailed, category: .authentication, properties: [
                "error": error.localizedDescription,
                "type": "signup"
            ])
            throw error
        }
    }

    func signIn(email: String, password: String) async throws {
        AnalyticsService.shared.track(.loginStarted, category: .authentication)

        do {
            _ = try await supabase.auth.signIn(
                email: email,
                password: password
            )
            // Auth state will be updated automatically via listener
            AnalyticsService.shared.track(.loginCompleted, category: .authentication)
        } catch {
            AnalyticsService.shared.track(.loginFailed, category: .authentication, properties: [
                "error": error.localizedDescription
            ])
            throw error
        }
    }

    func signOut() async throws {
        try await supabase.auth.signOut()
        DispatchQueue.main.async {
            self.currentUser = nil
            self.isAuthenticated = false
        }
        AnalyticsService.shared.track(.logoutCompleted, category: .authentication)
    }
}
