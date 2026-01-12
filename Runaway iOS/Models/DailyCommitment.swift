//
//  DailyCommitment.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 9/16/25.
//

import Foundation
import SwiftUI

// MARK: - Daily Commitment Model

struct DailyCommitment: Codable, Identifiable, Sendable {
    let id: Int?
    let athleteId: Int?  // Changed from userId to athleteId to match ERD pattern
    let commitmentDate: String // YYYY-MM-DD format
    let activityType: CommitmentActivityType
    let isFulfilled: Bool
    let fulfilledAt: String? // ISO 8601 timestamp
    let createdAt: String?
    let updatedAt: String?

    // Micro-commitment fields
    let commitmentLevel: CommitmentLevel
    let microCommitmentType: MicroCommitmentType?
    let progressionStep: Int

    enum CodingKeys: String, CodingKey {
        case id
        case athleteId = "athlete_id"
        case commitmentDate = "commitment_date"
        case activityType = "activity_type"
        case isFulfilled = "is_fulfilled"
        case fulfilledAt = "fulfilled_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case commitmentLevel = "commitment_level"
        case microCommitmentType = "micro_commitment_type"
        case progressionStep = "progression_step"
    }

    // Initializer for creating new standard commitments (backwards compatible)
    init(athleteId: Int, activityType: CommitmentActivityType, commitmentDate: Date = Date()) {
        self.id = nil
        self.athleteId = athleteId
        self.commitmentDate = DateFormatter.dateOnly.string(from: commitmentDate)
        self.activityType = activityType
        self.isFulfilled = false
        self.fulfilledAt = nil
        self.createdAt = nil
        self.updatedAt = nil
        self.commitmentLevel = .standard
        self.microCommitmentType = nil
        self.progressionStep = 0
    }

    // Initializer for creating micro-commitments
    init(athleteId: Int, microCommitmentType: MicroCommitmentType, commitmentDate: Date = Date()) {
        self.id = nil
        self.athleteId = athleteId
        self.commitmentDate = DateFormatter.dateOnly.string(from: commitmentDate)
        self.activityType = .run // Default to run for micro-commitments
        self.isFulfilled = false
        self.fulfilledAt = nil
        self.createdAt = nil
        self.updatedAt = nil
        self.commitmentLevel = .micro
        self.microCommitmentType = microCommitmentType
        self.progressionStep = 0
    }

    // Full initializer (for database responses)
    init(id: Int?, athleteId: Int?, commitmentDate: String, activityType: CommitmentActivityType,
         isFulfilled: Bool, fulfilledAt: String?, createdAt: String?, updatedAt: String?,
         commitmentLevel: CommitmentLevel = .standard, microCommitmentType: MicroCommitmentType? = nil,
         progressionStep: Int = 0) {
        self.id = id
        self.athleteId = athleteId
        self.commitmentDate = commitmentDate
        self.activityType = activityType
        self.isFulfilled = isFulfilled
        self.fulfilledAt = fulfilledAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.commitmentLevel = commitmentLevel
        self.microCommitmentType = microCommitmentType
        self.progressionStep = progressionStep
    }
}

// MARK: - Commitment Level

enum CommitmentLevel: String, Codable, CaseIterable, Sendable {
    case micro = "micro"       // Tiny: "Put on running shoes" (5-30 seconds)
    case mini = "mini"         // Small: "Walk to corner" (1-5 minutes)
    case standard = "standard" // Full commitment (existing behavior)

    var displayName: String {
        switch self {
        case .micro: return "Micro"
        case .mini: return "Mini"
        case .standard: return "Full"
        }
    }

    var description: String {
        switch self {
        case .micro: return "Start with the tiniest step"
        case .mini: return "A small but meaningful action"
        case .standard: return "Your full workout commitment"
        }
    }

    var icon: String {
        switch self {
        case .micro: return "sparkle"
        case .mini: return "flame"
        case .standard: return "flame.fill"
        }
    }

    var color: Color {
        switch self {
        case .micro: return .cyan
        case .mini: return .orange
        case .standard: return .red
        }
    }
}

// MARK: - Micro Commitment Types

enum MicroCommitmentType: String, Codable, CaseIterable, Sendable {
    case putOnShoes = "put_on_shoes"
    case stepOutside = "step_outside"
    case walkToCorner = "walk_to_corner"
    case jumpingJacks = "jumping_jacks"
    case lightStretch = "light_stretch"

    var displayName: String {
        switch self {
        case .putOnShoes: return "Put on running shoes"
        case .stepOutside: return "Step outside for 30 seconds"
        case .walkToCorner: return "Walk to the corner and back"
        case .jumpingJacks: return "Do 10 jumping jacks"
        case .lightStretch: return "Do a quick stretch"
        }
    }

