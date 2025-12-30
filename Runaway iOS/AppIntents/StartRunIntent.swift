//
//  StartRunIntent.swift
//  Runaway iOS
//
//  App Intent to start a run via Siri
//  "Hey Siri, start my run with Runaway"
//

import AppIntents
import SwiftUI

@available(iOS 16.0, *)
struct StartRunIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Run"
    static var description = IntentDescription("Start recording a run with Runaway")

    static var openAppWhenRun: Bool = true

    @Parameter(title: "Activity Type", default: "Run")
    var activityType: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        // Post notification to start recording
        NotificationCenter.default.post(
            name: .startRecordingFromSiri,
            object: nil,
            userInfo: ["activityType": activityType]
        )

        return .result(
            dialog: "Starting your \(activityType.lowercased())...",
            view: StartRunConfirmationView(activityType: activityType)
        )
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Start a \(\.$activityType)")
    }
}

@available(iOS 16.0, *)
struct StartRunConfirmationView: View {
    let activityType: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: activityIcon)
                .font(.system(size: 40))
                .foregroundColor(.blue)

            Text("Starting \(activityType)")
                .font(.headline)

            Text("GPS tracking enabled")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }

    private var activityIcon: String {
        switch activityType.lowercased() {
        case "run", "running":
            return "figure.run"
        case "walk", "walking":
            return "figure.walk"
        case "bike", "cycling", "ride":
            return "figure.outdoor.cycle"
        case "hike", "hiking":
            return "figure.hiking"
        default:
            return "figure.run"
        }
    }
}

// MARK: - Stop Run Intent

@available(iOS 16.0, *)
struct StopRunIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Run"
    static var description = IntentDescription("Stop the current run recording")

    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Post notification to stop recording
        NotificationCenter.default.post(
            name: .stopRecordingFromSiri,
            object: nil
        )

        return .result(dialog: "Stopping your run and saving...")
    }
}

// MARK: - Pause/Resume Intents

@available(iOS 16.0, *)
struct PauseRunIntent: AppIntent {
    static var title: LocalizedStringResource = "Pause Run"
    static var description = IntentDescription("Pause the current run recording")

    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        NotificationCenter.default.post(
            name: .pauseRecordingFromSiri,
            object: nil
        )

        return .result(dialog: "Run paused")
    }
}

@available(iOS 16.0, *)
struct ResumeRunIntent: AppIntent {
    static var title: LocalizedStringResource = "Resume Run"
    static var description = IntentDescription("Resume the paused run recording")

    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        NotificationCenter.default.post(
            name: .resumeRecordingFromSiri,
            object: nil
        )

        return .result(dialog: "Run resumed")
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let startRecordingFromSiri = Notification.Name("startRecordingFromSiri")
    static let stopRecordingFromSiri = Notification.Name("stopRecordingFromSiri")
    static let pauseRecordingFromSiri = Notification.Name("pauseRecordingFromSiri")
    static let resumeRecordingFromSiri = Notification.Name("resumeRecordingFromSiri")
    static let navigateToRecordTab = Notification.Name("navigateToRecordTab")
}
