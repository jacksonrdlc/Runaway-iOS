//
//  CheckInTrigger.swift
//  Runaway iOS
//
//  Created by Claude on 12/23/25.
//

import Foundation

// MARK: - Check-In Trigger

/// Trigger for periodic "How are you feeling?" prompts
final class CheckInTrigger: BaseTrigger {

    // MARK: - Properties

    private var settings: CoachSettings { CoachSettingsStore.shared.settings }

    /// Minimum elapsed time before first check-in
    private let minimumTimeBeforeFirstCheckIn: TimeInterval = 300 // 5 minutes

    /// Check-in prompts rotation
    private var promptIndex: Int = 0
    private let prompts: [String] = [
        "How are you feeling?",
        "How are the legs?",
        "Everything good?",
        "Quick check - how's it going?",
        "How's the effort level?",
        "Feeling strong?"
    ]

    // MARK: - Initialization

    init() {
        super.init(
            id: "checkIn",
            priority: .high,
            cooldown: 300 // Default 5 minutes, overridden by settings
        )
    }

    // MARK: - Dynamic Cooldown

    private var effectiveCooldown: TimeInterval {
        settings.checkInInterval
    }

    // MARK: - Trigger Implementation

    override func shouldFire(state: RunStateSnapshot, now: Date) -> Bool {
        // Check if check-ins are enabled
        guard settings.enableCheckIns else { return false }

        // Don't fire while paused
        guard !state.isPaused else { return false }

        // Wait for minimum time
        guard state.elapsedTime >= minimumTimeBeforeFirstCheckIn else {
            return false
        }

        // Check cooldown with dynamic interval
        if let lastFired = lastFired {
            guard now.timeIntervalSince(lastFired) >= effectiveCooldown else {
                return false
            }
        }

        // Smart timing: avoid interrupting high-intensity efforts
        if settings.smartCheckInTiming {
            // Don't interrupt if in high HR zone
            if let zone = state.currentZone, zone >= 4 {
                return false
            }

            // Don't interrupt if pace is significantly faster than average (likely a surge)
            if state.currentPace < state.averagePace * 0.9 {
                return false
            }
        }

        return true
    }

    override func generatePrompt(state: RunStateSnapshot) -> QueuedPrompt {
        let message = getNextPrompt()

        return QueuedPrompt(
            type: .checkIn,
            message: message,
            priority: priority,
            expectsResponse: true, // Check-ins expect voice response
            metadata: [
                "elapsedTime": state.elapsedTime,
                "distance": state.totalDistance
            ]
        )
    }

    // MARK: - Prompt Selection

    private func getNextPrompt() -> String {
        let prompt = prompts[promptIndex % prompts.count]
        promptIndex += 1
        return prompt
    }

    // MARK: - Reset

    func reset() {
        promptIndex = 0
        lastFired = nil
    }
}

// MARK: - Check-In Response Handling

extension CheckInTrigger {

    /// Possible responses to check-in prompts
    enum CheckInResponse: String, CaseIterable {
        case good = "good"
        case great = "great"
        case okay = "okay"
        case tired = "tired"
        case struggling = "struggling"
        case strong = "strong"

        /// Keywords that map to this response
        var keywords: [String] {
            switch self {
            case .good: return ["good", "fine", "alright"]
            case .great: return ["great", "amazing", "awesome", "fantastic", "excellent"]
            case .okay: return ["okay", "ok", "meh", "so-so"]
            case .tired: return ["tired", "fatigued", "exhausted"]
            case .struggling: return ["struggling", "hard", "difficult", "tough"]
            case .strong: return ["strong", "powerful", "energized"]
            }
        }

        /// Acknowledgment message for this response
        var acknowledgment: String {
            switch self {
            case .good, .okay:
                return "Got it, keep it steady."
            case .great, .strong:
                return "Awesome, you're crushing it!"
            case .tired:
                return "Noted. Listen to your body."
            case .struggling:
                return "Hang in there. Consider easing up if needed."
            }
        }
    }

    /// Parse a voice response to a check-in
    static func parseResponse(_ transcript: String) -> CheckInResponse? {
        let lowercased = transcript.lowercased()

        for response in CheckInResponse.allCases {
            for keyword in response.keywords {
                if lowercased.contains(keyword) {
                    return response
                }
            }
        }

        return nil
    }
}
