//
//  SetDailyCommitmentIntent.swift
//  RunawayWidget
//
//  AppIntent that lets users set their daily commitment directly from the widget
//  without opening the app. Makes a direct REST call to Supabase.
//

import AppIntents
import Foundation
import WidgetKit

// MARK: - Activity Type Enum

enum CommitmentActivityAppEnum: String, AppEnum {
    // rawValues match CommitmentActivityType in the main app so Supabase rows decode correctly
    case run = "Run"
    case walk = "Walk"
    case workout = "Weight Training"
    case yoga = "Yoga"

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

    var displayName: String {
        switch self {
        case .run: return "Run"
        case .walk: return "Walk"
        case .workout: return "Workout"
        case .yoga: return "Yoga"
        }
    }
}

// MARK: - AppIntent

struct SetDailyCommitmentIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Daily Commitment"
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Activity Type") var activityType: CommitmentActivityAppEnum

    init() {}

    init(activityType: CommitmentActivityAppEnum) {
        self.activityType = activityType
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let defaults = UserDefaults(suiteName: "group.com.jackrudelic.runawayios") else {
            return .result(dialog: "Open Runaway to save your commitment.")
        }

        // The extension has no secure shared user-token store. Queue the request
        // for the authenticated app instead of using the publishable key as JWT.
        let client = DailyCommitmentIntentClient(
            defaults: defaults,
            accessToken: { nil }
        )
        let outcome = await client.setCommitment(activityType: activityType.rawValue)

        switch outcome {
        case .saved:
            WidgetCenter.shared.reloadAllTimelines()
            return .result(dialog: "Commitment saved.")
        case .requiresAuthenticatedApp:
            return .result(dialog: "Open Runaway to save your commitment.")
        case .failed:
            return .result(dialog: "Runaway couldn't save that commitment. Open the app to try again.")
        }
    }
}
