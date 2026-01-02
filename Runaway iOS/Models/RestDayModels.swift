//
//  RestDayModels.swift
//  Runaway iOS
//
//  Models for rest day tracking and recovery calculation
//

import Foundation

// MARK: - Rest Day Reason

/// Reason for taking a rest day
enum RestDayReason: String, CaseIterable, Codable {
    case detected = "detected"       // Auto-detected (no activity logged)
    case scheduled = "scheduled"     // Planned rest day in training plan
    case recovery = "recovery"       // Active recovery choice
    case injury = "injury"           // Injury prevention/recovery
    case life = "life"               // Life circumstances (travel, busy day, etc.)
    case illness = "illness"         // Sick day

    var displayName: String {
        switch self {
        case .detected: return "Rest Day"
        case .scheduled: return "Scheduled Rest"
        case .recovery: return "Recovery Day"
        case .injury: return "Injury Recovery"
        case .life: return "Life Happens"
        case .illness: return "Sick Day"
        }
    }

    var icon: String {
        switch self {
        case .detected: return "moon.zzz.fill"
        case .scheduled: return "calendar.badge.checkmark"
        case .recovery: return "heart.fill"
        case .injury: return "bandage.fill"
        case .life: return "figure.walk"
        case .illness: return "cross.case.fill"
        }
    }

    /// Default recovery benefit score (0-100)
    var defaultRecoveryBenefit: Int {
        switch self {
        case .detected: return 75
        case .scheduled: return 85
        case .recovery: return 90
        case .injury: return 60
        case .life: return 70
        case .illness: return 50
        }
    }
}

// MARK: - Rest Day

/// A tracked rest day (day without training activity)
struct RestDay: Identifiable, Codable, Equatable {
    let id: UUID
    let athleteId: Int
    let date: Date
    let isPlanned: Bool
    let reason: RestDayReason
    let notes: String?
    let recoveryBenefit: Int  // 0-100, contribution to recovery
    let createdAt: Date
    let updatedAt: Date

    init(
        id: UUID = UUID(),
        athleteId: Int,
        date: Date,
        isPlanned: Bool = false,
        reason: RestDayReason = .detected,
        notes: String? = nil,
        recoveryBenefit: Int? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.athleteId = athleteId
        self.date = Calendar.current.startOfDay(for: date)
        self.isPlanned = isPlanned
        self.reason = reason
        self.notes = notes
        self.recoveryBenefit = recoveryBenefit ?? reason.defaultRecoveryBenefit
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Check if this rest day is today
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    /// Check if this rest day is yesterday
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(date)
    }

    /// Formatted date string
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    /// Short formatted date (e.g., "Mon, Jan 6")
    var shortFormattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Rest Day Database Response

/// Response structure from Supabase rest_days table
struct RestDayResponse: Codable {
    let id: String
    let athlete_id: Int
    let date: String
    let is_planned: Bool?
    let reason: String?
    let notes: String?
    let recovery_benefit: Int?
    let created_at: String
    let updated_at: String?

    /// Convert to RestDay model
    func toRestDay() -> RestDay? {
        guard let uuid = UUID(uuidString: id) else { return nil }

        // Parse date (format: "2025-01-06")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        guard let dateValue = dateFormatter.date(from: date) else { return nil }

        let reasonEnum = RestDayReason(rawValue: reason ?? "detected") ?? .detected

        let createdDate = ISO8601DateFormatter().date(from: created_at) ?? Date()
        let updatedDate = updated_at.flatMap { ISO8601DateFormatter().date(from: $0) } ?? createdDate

        return RestDay(
            id: uuid,
            athleteId: athlete_id,
            date: dateValue,
            isPlanned: is_planned ?? false,
            reason: reasonEnum,
            notes: notes,
            recoveryBenefit: recovery_benefit,
            createdAt: createdDate,
            updatedAt: updatedDate
        )
    }
}

// MARK: - Rest Day Summary

/// Summary of rest days over a period
struct RestDaySummary: Codable {
    let athleteId: Int
    let totalRestDays: Int
    let plannedRestDays: Int
    let unplannedRestDays: Int
    let averageRecoveryBenefit: Double
    let longestStreak: Int
    let currentStreak: Int
    let periodStart: Date
    let periodEnd: Date

    /// Percentage of days that were rest days
    var restDayPercentage: Double {
        let calendar = Calendar.current
        let totalDays = calendar.dateComponents([.day], from: periodStart, to: periodEnd).day ?? 1
        guard totalDays > 0 else { return 0 }
        return Double(totalRestDays) / Double(totalDays) * 100
    }

    /// Whether the rest day pattern is healthy (1-2 rest days per week is optimal)
    var isHealthyPattern: Bool {
        restDayPercentage >= 10 && restDayPercentage <= 30
    }
}

// MARK: - Rest Day Streak

/// Tracks consecutive rest days
struct RestDayStreak: Codable {
    let startDate: Date
    let endDate: Date
    let days: Int
    let reason: RestDayReason?

    var isActive: Bool {
        Calendar.current.isDateInToday(endDate) || Calendar.current.isDateInYesterday(endDate)
    }
}

// MARK: - Recovery Status

/// Current recovery status based on rest days and training
enum RecoveryStatus: String, CaseIterable, Codable {
    case fullyRecovered = "fully_recovered"
    case wellRested = "well_rested"
    case adequate = "adequate"
    case needsRest = "needs_rest"
    case overdue = "overdue"

    var displayName: String {
        switch self {
        case .fullyRecovered: return "Fully Recovered"
        case .wellRested: return "Well Rested"
        case .adequate: return "Adequate"
        case .needsRest: return "Needs Rest"
        case .overdue: return "Rest Overdue"
        }
    }

    var icon: String {
        switch self {
        case .fullyRecovered: return "bolt.fill"
        case .wellRested: return "checkmark.circle.fill"
        case .adequate: return "minus.circle.fill"
        case .needsRest: return "exclamationmark.triangle.fill"
        case .overdue: return "xmark.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .fullyRecovered: return "#22C55E"  // Green
        case .wellRested: return "#84CC16"      // Lime
        case .adequate: return "#EAB308"        // Yellow
        case .needsRest: return "#F97316"       // Orange
        case .overdue: return "#EF4444"         // Red
        }
    }

    var recommendation: String {
        switch self {
        case .fullyRecovered:
            return "You're well-rested and ready for hard training."
        case .wellRested:
            return "Good recovery. Proceed with your planned workout."
        case .adequate:
            return "Recovery is okay. Consider the intensity of today's workout."
        case .needsRest:
            return "Consider taking a rest day or easy recovery session."
        case .overdue:
            return "Rest day strongly recommended to prevent overtraining."
        }
    }

    /// Score contribution to readiness (0-100)
    var readinessScore: Int {
        switch self {
        case .fullyRecovered: return 100
        case .wellRested: return 85
        case .adequate: return 70
        case .needsRest: return 50
        case .overdue: return 30
        }
    }
}

// MARK: - Rest Day Recommendation

/// AI-generated rest day recommendation
struct RestDayRecommendation: Codable {
    let shouldRest: Bool
    let confidence: Double  // 0-1
    let reason: String
    let suggestedReason: RestDayReason?
    let alternativeWorkout: String?  // If not resting, what to do instead

    var formattedConfidence: String {
        String(format: "%.0f%%", confidence * 100)
    }
}
