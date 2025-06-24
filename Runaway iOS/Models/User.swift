import Foundation

public struct User: Codable, Identifiable {
    public let id: UUID
    public let authId: UUID
    public let userId: Int
    public let createdAt: Date?
    public let updatedAt: Date?
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.userId = try container.decode(Int.self, forKey: .userId)
        self.id = UUID(uuidString: String(format: "%08x-0000-0000-0000-000000000000", self.userId)) ?? UUID()
        
        self.authId = try container.decode(UUID.self, forKey: .authId)
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
    
    public init(authId: UUID, userId: Int, createdAt: Date?, updatedAt: Date?) {
        self.id = UUID()
        self.authId = authId
        self.userId = userId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case authId = "auth_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
} 
