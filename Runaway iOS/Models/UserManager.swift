import SwiftUI
import Foundation

@MainActor
public final class UserManager: ObservableObject {
    @Published public var profileUser: User?
    
    public static let shared = UserManager()
    
    private init() {}
    
    public func setUser(_ user: User) {
        self.profileUser = user
    }
    
    public func clearUser() {
        self.profileUser = nil
    }
    
    public var userId: Int? {
        return profileUser?.userId
    }
}