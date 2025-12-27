//
//  SplitTrigger.swift
//  Runaway iOS
//
//  Created by Claude on 12/23/25.
//

import Foundation

// MARK: - Split Trigger

/// Trigger that fires when a mile/kilometer split is completed
final class SplitTrigger: BaseTrigger {

    // MARK: - Properties

    private var lastAnnouncedSplit: Int = 0
    private var settings: CoachSettings { CoachSettingsStore.shared.settings }

    // Track split history for pace comparison
    private var splitPaces: [TimeInterval] = []

    // MARK: - Initialization

    init() {
        super.init(
            id: "split",
            priority: .medium,
            cooldown: 60 // 60 seconds minimum between split announcements
        )
    }

    // MARK: - Trigger Implementation

    override func shouldFire(state: RunStateSnapshot, now: Date) -> Bool {
        // Check if split announcements are enabled
        guard settings.announceSplits,
              settings.splitDetail != .off else {
            return false
        }

        // Don't fire while paused
        guard !state.isPaused else { return false }

        // Check cooldown
        guard cooldownElapsed(now: now) else { return false }

        // Check if we've completed a new split
        let currentSplitNumber = state.completedSplits
        return currentSplitNumber > lastAnnouncedSplit
    }

    override func generatePrompt(state: RunStateSnapshot) -> QueuedPrompt {
        let splitNumber = state.completedSplits
        lastAnnouncedSplit = splitNumber

        // Store pace for comparison
        if let pace = state.lastSplitPace {
            splitPaces.append(pace)
        }

        let message = buildMessage(state: state, splitNumber: splitNumber)

        return QueuedPrompt(
            type: .split,
            message: message,
            priority: priority,
            metadata: [
                "splitNumber": splitNumber,
                "pace": state.lastSplitPace ?? state.averagePace
            ]
        )
    }

    // MARK: - Message Building

    private func buildMessage(state: RunStateSnapshot, splitNumber: Int) -> String {
        let unitName = state.distanceUnit == .miles ? "Mile" : "Kilometer"
        let pace = state.lastSplitPace ?? state.averagePace
        let formattedPace = formatPace(pace)

        switch settings.splitDetail {
        case .off:
            return ""

        case .basic:
            // "Mile 3. 8:42"
            return "\(unitName) \(splitNumber). \(formattedPace)."

        case .detailed:
            // "Mile 3 complete. 8:42 pace, 10 seconds faster. Heart rate 156, zone 3."
            var message = "\(unitName) \(splitNumber) complete. \(formattedPace) pace."

            // Add pace comparison
            if let comparison = paceComparison(currentPace: pace) {
                message += " \(comparison)."
            }

            // Add heart rate if available
            if let hr = state.currentHeartRate {
                message += " Heart rate \(hr)"
                if let zone = state.currentZone {
                    message += ", zone \(zone)"
                }
                message += "."
            }

            return message
        }
    }

    // MARK: - Helpers

    private func formatPace(_ pace: TimeInterval) -> String {
        let minutes = Int(pace) / 60
        let seconds = Int(pace) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }

    private func paceComparison(currentPace: TimeInterval) -> String? {
        // Compare to previous split
        guard splitPaces.count >= 2 else { return nil }

        let previousPace = splitPaces[splitPaces.count - 2]
        let diff = currentPace - previousPace

        // Ignore small differences
        guard abs(diff) >= 3 else { return nil }

        let absDiff = Int(abs(diff))
        if diff < 0 {
            return "\(absDiff) seconds faster than last \(settings.distanceUnit == .miles ? "mile" : "kilometer")"
        } else {
            return "\(absDiff) seconds slower"
        }
    }

    // MARK: - Reset

    func reset() {
        lastAnnouncedSplit = 0
        splitPaces.removeAll()
        lastFired = nil
    }
}

// MARK: - Split Announcement Variations

extension SplitTrigger {

    /// Get a varied opening phrase for the split announcement
    private func splitOpening(for splitNumber: Int) -> String {
        let variations = [
            "Mile \(splitNumber) complete.",
            "That's mile \(splitNumber).",
            "Mile \(splitNumber) done.",
            "\(splitNumber) down."
        ]
        return variations.randomElement() ?? "Mile \(splitNumber)."
    }

    /// Get encouragement based on pace trend
    private func encouragement(faster: Bool) -> String? {
        if faster {
            let phrases = [
                "Nice negative split!",
                "Picking up the pace!",
                "Getting faster!"
            ]
            return phrases.randomElement()
        }
        return nil
    }
}