    var shortName: String {
        switch self {
        case .putOnShoes: return "Shoes on"
        case .stepOutside: return "Step outside"
        case .walkToCorner: return "Quick walk"
        case .jumpingJacks: return "Jumping jacks"
        case .lightStretch: return "Stretch"
        }
    }

    var icon: String {
        switch self {
        case .putOnShoes: return "shoe.fill"
        case .stepOutside: return "door.left.hand.open"
        case .walkToCorner: return "figure.walk"
        case .jumpingJacks: return "figure.jumprope"
        case .lightStretch: return "figure.flexibility"
        }
    }

    var durationSeconds: Int {
        switch self {
        case .putOnShoes: return 30
        case .stepOutside: return 30
        case .walkToCorner: return 120
        case .jumpingJacks: return 60
        case .lightStretch: return 90
        }
    }

    var durationText: String {
        let seconds = durationSeconds
        if seconds < 60 {
            return "\(seconds) sec"
        } else {
            return "\(seconds / 60) min"
        }
    }

    var motivationalMessage: String {
        switch self {
        case .putOnShoes: return "The hardest step is putting on your shoes!"
        case .stepOutside: return "Fresh air awaits!"
        case .walkToCorner: return "A quick stroll to get moving!"
        case .jumpingJacks: return "Get your heart pumping!"
        case .lightStretch: return "Loosen up those muscles!"
        }
    }

    var completionMessage: String {
        switch self {
        case .putOnShoes: return "Shoes are on! You're ready for anything!"
        case .stepOutside: return "You made it outside! That's huge!"
        case .walkToCorner: return "Great walk! Your body thanks you!"
        case .jumpingJacks: return "Heart rate up! Feeling alive!"
        case .lightStretch: return "Feeling loose and limber!"
        }
    }

    var color: Color {
        switch self {
        case .putOnShoes: return .blue
        case .stepOutside: return .green
        case .walkToCorner: return .orange
        case .jumpingJacks: return .red
        case .lightStretch: return .purple
        }
    }

    /// Suggested progression order
    static var progressionOrder: [MicroCommitmentType] {
        [.putOnShoes, .stepOutside, .lightStretch, .jumpingJacks, .walkToCorner]
    }
}

// MARK: - Commitment Activity Types

enum CommitmentActivityType: String, CaseIterable, Codable {
    case run = "Run"
    case workout = "Weight Training"
    case walk = "Walk"
    case yoga = "Yoga"

    var displayName: String {
        return rawValue
    }

    var icon: String {
        switch self {
        case .run: return "figure.run"
        case .workout: return "dumbbell.fill"
        case .walk: return "figure.walk"
        case .yoga: return "figure.mind.and.body"
        }
    }

    var color: String {
        switch self {
        case .run: return "blue"
        case .workout: return "red"
        case .walk: return "green"
        case .yoga: return "purple"
        }
    }
}

// MARK: - Helper Extensions

extension DailyCommitment {
    var commitmentDateAsDate: Date {
        return DateFormatter.dateOnly.date(from: commitmentDate) ?? Date()
    }

    var fulfilledAtAsDate: Date? {
        guard let fulfilledAt = fulfilledAt else { return nil }
        return DateFormatter.iso8601.date(from: fulfilledAt)
    }

    var isToday: Bool {
        return Calendar.current.isDate(commitmentDateAsDate, inSameDayAs: Date())
    }

    var timeRemainingToday: TimeInterval {
        guard isToday else { return 0 }
        let endOfDay = Calendar.current.dateInterval(of: .day, for: Date())?.end ?? Date()
        return max(0, endOfDay.timeIntervalSince(Date()))
    }

    var timeRemainingText: String {
        let remaining = timeRemainingToday
        let hours = Int(remaining) / 3600
        let minutes = Int(remaining) % 3600 / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m remaining"
        } else {
            return "\(minutes)m remaining"
        }
    }

    // MARK: - Micro-Commitment Helpers

    var isMicroCommitment: Bool {
        return commitmentLevel == .micro
    }

    var isMiniCommitment: Bool {
        return commitmentLevel == .mini
    }

    var isStandardCommitment: Bool {
        return commitmentLevel == .standard
    }

    var displayTitle: String {
        if let microType = microCommitmentType {
            return microType.displayName
        }
        return activityType.displayName
    }

    var displayIcon: String {
        if let microType = microCommitmentType {
            return microType.icon
        }
        return activityType.icon
    }

    var celebrationIntensity: CelebrationIntensity {
        switch commitmentLevel {
        case .micro: return .light
        case .mini: return .medium
        case .standard: return .full
        }
    }
}

// MARK: - Celebration Intensity

enum CelebrationIntensity {
    case light   // Light haptic, small animation
    case medium  // Medium haptic, confetti
    case full    // Strong haptic, full confetti, sound
}

// MARK: - DateFormatter Extensions

extension DateFormatter {
    static let dateOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    static let iso8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter
    }()
}
