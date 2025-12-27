//
//  ZoneTransitionTrigger.swift
//  Runaway iOS
//
//  Created by Claude on 12/23/25.
//

import Foundation

// MARK: - Zone Transition Trigger

/// Trigger that fires when heart rate zone changes
final class ZoneTransitionTrigger: BaseTrigger {

    // MARK: - Properties

    private var settings: CoachSettings { CoachSettingsStore.shared.settings }

    /// Track previous zone to detect transitions
    private var previousZone: Int?

    /// Minimum time in new zone before announcing (avoid rapid oscillations)
    private let minimumTimeInNewZone: TimeInterval = 10

    /// Track when zone was entered
    private var zoneEntryTime: Date?

    // MARK: - Initialization

    init() {
        super.init(
            id: "zoneTransition",
            priority: .high,
            cooldown: 30 // 30 seconds between zone announcements
        )
    }

    // MARK: - Trigger Implementation

    override func shouldFire(state: RunStateSnapshot, now: Date) -> Bool {
        // Check if zone alerts are enabled
        guard settings.zoneAlerts else { return false }

        // Don't fire while paused
        guard !state.isPaused else { return false }

        // Need heart rate data
        guard let currentZone = state.currentZone else { return false }

        // Check cooldown
        guard cooldownElapsed(now: now) else { return false }

        // First zone reading - initialize but don't announce
        guard let prevZone = previousZone else {
            previousZone = currentZone
            zoneEntryTime = now
            return false
        }

        // No transition
        guard currentZone != prevZone else { return false }

        // Check if we've been in new zone long enough
        if let entryTime = zoneEntryTime {
            guard now.timeIntervalSince(entryTime) >= minimumTimeInNewZone else {
                return false
            }
        }

        return true
    }

    override func generatePrompt(state: RunStateSnapshot) -> QueuedPrompt {
        guard let currentZone = state.currentZone,
              let prevZone = previousZone else {
            // Fallback - shouldn't happen
            return QueuedPrompt(
                type: .zoneTransition,
                message: "Heart rate zone update.",
                priority: priority
            )
        }

        // Update tracking
        let direction: ZoneDirection = currentZone > prevZone ? .up : .down
        previousZone = currentZone
        zoneEntryTime = Date()

        let message = buildMessage(
            fromZone: prevZone,
            toZone: currentZone,
            direction: direction,
            heartRate: state.currentHeartRate
        )

        return QueuedPrompt(
            type: .zoneTransition,
            message: message,
            priority: priority,
            metadata: [
                "fromZone": prevZone,
                "toZone": currentZone,
                "direction": direction.rawValue,
                "heartRate": state.currentHeartRate ?? 0
            ]
        )
    }

    // MARK: - Message Building

    private enum ZoneDirection: String {
        case up
        case down
    }

    private func buildMessage(
        fromZone: Int,
        toZone: Int,
        direction: ZoneDirection,
        heartRate: Int?
    ) -> String {
        let zoneName = zoneDescription(toZone)
        let hrString = heartRate.map { "Heart rate \($0)." } ?? ""

        switch direction {
        case .up:
            if toZone >= 4 {
                // Entering high intensity
                return "Entering zone \(toZone), \(zoneName). \(hrString) Monitor your effort."
            } else {
                return "Moving up to zone \(toZone), \(zoneName). \(hrString)"
            }

        case .down:
            if fromZone >= 4 && toZone <= 3 {
                // Dropping from high intensity
                return "Nice recovery. Back to zone \(toZone), \(zoneName). \(hrString)"
            } else {
                return "Easing into zone \(toZone), \(zoneName). \(hrString)"
            }
        }
    }

    private func zoneDescription(_ zone: Int) -> String {
        switch zone {
        case 1: return "recovery"
        case 2: return "easy"
        case 3: return "tempo"
        case 4: return "threshold"
        case 5: return "max effort"
        default: return "zone \(zone)"
        }
    }

    // MARK: - Reset

    func reset() {
        previousZone = nil
        zoneEntryTime = nil
        lastFired = nil
    }
}
