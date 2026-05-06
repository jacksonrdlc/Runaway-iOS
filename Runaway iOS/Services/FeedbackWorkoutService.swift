import Foundation
import Supabase

struct FeedbackWorkoutService {
    private struct Request: Encodable {
        let athlete_id: Int
        let activity_id: Int
    }

    private struct Response: Decodable {
        let feedback: String
        let effort_label: String
    }

    static func generateFeedback(athleteId: Int, activityId: Int) async throws {
        let _: Response = try await supabase.functions.invoke(
            "feedback-workout",
            options: .init(body: Request(athlete_id: athleteId, activity_id: activityId))
        )
        #if DEBUG
        print("✅ FeedbackWorkoutService: feedback generated for activity \(activityId)")
        #endif
    }
}
