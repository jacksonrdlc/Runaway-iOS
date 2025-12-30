//
//  Split.swift
//  Runaway iOS
//
//  Created by Claude on 12/23/25.
//

import Foundation

// MARK: - Split Model

/// Represents a completed distance split (mile or kilometer)
struct Split: Identifiable, Codable {

    let id: UUID
    let splitNumber: Int
    let distance: Double // meters
    let duration: TimeInterval // seconds
    let pace: TimeInterval // seconds per unit (mile or km)
    let timestamp: Date

    // Optional metrics (if available)
    let averageHeartRate: Int?
    let elevationGain: Double?
    let elevationLoss: Double?
    let averageCadence: Int?

    // Comparison with previous split
    var paceChangeFromPrevious: TimeInterval?

    init(
        splitNumber: Int,
        distance: Double,
        duration: TimeInterval,
        pace: TimeInterval,
        timestamp: Date = Date(),
        averageHeartRate: Int? = nil,
        elevationGain: Double? = nil,
        elevationLoss: Double? = nil,
        averageCadence: Int? = nil,
        paceChangeFromPrevious: TimeInterval? = nil
    ) {
        self.id = UUID()
        self.splitNumber = splitNumber
        self.distance = distance
        self.duration = duration
        self.pace = pace
        self.timestamp = timestamp
        self.averageHeartRate = averageHeartRate
        self.elevationGain = elevationGain
        self.elevationLoss = elevationLoss
        self.averageCadence = averageCadence
        self.paceChangeFromPrevious = paceChangeFromPrevious
    }
}

// MARK: - Split Formatting

extension Split {

    /// Format pace as MM:SS
    var formattedPace: String {
        let minutes = Int(pace) / 60
        let seconds = Int(pace) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Format duration as MM:SS or HH:MM:SS
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    /// Pace change description (e.g., "10 seconds faster")
    var paceChangeDescription: String? {
        guard let change = paceChangeFromPrevious else { return nil }

        let absChange = abs(Int(change))
        if absChange < 3 {
            return nil // Ignore changes less than 3 seconds
        }

        if change < 0 {
            return "\(absChange) seconds faster"
        } else {
            return "\(absChange) seconds slower"
        }
    }
}

// MARK: - Split Tracker

/// Tracks splits during an active run
@MainActor
final class SplitTracker: ObservableObject {

    @Published private(set) var splits: [Split] = []
    @Published private(set) var currentSplitDistance: Double = 0 // meters into current split
    @Published private(set) var currentSplitStartTime: Date?

    private let unitDistance: Double // meters per split (mile or km)
    private var lastTotalDistance: Double = 0
    private var splitStartDistance: Double = 0

    // Callbacks
    var onSplitCompleted: ((Split) -> Void)?

    init(unit: DistanceUnit = .miles) {
        self.unitDistance = unit.metersPerUnit
    }

    /// Update with new total distance
    func update(totalDistance: Double, currentPace: TimeInterval) {
        // Initialize on first update
        if currentSplitStartTime == nil {
            currentSplitStartTime = Date()
            splitStartDistance = totalDistance
            print("SplitTracker: Initialized with distance \(totalDistance)m")
        }

        lastTotalDistance = totalDistance
        currentSplitDistance = totalDistance - splitStartDistance

        // Check if we've completed a split
        let expectedSplitNumber = splits.count + 1
        let completedSplits = Int(totalDistance / unitDistance)

        // Log progress every ~100m
        let distanceMiles = totalDistance / 1609.34
        if Int(totalDistance) % 100 == 0 && totalDistance > 0 {
            print("SplitTracker: \(String(format: "%.2f", distanceMiles)) miles, split progress: \(Int(currentSplitDistance))m / \(Int(unitDistance))m")
        }

        if completedSplits >= expectedSplitNumber {
            print("SplitTracker: Split \(expectedSplitNumber) completed!")
            completeSplit(at: totalDistance, pace: currentPace)
        }
    }

    /// Complete the current split
    private func completeSplit(at totalDistance: Double, pace: TimeInterval) {
        guard let startTime = currentSplitStartTime else { return }

        let splitNumber = splits.count + 1
        let duration = Date().timeIntervalSince(startTime)

        // Calculate pace change from previous
        var paceChange: TimeInterval? = nil
        if let previousSplit = splits.last {
            paceChange = pace - previousSplit.pace
        }

        let split = Split(
            splitNumber: splitNumber,
            distance: unitDistance,
            duration: duration,
            pace: pace,
            paceChangeFromPrevious: paceChange
        )

        splits.append(split)

        // Reset for next split
        currentSplitStartTime = Date()
        splitStartDistance = totalDistance
        currentSplitDistance = 0

        // Notify
        onSplitCompleted?(split)
    }

    /// Reset tracker for new run
    func reset() {
        splits.removeAll()
        currentSplitDistance = 0
        currentSplitStartTime = nil
        lastTotalDistance = 0
        splitStartDistance = 0
    }

    /// Get the last completed split
    var lastSplit: Split? {
        splits.last
    }

    /// Average pace across all splits
    var averageSplitPace: TimeInterval? {
        guard !splits.isEmpty else { return nil }
        let totalPace = splits.reduce(0) { $0 + $1.pace }
        return totalPace / Double(splits.count)
    }
}
