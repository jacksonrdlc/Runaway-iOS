import Foundation

public struct User: Codable, Identifiable, Sendable {
    public let id: UUID
    public let authId: UUID?  // Make optional since it might not exist in athletes table
    public let userId: Int    // This maps to athletes.id (bigint)
    public let createdAt: Date?
    public let updatedAt: Date?
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.userId = try container.decode(Int.self, forKey: .userId)
        self.id = UUID(uuidString: String(format: "%08x-0000-0000-0000-000000000000", self.userId)) ?? UUID()

        self.authId = try container.decodeIfPresent(UUID.self, forKey: .authId)
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
    
    public init(authId: UUID?, userId: Int, createdAt: Date?, updatedAt: Date?) {
        self.id = UUID()
        self.authId = authId
        self.userId = userId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case userId = "id"  // athletes.id
        case authId = "auth_user_id"  // Link to auth.users.id
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
