import Foundation

public struct User: Codable, Identifiable {
    public let id: UUID
    public let aud: String
    public let role: String
    public let email: String
    public let emailConfirmedAt: Date?
    public let phone: String?
    public let lastSignInAt: Date?
    public let createdAt: Date
    public let updatedAt: Date
    
    public init(id: UUID, aud: String, role: String, email: String, emailConfirmedAt: Date?, phone: String?, lastSignInAt: Date?, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.aud = aud
        self.role = role
        self.email = email
        self.emailConfirmedAt = emailConfirmedAt
        self.phone = phone
        self.lastSignInAt = lastSignInAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case aud
        case role
        case email
        case emailConfirmedAt = "email_confirmed_at"
        case phone
        case lastSignInAt = "last_sign_in_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
} 
