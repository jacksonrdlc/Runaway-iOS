//
//  RunawayShortcuts.swift
//  Runaway iOS
//
//  App Shortcuts provider for Siri integration
//  Enables phrases like "Start my run with Runaway"
//

import AppIntents

@available(iOS 16.0, *)
struct RunawayShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartRunIntent(),
            phrases: [
                "Start my run with \(.applicationName)",
                "Start a run with \(.applicationName)",
                "Start running with \(.applicationName)",
                "Begin my run with \(.applicationName)",
                "Let's run with \(.applicationName)",
                "Start \(.applicationName) run",
                "Go for a run with \(.applicationName)"
            ],
            shortTitle: "Start Run",
            systemImageName: "figure.run"
        )

        AppShortcut(
            intent: StopRunIntent(),
            phrases: [
                "Stop my run with \(.applicationName)",
                "Stop running with \(.applicationName)",
                "End my run with \(.applicationName)",
                "Finish my run with \(.applicationName)",
                "Stop \(.applicationName)"
            ],
            shortTitle: "Stop Run",
            systemImageName: "stop.fill"
        )

        AppShortcut(
            intent: PauseRunIntent(),
            phrases: [
                "Pause my run with \(.applicationName)",
                "Pause \(.applicationName)",
                "Take a break with \(.applicationName)"
            ],
            shortTitle: "Pause Run",
            systemImageName: "pause.fill"
        )

        AppShortcut(
            intent: ResumeRunIntent(),
            phrases: [
                "Resume my run with \(.applicationName)",
                "Continue my run with \(.applicationName)",
                "Resume \(.applicationName)"
            ],
            shortTitle: "Resume Run",
            systemImageName: "play.fill"
        )
    }
}

// MARK: - Activity Type Enum for Intents

@available(iOS 16.0, *)
enum RunawayActivityType: String, AppEnum {
    case run = "Run"
    case walk = "Walk"
    case bike = "Bike"
    case hike = "Hike"

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Activity Type")
    }

    static var caseDisplayRepresentations: [RunawayActivityType: DisplayRepresentation] {
        [
            .run: DisplayRepresentation(title: "Run", image: .init(systemName: "figure.run")),
            .walk: DisplayRepresentation(title: "Walk", image: .init(systemName: "figure.walk")),
            .bike: DisplayRepresentation(title: "Bike", image: .init(systemName: "figure.outdoor.cycle")),
            .hike: DisplayRepresentation(title: "Hike", image: .init(systemName: "figure.hiking"))
        ]
    }
}
