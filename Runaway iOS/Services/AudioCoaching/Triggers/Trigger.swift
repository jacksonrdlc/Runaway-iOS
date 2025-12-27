//
//  Trigger.swift
//  Runaway iOS
//
//  Created by Claude on 12/23/25.
//

import Foundation

// MARK: - Run State Snapshot

/// A snapshot of the current run state for trigger evaluation
struct RunStateSnapshot {
    // Timing
    let elapsedTime: TimeInterval
    let isPaused: Bool

    // Distance & Pace
    let totalDistance: Double // meters
    let currentPace: TimeInterval // seconds per mile
    let averagePace: TimeInterval
    let targetPace: TimeInterval?

    // Splits
    let completedSplits: Int
    let lastSplitPace: TimeInterval?

    // Speed
    let currentSpeed: Double // m/s

    // Heart Rate (optional)
    let currentHeartRate: Int?
    let currentZone: Int?
    let previousZone: Int?
    let timeInCurrentZone: TimeInterval?

    // Settings
    let distanceUnit: DistanceUnit

    // Computed
    var currentSplitNumber: Int {
        completedSplits + 1
    }

    var totalDistanceInUnits: Double {
        totalDistance / distanceUnit.metersPerUnit
    }

    init(
        elapsedTime: TimeInterval = 0,
        isPaused: Bool = false,
        totalDistance: Double = 0,
        currentPace: TimeInterval = 0,
        averagePace: TimeInterval = 0,
        targetPace: TimeInterval? = nil,
        completedSplits: Int = 0,
        lastSplitPace: TimeInterval? = nil,
        currentSpeed: Double = 0,
        currentHeartRate: Int? = nil,
        currentZone: Int? = nil,
        previousZone: Int? = nil,
        timeInCurrentZone: TimeInterval? = nil,
        distanceUnit: DistanceUnit = .miles
    ) {
        self.elapsedTime = elapsedTime
        self.isPaused = isPaused
        self.totalDistance = totalDistance
        self.currentPace = currentPace
        self.averagePace = averagePace
        self.targetPace = targetPace
        self.completedSplits = completedSplits
        self.lastSplitPace = lastSplitPace
        self.currentSpeed = currentSpeed
        self.currentHeartRate = currentHeartRate
        self.currentZone = currentZone
        self.previousZone = previousZone
        self.timeInCurrentZone = timeInCurrentZone
        self.distanceUnit = distanceUnit
    }
}

// MARK: - Trigger Protocol

/// Protocol for all coaching triggers
protocol Trigger: AnyObject {

    /// Unique identifier for this trigger type
    var id: String { get }

    /// Whether this trigger is currently enabled
    var isEnabled: Bool { get set }

    /// Priority level for prompts from this trigger
    var priority: PromptPriority { get }

    /// Minimum time between firings (seconds)
    var cooldown: TimeInterval { get }

    /// Last time this trigger fired
    var lastFired: Date? { get set }

    /// Evaluate whether this trigger should fire
    func shouldFire(state: RunStateSnapshot, now: Date) -> Bool

    /// Generate the prompt for this trigger
    func generatePrompt(state: RunStateSnapshot) -> QueuedPrompt
}

// MARK: - Trigger Base Class

/// Base class with common trigger functionality
class BaseTrigger: Trigger {

    let id: String
    var isEnabled: Bool = true
    let priority: PromptPriority
    let cooldown: TimeInterval
    var lastFired: Date?

    init(id: String, priority: PromptPriority, cooldown: TimeInterval) {
        self.id = id
        self.priority = priority
        self.cooldown = cooldown
    }

    /// Check if cooldown has elapsed since last firing
    func cooldownElapsed(now: Date) -> Bool {
        guard let lastFired = lastFired else { return true }
        return now.timeIntervalSince(lastFired) >= cooldown
    }

    /// Override in subclasses
    func shouldFire(state: RunStateSnapshot, now: Date) -> Bool {
        fatalError("Subclasses must implement shouldFire")
    }

    /// Override in subclasses
    func generatePrompt(state: RunStateSnapshot) -> QueuedPrompt {
        fatalError("Subclasses must implement generatePrompt")
    }
}

// MARK: - Trigger Registry

/// Manages all registered triggers
final class TriggerRegistry {

    private var triggers: [String: Trigger] = [:]

    /// Register a trigger
    func register(_ trigger: Trigger) {
        triggers[trigger.id] = trigger
    }

    /// Unregister a trigger
    func unregister(id: String) {
        triggers.removeValue(forKey: id)
    }

    /// Get a trigger by ID
    func get(id: String) -> Trigger? {
        triggers[id]
    }

    /// Get all enabled triggers
    var enabledTriggers: [Trigger] {
        triggers.values.filter { $0.isEnabled }
    }

    /// Get all triggers
    var allTriggers: [Trigger] {
        Array(triggers.values)
    }

    /// Enable/disable a trigger
    func setEnabled(_ enabled: Bool, for id: String) {
        triggers[id]?.isEnabled = enabled
    }

    /// Reset all trigger cooldowns
    func resetCooldowns() {
        for trigger in triggers.values {
            trigger.lastFired = nil
        }
    }
}
