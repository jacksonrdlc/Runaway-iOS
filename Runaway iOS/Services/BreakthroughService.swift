//
//  BreakthroughService.swift
//  Runaway iOS
//
//  Fetches breakthrough milestone insights from Supabase activity_insights table.
//

import Foundation
import Supabase

class BreakthroughService: ObservableObject {
    static let shared = BreakthroughService()

    @Published var milestones: [BreakthroughMilestone] = []
    @Published var isLoading = false

    private init() {}

    func fetchMilestones(for athleteId: Int) async {
        guard athleteId > 0 else { return }
        await MainActor.run { isLoading = true }

        do {
            let rows = try await fetchInsightRows(for: athleteId)
            let parsed = rows.compactMap { mapToMilestone($0) }
                .sorted { $0.detectedAt > $1.detectedAt }
            await MainActor.run {
                self.milestones = parsed
                self.isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }

    // MARK: - Private

    private func fetchInsightRows(for athleteId: Int) async throws -> [InsightRow] {
        // Fetch recent activity IDs for this athlete to scope the insight query.
        // Using athlete's activities avoids relying on RLS being configured on activity_insights.
        struct IdRow: Decodable { let id: Int }
        let activityIdRows: [IdRow] = try await supabase
            .from("activities")
            .select("id")
            .eq("athlete_id", athleteId)
            .order("activity_date", ascending: false)
            .limit(500)
            .execute()
            .value

        guard !activityIdRows.isEmpty else { return [] }

        return try await supabase
            .from("activity_insights")
            .select("activity_id, insight_data")
            .eq("insight_type", "breakthrough_milestone")
            .in("activity_id", activityIdRows.map { $0.id })
            .execute()
            .value
    }

    private func mapToMilestone(_ row: InsightRow) -> BreakthroughMilestone? {
        let data = row.insightData
        guard !data.type.isEmpty, !data.title.isEmpty else { return nil }

        // Use activity_date from insight_data (stored by edge function) if available,
        // otherwise fall back to detected_at.
        let displayDate = parseDate(data.activityDate) ?? parseDate(data.detectedAt) ?? Date()

        return BreakthroughMilestone(
            id: row.activityId,
            type: data.type,
            title: data.title,
            coachMessage: data.coachMessage,
            detectedAt: displayDate,
            activityId: row.activityId
        )
    }

    private func parseDate(_ string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: string) { return date }
        // Try date-only format (activity_date is "YYYY-MM-DD")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: string)
    }

    // MARK: - DB Row Types

    private struct InsightRow: Decodable {
        let activityId: Int
        let insightData: InsightData

        enum CodingKeys: String, CodingKey {
            case activityId = "activity_id"
            case insightData = "insight_data"
        }

        struct InsightData: Decodable {
            let type: String
            let title: String
            let coachMessage: String
            let detectedAt: String
            let activityDate: String?

            enum CodingKeys: String, CodingKey {
                case type, title
                case coachMessage = "coach_message"
                case detectedAt = "detected_at"
                case activityDate = "activity_date"
            }
        }
    }
}
