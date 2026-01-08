//
//  MissionProvider.swift
//  Runaway iOS
//
//  Provides access to the product mission throughout the app.
//  Loads from mission.json (gitignored) with sensible defaults.
//

import Foundation

/// The sacred mission of Runaway - loaded from mission.json (not in git)
/// Usage: MissionProvider.shared.mission, MissionProvider.shared.coachContext
final class MissionProvider {

    // MARK: - Singleton

    static let shared = MissionProvider()

    // MARK: - Mission Data

    private let missionData: MissionData

    // MARK: - Public Properties

    /// The app name
    var name: String { missionData.name }

    /// The mission statement
    var mission: String { missionData.mission }

    /// The tagline
    var tagline: String { missionData.tagline }

    /// Why the name
    var nameExplanation: String { missionData.nameExplanation }

    /// Who we're for
    var audience: String { missionData.audience }

    /// What we believe
    var beliefs: String { missionData.beliefs }

    /// What we do
    var whatWeDo: String { missionData.whatWeDo }

    /// Encouragement phrases
    var encouragements: [String] { missionData.encouragements }

    /// Get a random encouragement
    var randomEncouragement: String {
        encouragements.randomElement() ?? tagline
    }

    /// Full context for the AI coach - inject this into prompts
    var coachContext: String {
        """
        You are the \(name) coach. Here is who you are and why you exist:

        THE NAME:
        \(nameExplanation)

        WHO WE'RE FOR:
        \(audience)

        WHAT WE BELIEVE:
        \(beliefs)

        WHAT WE DO:
        \(whatWeDo)

        YOUR MISSION:
        \(mission)

        Remember: You're not just optimizing training. You're a mirror that believes in them before they do. You reflect back who they're becoming, especially when they can't see it themselves.

        Every interaction should help them break through false limits and discover who they really are.
        """
    }

    // MARK: - Initialization

    private init() {
        self.missionData = MissionProvider.loadMission()
    }

    // MARK: - Private Loading

    private static func loadMission() -> MissionData {
        // Try to load from bundle
        if let url = Bundle.main.url(forResource: "mission", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let mission = try? JSONDecoder().decode(MissionData.self, from: data) {
            #if DEBUG
            print("✨ MissionProvider: Loaded sacred mission from mission.json")
            #endif
            return mission
        }

        // Fall back to defaults
        #if DEBUG
        print("⚠️ MissionProvider: Using default mission (mission.json not found)")
        #endif
        return MissionData.default
    }
}

// MARK: - Mission Data Model

private struct MissionData: Codable {
    let name: String
    let nameExplanation: String
    let audience: String
    let beliefs: String
    let whatWeDo: String
    let mission: String
    let tagline: String
    let encouragements: [String]

    static let `default` = MissionData(
        name: "Runaway",
        nameExplanation: "Run a way — a path, a method, a means to discover who you really are.",
        audience: "Runaway is for runners ready to break through their limits.",
        beliefs: "Every run is an act of self-definition.",
        whatWeDo: "Runaway is an AI-powered running coach that sees you clearly.",
        mission: "To help runners discover who they really are, one mile at a time.",
        tagline: "Runaway. Find your way.",
        encouragements: [
            "Every run is an act of self-definition.",
            "Find your way.",
            "Limits can be unlearned."
        ]
    )
}
