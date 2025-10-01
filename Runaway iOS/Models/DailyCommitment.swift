//
//  DailyCommitment.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 9/16/25.
//

import Foundation

// MARK: - Daily Commitment Model

struct DailyCommitment: Codable, Identifiable {
    let id: Int?
    let athleteId: Int?  // Changed from userId to athleteId to match ERD pattern
    let commitmentDate: String // YYYY-MM-DD format
    let activityType: CommitmentActivityType
    let isFulfilled: Bool
    let fulfilledAt: String? // ISO 8601 timestamp
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case athleteId = "athlete_id"  // Changed to match ERD pattern
        case commitmentDate = "commitment_date"
        case activityType = "activity_type"
        case isFulfilled = "is_fulfilled"
        case fulfilledAt = "fulfilled_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // Initializer for creating new commitments
    init(athleteId: Int, activityType: CommitmentActivityType, commitmentDate: Date = Date()) {
        self.id = nil
        self.athleteId = athleteId
        self.commitmentDate = DateFormatter.dateOnly.string(from: commitmentDate)
        self.activityType = activityType
        self.isFulfilled = false
        self.fulfilledAt = nil
        self.createdAt = nil
        self.updatedAt = nil
    }

    // Full initializer (for database responses)
    init(id: Int?, athleteId: Int?, commitmentDate: String, activityType: CommitmentActivityType,
         isFulfilled: Bool, fulfilledAt: String?, createdAt: String?, updatedAt: String?) {
        self.id = id
        self.athleteId = athleteId
        self.commitmentDate = commitmentDate
        self.activityType = activityType
        self.isFulfilled = isFulfilled
        self.fulfilledAt = fulfilledAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
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
