//
//  SetDailyCommitmentIntent.swift
//  RunawayWidget
//
//  AppIntent that lets users set their daily commitment directly from the widget
//  without opening the app. Makes a direct REST call to Supabase.
//

import AppIntents
import WidgetKit

// MARK: - Activity Type Enum

enum CommitmentActivityAppEnum: String, AppEnum {
    case run
    case walk
    case workout
    case yoga

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Activity Type" }
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .run:     DisplayRepresentation(title: "Run",     image: .init(systemName: "figure.run")),
        .walk:    DisplayRepresentation(title: "Walk",    image: .init(systemName: "figure.walk")),
        .workout: DisplayRepresentation(title: "Workout", image: .init(systemName: "dumbbell")),
        .yoga:    DisplayRepresentation(title: "Yoga",    image: .init(systemName: "figure.yoga")),
    ]

    var iconName: String {
        switch self {
        case .run: return "figure.run"
        case .walk: return "figure.walk"
        case .workout: return "dumbbell"
        case .yoga: return "figure.yoga"
        }
    }

    var displayName: String { rawValue.capitalized }
}

// MARK: - AppIntent

struct SetDailyCommitmentIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Daily Commitment"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Activity Type") var activityType: CommitmentActivityAppEnum

    init() {}

    init(activityType: CommitmentActivityAppEnum) {
        self.activityType = activityType
    }

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.com.jackrudelic.runawayios")
        guard
            let supabaseURL = defaults?.string(forKey: "widget_supabase_url"),
            let supabaseKey = defaults?.string(forKey: "widget_supabase_key"),
            let athleteId = defaults?.value(forKey: "widget_athlete_id") as? Int,
            athleteId > 0,
            !supabaseURL.isEmpty,
            !supabaseKey.isEmpty
        else { return .result() }

        // Optimistic UI update — show commitment immediately
        defaults?.set(activityType.rawValue, forKey: "todays_commitment_type")
        defaults?.set(false, forKey: "todays_commitment_fulfilled")
        WidgetCenter.shared.reloadAllTimelines()

        // REST upsert to Supabase daily_commitments table
        let today = Calendar.current.startOfDay(for: Date())
        let dateString = ISO8601DateFormatter().string(from: today).prefix(10)
        let body: [String: Any] = [
            "athlete_id": athleteId,
            "activity_type": activityType.rawValue,
            "commitment_date": String(dateString),
            "is_fulfilled": false,
            "commitment_level": "standard"
        ]

        guard let url = URL(string: "\(supabaseURL)/rest/v1/daily_commitments") else {
            return .result()
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal,resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        _ = try? await URLSession.shared.data(for: request)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
