import Foundation
import Supabase

class AuthService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    
    static let shared = AuthService()
    private let supabase = SupabaseHelper.shared.client
    
    func signUp(email: String, password: String) async throws {
        let auth = try await supabase.auth.signUp(
            email: email,
            password: password
        )
        DispatchQueue.main.async {
            self.currentUser = auth.user
            self.isAuthenticated = auth.user != nil
        }
    }
    
    func signIn(email: String, password: String) async throws {
        let auth = try await supabase.auth.signIn(
            email: email,
            password: password
        )
        DispatchQueue.main.async {
            self.currentUser = auth.user
            self.isAuthenticated = auth.user != nil
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
