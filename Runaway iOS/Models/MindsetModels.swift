import Foundation

struct MindsetProfile: Equatable, Sendable {
    let runnerIdentity: String
    let identitySummary: String
    let whyIRun: String
    let coreValues: [String]
}

struct RunnerIdentityMilestone: Identifiable, Decodable {
    let id: UUID
    let milestoneKey: String
    let label: String
    let description: String
    let earned: Bool
    let earnedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case milestoneKey  = "milestone_key"
        case label
        case description
        case earned
        case earnedAt      = "earned_at"
    }
}
