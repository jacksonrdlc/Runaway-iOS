//
//  HeartRateZone.swift
//  Runaway iOS
//
//  Created by Claude on 12/23/25.
//

import Foundation
import SwiftUI

// MARK: - Heart Rate Zone

/// Heart rate training zones based on percentage of max HR
enum HeartRateZone: Int, CaseIterable, Codable, Comparable {
    case zone1 = 1  // Recovery: 50-60% max HR
    case zone2 = 2  // Easy/Aerobic: 60-70% max HR
    case zone3 = 3  // Tempo: 70-80% max HR
    case zone4 = 4  // Threshold: 80-90% max HR
    case zone5 = 5  // VO2 Max: 90-100% max HR

    // MARK: - Comparable

    static func < (lhs: HeartRateZone, rhs: HeartRateZone) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    // MARK: - Display Properties

    var name: String {
        switch self {
        case .zone1: return "Recovery"
        case .zone2: return "Easy"
        case .zone3: return "Tempo"
        case .zone4: return "Threshold"
        case .zone5: return "VO2 Max"
        }
    }

    var shortName: String {
        "Z\(rawValue)"
    }

    var description: String {
        switch self {
        case .zone1: return "Very light effort, recovery pace"
        case .zone2: return "Comfortable, conversational pace"
        case .zone3: return "Moderate effort, getting challenging"
        case .zone4: return "Hard effort, at threshold"
        case .zone5: return "Maximum effort, unsustainable"
        }
    }

    var color: Color {
        switch self {
        case .zone1: return .blue
        case .zone2: return .green
        case .zone3: return .yellow
        case .zone4: return .orange
        case .zone5: return .red
        }
    }

    var percentageRange: ClosedRange<Double> {
        switch self {
        case .zone1: return 0.50...0.60
        case .zone2: return 0.60...0.70
        case .zone3: return 0.70...0.80
        case .zone4: return 0.80...0.90
        case .zone5: return 0.90...1.00
        }
    }

    // MARK: - Effort Level

    var isHighIntensity: Bool {
        self >= .zone4
    }

    var isRecovery: Bool {
        self <= .zone2
    }
}

// MARK: - Heart Rate Zone Calculator

struct HeartRateZoneCalculator {

    /// User's maximum heart rate
    let maxHeartRate: Int

    /// User's resting heart rate (optional, for Karvonen formula)
    let restingHeartRate: Int?

    // MARK: - Initialization

    /// Initialize with max HR (can be estimated from age: 220 - age)
    init(maxHeartRate: Int, restingHeartRate: Int? = nil) {
        self.maxHeartRate = maxHeartRate
        self.restingHeartRate = restingHeartRate
    }

    /// Initialize with age (estimates max HR as 220 - age)
    init(age: Int, restingHeartRate: Int? = nil) {
        self.maxHeartRate = 220 - age
        self.restingHeartRate = restingHeartRate
    }

    // MARK: - Zone Calculation

    /// Get the zone for a given heart rate
    func zone(for heartRate: Int) -> HeartRateZone {
        let percentage = Double(heartRate) / Double(maxHeartRate)

        for zone in HeartRateZone.allCases.reversed() {
            if percentage >= zone.percentageRange.lowerBound {
                return zone
            }
        }

        return .zone1
    }

    /// Get heart rate range for a zone
    func heartRateRange(for zone: HeartRateZone) -> ClosedRange<Int> {
        let range = zone.percentageRange
        let lower = Int(Double(maxHeartRate) * range.lowerBound)
        let upper = Int(Double(maxHeartRate) * range.upperBound)
        return lower...upper
    }

    /// Get percentage of max HR
    func percentageOfMax(heartRate: Int) -> Double {
        Double(heartRate) / Double(maxHeartRate)
    }

    // MARK: - Heart Rate Reserve (Karvonen Formula)

    /// Calculate target HR using heart rate reserve method
    /// More accurate if resting HR is known
    func targetHeartRate(intensity: Double) -> Int? {
        guard let restingHR = restingHeartRate else { return nil }

        let reserve = maxHeartRate - restingHR
        return Int(Double(reserve) * intensity + Double(restingHR))
    }
}

// MARK: - Zone Transition

struct ZoneTransition {
    let from: HeartRateZone
    let to: HeartRateZone
    let timestamp: Date

    var direction: Direction {
        if to > from {
            return .up
        } else if to < from {
            return .down
        } else {
            return .none
        }
    }

    enum Direction {
        case up
        case down
        case none
    }

    var description: String {
        switch direction {
        case .up:
            return "Entered zone \(to.rawValue) (\(to.name))"
        case .down:
            return "Dropped to zone \(to.rawValue) (\(to.name))"
        case .none:
            return "Stayed in zone \(to.rawValue)"
        }
    }
}

// MARK: - Zone Time Tracking

final class ZoneTimeTracker: ObservableObject {

    @Published private(set) var currentZone: HeartRateZone?
    @Published private(set) var timeInZones: [HeartRateZone: TimeInterval] = [:]
    @Published private(set) var transitions: [ZoneTransition] = []

    private var zoneEntryTime: Date?
    private let calculator: HeartRateZoneCalculator

    init(maxHeartRate: Int) {
        self.calculator = HeartRateZoneCalculator(maxHeartRate: maxHeartRate)

        // Initialize all zones to 0
        for zone in HeartRateZone.allCases {
            timeInZones[zone] = 0
        }
    }

    /// Update with new heart rate reading
    func update(heartRate: Int) {
        let newZone = calculator.zone(for: heartRate)
        let now = Date()

        // Update time in previous zone
        if let previousZone = currentZone, let entryTime = zoneEntryTime {
            let duration = now.timeIntervalSince(entryTime)
            timeInZones[previousZone, default: 0] += duration
        }

        // Track transition
        if let previousZone = currentZone, previousZone != newZone {
            let transition = ZoneTransition(from: previousZone, to: newZone, timestamp: now)
            transitions.append(transition)
        }

        // Update current zone
        currentZone = newZone
        zoneEntryTime = now
    }

    /// Get time in current zone
    var timeInCurrentZone: TimeInterval {
        guard let entryTime = zoneEntryTime else { return 0 }
        return Date().timeIntervalSince(entryTime)
    }

    /// Reset for new run
    func reset() {
        currentZone = nil
        zoneEntryTime = nil
        transitions.removeAll()
        for zone in HeartRateZone.allCases {
            timeInZones[zone] = 0
        }
    }

    /// Get zone distribution as percentages
    var zoneDistribution: [HeartRateZone: Double] {
        let total = timeInZones.values.reduce(0, +)
        guard total > 0 else { return [:] }

        var distribution: [HeartRateZone: Double] = [:]
        for (zone, time) in timeInZones {
            distribution[zone] = time / total
        }
        return distribution
    }
}
