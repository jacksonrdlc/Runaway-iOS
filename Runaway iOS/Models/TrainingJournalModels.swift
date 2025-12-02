//
//  TrainingJournalModels.swift
//  Runaway iOS
//
//  Models for AI-generated weekly training journal entries
//

import Foundation

// MARK: - Training Journal Entry
struct TrainingJournal: Codable, Identifiable {
    let id: String
    let athleteId: Int
    let weekStartDate: String
    let weekEndDate: String
    let narrative: String
    let weekStats: WeekStats
    let insights: [JournalInsight]
    let generationModel: String?
    let generationTimestamp: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case athleteId = "athlete_id"
        case weekStartDate = "week_start_date"
        case weekEndDate = "week_end_date"
        case narrative
        case weekStats = "week_stats"
        case insights
        case generationModel = "generation_model"
        case generationTimestamp = "generation_timestamp"
        case updatedAt = "updated_at"
        // Note: goalProgress is ignored for now (complex JSONB field)
    }

    // Computed properties for display
    var weekStartDateFormatted: Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: weekStartDate)
    }

    var weekEndDateFormatted: Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: weekEndDate)
    }

    var weekRangeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        if let start = weekStartDateFormatted, let end = weekEndDateFormatted {
            let endFormatter = DateFormatter()
            if Calendar.current.component(.month, from: start) == Calendar.current.component(.month, from: end) {
                endFormatter.dateFormat = "d"
            } else {
                endFormatter.dateFormat = "MMM d"
            }
            return "\(formatter.string(from: start)) - \(endFormatter.string(from: end))"
        }
        return "Week"
    }
}

// MARK: - Week Statistics
struct WeekStats: Codable {
    let totalDistanceMiles: String
    let totalTimeHours: String
    let activitiesCount: Int
    let avgPace: String
    let longestRunMiles: String
    let elevationGainFeet: Int?
    let avgHeartRate: Int?

    enum CodingKeys: String, CodingKey {
        case totalDistanceMiles = "total_distance_miles"
        case totalTimeHours = "total_time_hours"
        case activitiesCount = "activities_count"
        case avgPace = "avg_pace"
        case longestRunMiles = "longest_run_miles"
        case elevationGainFeet = "elevation_gain_feet"
        case avgHeartRate = "avg_heart_rate"
    }

    // Computed properties for display
    var totalDistance: Double {
        Double(totalDistanceMiles) ?? 0.0
    }

    var totalTime: Double {
        Double(totalTimeHours) ?? 0.0
    }

    var longestRun: Double {
        Double(longestRunMiles) ?? 0.0
    }
}

// MARK: - Journal Insight
struct JournalInsight: Codable, Identifiable {
    let type: InsightType
    let text: String

    var id: String { text }

    enum InsightType: String, Codable {
        case achievement
        case pattern
        case recommendation
        case observation

        var icon: String {
            switch self {
            case .achievement:
                return "star.fill"
            case .pattern:
                return "chart.line.uptrend.xyaxis"
            case .recommendation:
                return "lightbulb.fill"
            case .observation:
                return "eye.fill"
            }
        }

        var color: String {
            switch self {
            case .achievement:
                return "yellow"
            case .pattern:
                return "blue"
            case .recommendation:
                return "green"
            case .observation:
                return "purple"
            }
        }
    }
}

// MARK: - API Response
struct JournalAPIResponse: Codable {
    let success: Bool
    let journal: TrainingJournal?
    let entries: [TrainingJournal]?
    let count: Int?
    let generated: Int?
    let error: APIError?

    struct APIError: Codable {
        let code: String
        let message: String
    }
}
