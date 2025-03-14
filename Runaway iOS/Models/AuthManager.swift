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
    }

    func signUp(email: String, password: String) async throws {
        let auth = try await supabase.auth.signUp(
            email: email,
            password: password
        )
        
        let user = User(
            id: auth.user.id,
            aud: auth.user.aud,
            role: auth.user.role ?? "authenticated",
            email: auth.user.email ?? "",
            emailConfirmedAt: auth.user.emailConfirmedAt,
            phone: auth.user.phone,
            lastSignInAt: auth.user.lastSignInAt,
            createdAt: auth.user.createdAt,
            updatedAt: (auth.user.updatedAt ?? auth.user.createdAt)
        )
        
        DispatchQueue.main.async {
            self.currentUser = user
            self.isAuthenticated = true
        }
    }
    
    func signIn(email: String, password: String) async throws {
        let auth = try await supabase.auth.signIn(
            email: email,
            password: password
        )
        
        let user = User(
            id: auth.user.id,
            aud: auth.user.aud,
            role: auth.user.role ?? "authenticated",
            email: auth.user.email ?? "",
            emailConfirmedAt: auth.user.emailConfirmedAt,
            phone: auth.user.phone,
            lastSignInAt: auth.user.lastSignInAt,
            createdAt: auth.user.createdAt,
            updatedAt: (auth.user.updatedAt ?? auth.user.createdAt)
        )
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        DispatchQueue.main.async {
            self.currentUser = user
            self.isAuthenticated = true
        }
    }
    
    func signOut() async throws {
        try await supabase.auth.signOut()
        DispatchQueue.main.async {
            self.currentUser = nil
            self.isAuthenticated = false
        }
    }
}
