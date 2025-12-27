//
//  PaceDriftTrigger.swift
//  Runaway iOS
//
//  Created by Claude on 12/23/25.
//

import Foundation

// MARK: - Pace Drift Trigger

/// Trigger that fires when pace deviates significantly from target or average
final class PaceDriftTrigger: BaseTrigger {

    // MARK: - Properties

    private var settings: CoachSettings { CoachSettingsStore.shared.settings }

    /// Minimum distance before pace drift alerts (let runner settle in)
    private let minimumDistance: Double = 800 // meters (~0.5 mile)

    /// Minimum elapsed time before alerts
    private let minimumTime: TimeInterval = 180 // 3 minutes

    /// Track consecutive drift readings to avoid false positives
    private var consecutiveDriftCount: Int = 0
    private let requiredConsecutiveReadings: Int = 3

    // MARK: - Initialization

    init() {
        super.init(
            id: "paceDrift",
            priority: .high,
            cooldown: 120 // 2 minutes between pace drift alerts
        )
    }

    // MARK: - Trigger Implementation

    override func shouldFire(state: RunStateSnapshot, now: Date) -> Bool {
        // Check if pace alerts are enabled
        guard settings.paceAlerts else { return false }

        // Don't fire while paused
        guard !state.isPaused else { return false }

        // Check cooldown
        guard cooldownElapsed(now: now) else { return false }

        // Wait for minimum distance and time
        guard state.totalDistance >= minimumDistance,
              state.elapsedTime >= minimumTime else {
            return false
        }

        // Need valid current pace
        guard state.currentPace > 0, state.currentPace < 1800 else { // < 30 min/mile
            return false
        }

        // Determine reference pace (target or average)
        let referencePace = state.targetPace ?? state.averagePace
        guard referencePace > 0 else { return false }

        // Calculate drift percentage
        let drift = (state.currentPace - referencePace) / referencePace
        let threshold = settings.paceDriftThreshold

        // Check if drift exceeds threshold
        if abs(drift) > threshold {
            consecutiveDriftCount += 1
        } else {
            consecutiveDriftCount = 0
        }

        // Require consecutive readings to avoid false positives
        return consecutiveDriftCount >= requiredConsecutiveReadings
    }

    override func generatePrompt(state: RunStateSnapshot) -> QueuedPrompt {
        // Reset counter after firing
        consecutiveDriftCount = 0

        let message = buildMessage(state: state)

        return QueuedPrompt(
            type: .paceDrift,
            message: message,
            priority: priority,
            metadata: [
                "currentPace": state.currentPace,
                "referencePace": state.targetPace ?? state.averagePace
            ]
        )
    }

    // MARK: - Message Building

    private func buildMessage(state: RunStateSnapshot) -> String {
        let currentPace = state.currentPace
        let referencePace = state.targetPace ?? state.averagePace
        let drift = currentPace - referencePace

        let currentFormatted = formatPace(currentPace)
        let referenceFormatted = formatPace(referencePace)

        let hasTarget = state.targetPace != nil
        let referenceLabel = hasTarget ? "target" : "average"

        if drift > 0 {
            // Slower than reference
            let slowerBy = Int(abs(drift))
            if slowerBy > 30 {
                return "Pace check. You've slowed to \(currentFormatted). That's \(slowerBy) seconds off your \(referenceLabel) of \(referenceFormatted)."
            } else {
                return "Pace check. Running \(currentFormatted), slightly slower than \(referenceLabel)."
            }
        } else {
            // Faster than reference
            let fasterBy = Int(abs(drift))
            if fasterBy > 30 {
                return "Pace check. You're pushing at \(currentFormatted). That's \(fasterBy) seconds faster than \(referenceLabel). Make sure this is intentional."
            } else {
                return "Pace check. Running \(currentFormatted), ahead of \(referenceLabel) pace."
            }
        }
    }

    // MARK: - Helpers

    private func formatPace(_ pace: TimeInterval) -> String {
        let minutes = Int(pace) / 60
        let seconds = Int(pace) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }

    // MARK: - Reset

    func reset() {
        consecutiveDriftCount = 0
        lastFired = nil
    }
}
