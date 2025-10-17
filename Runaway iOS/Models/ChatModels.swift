//
//  ChatModels.swift
//  Runaway iOS
//
//  Models for Chat API with AI Running Coach
//

import Foundation

// MARK: - Request Models

struct ChatRequest: Codable {
    let message: String
    let userId: String?
    let conversationId: String?
    let context: ChatContext?

    enum CodingKeys: String, CodingKey {
        case message
        case userId = "user_id"
        case conversationId = "conversation_id"
        case context
    }
}

struct ChatContext: Codable {
    let recentActivity: RecentActivityContext?
    let activities: [ActivityContext]?
    let weeklyMileage: Double?
    let goal: GoalContext?
    let profile: ProfileContext?

    enum CodingKeys: String, CodingKey {
        case recentActivity = "recent_activity"
        case activities
        case weeklyMileage = "weekly_mileage"
        case goal
        case profile
    }
}

struct RecentActivityContext: Codable {
    let distance: Double  // miles
    let avgPace: String   // MM:SS format
    let duration: Int?    // seconds
    let date: String      // ISO 8601
    let heartRateAvg: Int?
    let elevationGain: Double?

    enum CodingKeys: String, CodingKey {
        case distance
        case avgPace = "avg_pace"
        case duration
        case date
        case heartRateAvg = "heart_rate_avg"
        case elevationGain = "elevation_gain"
    }
}

struct ActivityContext: Codable {
    let distance: Double
    let avgPace: String
    let date: String

    enum CodingKeys: String, CodingKey {
        case distance
        case avgPace = "avg_pace"
        case date
    }
}

struct GoalContext: Codable {
    let type: String       // "race", "distance", "fitness"
    let distance: String?  // "5K", "10K", "Half", "Marathon"
    let targetTime: String?
    let raceDate: String?

    enum CodingKeys: String, CodingKey {
        case type
        case distance
        case targetTime = "target_time"
        case raceDate = "race_date"
    }
}

struct ProfileContext: Codable {
    let age: Int?
    let gender: String?
    let experienceLevel: String?
    let bestTimes: [String: String]?

    enum CodingKeys: String, CodingKey {
        case age
        case gender
        case experienceLevel = "experience_level"
        case bestTimes = "best_times"
    }
}

// MARK: - Response Models

struct ChatResponse: Codable {
    let success: Bool
    let message: String
    let conversationId: String
    let triggeredAnalysis: TriggeredAnalysis?
    let errorMessage: String?
    let processingTime: Double

    enum CodingKeys: String, CodingKey {
        case success
        case message
        case conversationId = "conversation_id"
        case triggeredAnalysis = "triggered_analysis"
        case errorMessage = "error_message"
        case processingTime = "processing_time"
    }
}

struct TriggeredAnalysis: Codable, Equatable {
    let type: String  // "performance", "goal", "plan"
    let data: AnyCodable

    static func == (lhs: TriggeredAnalysis, rhs: TriggeredAnalysis) -> Bool {
        lhs.type == rhs.type
    }

    enum AnalysisType {
        case performance
        case goal
        case plan
        case unknown

        init(from string: String) {
            switch string {
            case "performance": self = .performance
            case "goal": self = .goal
            case "plan": self = .plan
            default: self = .unknown
            }
        }
    }
}

// Helper for decoding arbitrary JSON
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let arrayValue as [Any]:
            try container.encode(arrayValue.map { AnyCodable($0) })
        case let dictValue as [String: Any]:
            try container.encode(dictValue.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - Conversation Models

struct ConversationResponse: Codable {
    let success: Bool
    let conversation: Conversation
}

struct Conversation: Codable, Identifiable {
    let id: String
    let userId: String
    let messages: [ChatMessage]
    let context: ChatContext?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case messages
        case context
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ChatMessage: Codable, Identifiable, Equatable {
    let id: String
    let role: String  // "user" or "assistant"
    let content: String
    let timestamp: String

    init(id: String = UUID().uuidString, role: String, content: String, timestamp: String = ISO8601DateFormatter().string(from: Date())) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Conversation List

struct ConversationsListResponse: Codable {
    let success: Bool
    let conversations: [ConversationSummary]
}

struct ConversationSummary: Codable, Identifiable {
    let id: String
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Delete Response

struct DeleteConversationResponse: Codable {
    let success: Bool
    let message: String
}

// MARK: - Error Models

enum ChatError: Error, LocalizedError {
    case invalidResponse
    case unauthorized
    case notFound
    case serverError(String)
    case networkError(Error)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Authentication failed. Please log in again."
        case .notFound:
            return "Conversation not found"
        case .serverError(let message):
            return message
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Data parsing error: \(error.localizedDescription)"
        }
    }
}
