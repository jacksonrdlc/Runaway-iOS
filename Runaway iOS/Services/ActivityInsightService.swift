import Foundation

struct ActivityInsightService {
    static func fetchFeedback(activityId: Int) async throws -> String? {
        struct Row: Decodable {
            let insightData: InsightData
            enum CodingKeys: String, CodingKey { case insightData = "insight_data" }
        }
        // The `feedback-workout` edge function writes the encouragement text into
        // `insight_data.content` (not `feedback`). Match that exactly.
        struct InsightData: Decodable {
            let content: String
        }

        let rows: [Row] = try await supabase
            .from("activity_insights")
            .select("insight_data")
            .eq("activity_id", value: activityId)
            .eq("insight_type", value: "adlerian_feedback")
            .limit(1)
            .execute()
            .value

        return rows.first?.insightData.content
    }
}
