import Foundation

struct MilestoneService {
    static let didUpdateNotification = Notification.Name("milestonesDidUpdate")

    static func checkMilestones(athleteId: Int, activityId: Int) async throws {
        struct Request: Encodable {
            let athleteId: Int
            let activityId: Int
            enum CodingKeys: String, CodingKey {
                case athleteId  = "athlete_id"
                case activityId = "activity_id"
            }
        }
        struct Response: Decodable {
            let newlyEarned: [String]
            enum CodingKeys: String, CodingKey { case newlyEarned = "newly_earned" }
        }

        let response: Response = try await supabase.functions.invoke(
            "check-milestones",
            options: .init(body: Request(athleteId: athleteId, activityId: activityId))
        )

        if !response.newlyEarned.isEmpty {
            NotificationCenter.default.post(name: didUpdateNotification, object: nil)
        }
    }
}
