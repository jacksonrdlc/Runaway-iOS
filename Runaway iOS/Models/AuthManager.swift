import SwiftUI
import Foundation
import Supabase

// Import User model from the same directory
@MainActor
public final class AuthManager: ObservableObject {
    @Published public var isAuthenticated = false
    @Published public var currentUser: User?
    
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
        case .tokenRefreshed:
            if let user = session?.user {
                await updateAuthState(with: user)
            }
        default:
            break
        }
    }
    
    private func updateAuthState(with user: Supabase.User) async {
        let appUser = User(
            id: user.id,
            aud: user.aud,
            role: user.role ?? "authenticated",
            email: user.email ?? "",
            emailConfirmedAt: user.emailConfirmedAt,
            phone: user.phone,
            lastSignInAt: user.lastSignInAt,
            createdAt: user.createdAt,
            updatedAt: user.updatedAt ?? user.createdAt
        )
        
        await MainActor.run {
            self.currentUser = appUser
            self.isAuthenticated = true
        }
    }

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
        DispatchQueue.main.async {
            self.currentUser = nil
            self.isAuthenticated = false
        }
    }
}