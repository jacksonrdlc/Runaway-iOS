//
//  ZoneDurationTrigger.swift
//  Runaway iOS
//
//  Created by Claude on 12/23/25.
//

import Foundation

// MARK: - Zone Duration Trigger

/// Trigger that fires when user has been in a concerning zone for too long
/// - Zone 5 for too long: risk of overexertion
/// - Zone 1 for too long during active run: might need motivation
final class ZoneDurationTrigger: BaseTrigger {

    // MARK: - Properties

    private var settings: CoachSettings { CoachSettingsStore.shared.settings }

    /// Thresholds for zone duration warnings
    private let zone5WarningThreshold: TimeInterval = 180 // 3 minutes
    private let zone1WarningThreshold: TimeInterval = 600 // 10 minutes (only if running, not warmup)

    /// Track which warnings have been issued to avoid repeats
    private var zone5WarningIssued: Bool = false
    private var zone1WarningIssued: Bool = false

    /// Minimum distance before zone 1 warnings (allow for warmup)
    private let minimumDistanceForZone1Warning: Double = 1609.34 // 1 mile

    // MARK: - Initialization

    init() {
        super.init(
            id: "zoneDuration",
            priority: .critical, // Duration warnings are important
            cooldown: 300 // 5 minutes between same type of warning
        )
    }

    // MARK: - Trigger Implementation

    override func shouldFire(state: RunStateSnapshot, now: Date) -> Bool {
        // Check if zone alerts are enabled
        guard settings.zoneAlerts else { return false }

        // Don't fire while paused
        guard !state.isPaused else { return false }

        // Need zone and time data
        guard let currentZone = state.currentZone,
              let timeInZone = state.timeInCurrentZone else {
            return false
        }

        // Check cooldown
        guard cooldownElapsed(now: now) else { return false }

        // Check Zone 5 duration
        if currentZone == 5 && timeInZone >= zone5WarningThreshold && !zone5WarningIssued {
            return true
        }

        // Check Zone 1 duration (only after warmup distance)
        if currentZone == 1 &&
           timeInZone >= zone1WarningThreshold &&
           state.totalDistance >= minimumDistanceForZone1Warning &&
           !zone1WarningIssued {
            return true
        }

        return false
    }

    override func generatePrompt(state: RunStateSnapshot) -> QueuedPrompt {
        guard let currentZone = state.currentZone,
              let timeInZone = state.timeInCurrentZone else {
            return QueuedPrompt(
                type: .zoneDuration,
                message: "Check your heart rate zone.",
                priority: priority
            )
        }

        let message: String
        let promptType: PromptType = .zoneDuration

        if currentZone == 5 && timeInZone >= zone5WarningThreshold {
            zone5WarningIssued = true
            let minutes = Int(timeInZone / 60)
            message = buildZone5WarningMessage(timeInZone: minutes, heartRate: state.currentHeartRate)
        } else if currentZone == 1 && timeInZone >= zone1WarningThreshold {
            zone1WarningIssued = true
            let minutes = Int(timeInZone / 60)
            message = buildZone1WarningMessage(timeInZone: minutes)
        } else {
            message = "Heart rate zone alert."
        }

        return QueuedPrompt(
            type: promptType,
            message: message,
            priority: priority,
            metadata: [
                "zone": currentZone,
                "timeInZone": timeInZone,
                "warningType": currentZone == 5 ? "high" : "low"
            ]
        )
    }

    // MARK: - Message Building

    private func buildZone5WarningMessage(timeInZone: Int, heartRate: Int?) -> String {
        let hrInfo = heartRate.map { " Heart rate at \($0)." } ?? ""
        return "You've been in zone 5 for \(timeInZone) minutes.\(hrInfo) Consider easing up to avoid overexertion."
    }

    private func buildZone1WarningMessage(timeInZone: Int) -> String {
        return "You've been in zone 1 for \(timeInZone) minutes. If this is intentional recovery, great. Otherwise, consider picking up the pace."
    }

    // MARK: - Reset

    func reset() {
        zone5WarningIssued = false
        zone1WarningIssued = false
        lastFired = nil
    }

    // MARK: - Zone Change Handler

    /// Call when zone changes to reset warning flags
    func handleZoneChange(from oldZone: Int?, to newZone: Int) {
        // Reset Zone 5 warning if we left Zone 5
        if oldZone == 5 && newZone != 5 {
            zone5WarningIssued = false
        }

        // Reset Zone 1 warning if we left Zone 1
        if oldZone == 1 && newZone != 1 {
            zone1WarningIssued = false
        }
    }
}
