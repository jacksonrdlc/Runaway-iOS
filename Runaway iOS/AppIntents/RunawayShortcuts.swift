//
//  RunawayShortcuts.swift
//  Runaway iOS
//
//  App Shortcuts for Siri / Shortcuts integration
//

import AppIntents

@available(iOS 16.0, *)
struct RunawayShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CheckTrainingPhaseIntent(),
            phrases: [
                "What's my training phase with \(.applicationName)",
                "Where am I in training with \(.applicationName)",
                "Check my training with \(.applicationName)",
                "What does \(.applicationName) say about my training"
            ],
            shortTitle: "Training Phase",
            systemImageName: "chart.bar.fill"
        )

        AppShortcut(
            intent: GetDailyBriefIntent(),
            phrases: [
                "Give me my daily brief with \(.applicationName)",
                "What's my \(.applicationName) daily brief",
                "Open my training brief with \(.applicationName)"
            ],
            shortTitle: "Daily Brief",
            systemImageName: "sun.max.fill"
        )

        AppShortcut(
            intent: CheckRaceCountdownIntent(),
            phrases: [
                "How many days until my race with \(.applicationName)",
                "Race countdown with \(.applicationName)",
                "When is my race with \(.applicationName)"
            ],
            shortTitle: "Race Countdown",
            systemImageName: "flag.checkered"
        )
    }
}
