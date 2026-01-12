//
//  TrainingPhaseModels.swift
//  Runaway iOS
//
//  Models for adaptive training phase detection
//

import Foundation
import SwiftUI

// MARK: - Training Phase

/// Detected training phase based on activity patterns and load analysis
enum TrainingPhase: String, CaseIterable, Codable {
    case newUser = "new_user"           // < 5 activities
    case rampingUp = "ramping_up"       // Building volume
    case tapering = "tapering"          // Reducing volume before race
    case detraining = "detraining"      // Extended break, losing fitness
    case steady = "steady"              // Consistent training
    case recovery = "recovery"          // Fatigued, needs rest

    var displayName: String {
        switch self {
        case .newUser: return "Getting Started"
        case .rampingUp: return "Building Up"
        case .tapering: return "Race Ready"
        case .detraining: return "Returning"
        case .steady: return "Consistent"
        case .recovery: return "Recovery"
        }
    }

    var icon: String {
        switch self {
        case .newUser: return "figure.run.circle"
        case .rampingUp: return "arrow.up.right.circle.fill"
        case .tapering: return "flag.checkered.circle.fill"
        case .detraining: return "arrow.counterclockwise.circle"
        case .steady: return "equal.circle.fill"
        case .recovery: return "bed.double.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .newUser: return .blue
        case .rampingUp: return .green
        case .tapering: return .purple
        case .detraining: return .orange
        case .steady: return .cyan
        case .recovery: return .pink
        }
    }

    var description: String {
        switch self {
        case .newUser:
            return "You're just getting started! Focus on building consistency."
        case .rampingUp:
            return "Your training volume is increasing. Great progress!"
        case .tapering:
            return "You're tapering. Trust your training and prepare to race."
        case .detraining:
            return "Time to rebuild. Start easy and gradually increase."
        case .steady:
            return "You're maintaining consistent training. Keep it up!"
        case .recovery:
            return "Your body needs rest. Take it easy for best results."
        }
    }
}

// MARK: - Training Phase Context

/// Additional context for the detected training phase
struct TrainingPhaseContext {
    let phase: TrainingPhase
    let confidence: Double // 0.0 - 1.0
    let activityCount: Int
    let weeklyVolumeKm: Double
    let volumeChange: Double // Percentage change vs previous period
    let streakDays: Int
    let daysUntilRace: Int? // If goal race is set
    let recoveryStatus: String?
    let recommendations: [String]

    var weeklyVolumeMiles: Double {
        weeklyVolumeKm * 0.621371
    }

    var volumeChangeFormatted: String {
        let sign = volumeChange >= 0 ? "+" : ""
        return "\(sign)\(Int(volumeChange))%"
    }

    var confidenceLevel: String {
        if confidence >= 0.8 {
            return "High"
        } else if confidence >= 0.5 {
            return "Medium"
        } else {
            return "Low"
        }
    }
}

// MARK: - Insight Card Type

/// Types of insight cards that can be shown based on training phase
enum InsightCardType: String, CaseIterable {
    case progressionBasics    // For new users
    case volumeConsistency    // For ramping up / steady
    case taperMetrics         // For tapering
    case recoveryReadiness    // For recovery / fatigued
    case returnToRunning      // For detraining

    var title: String {
        switch self {
        case .progressionBasics: return "Your Progress"
        case .volumeConsistency: return "Volume Consistency"
        case .taperMetrics: return "Race Readiness"
        case .recoveryReadiness: return "Recovery Status"
        case .returnToRunning: return "Return Plan"
        }
    }

    var icon: String {
        switch self {
        case .progressionBasics: return "chart.line.uptrend.xyaxis"
        case .volumeConsistency: return "calendar.badge.checkmark"
        case .taperMetrics: return "flag.checkered"
        case .recoveryReadiness: return "heart.fill"
        case .returnToRunning: return "arrow.uturn.up.circle"
        }
    }

    static func forPhase(_ phase: TrainingPhase) -> InsightCardType {
        switch phase {
        case .newUser: return .progressionBasics
        case .rampingUp: return .volumeConsistency
        case .tapering: return .taperMetrics
        case .detraining: return .returnToRunning
        case .steady: return .volumeConsistency
        case .recovery: return .recoveryReadiness
        }
    }
}

// MARK: - Taper Metrics

/// Metrics specific to tapering phase
struct TaperMetrics {
    let daysUntilRace: Int
    let currentVolumePercent: Double // % of peak volume
    let targetVolumePercent: Double // Recommended % at this point
    let peakVolumeKm: Double
    let currentVolumeKm: Double
    let raceGoal: String?
    let predictedRaceTime: String?
    let confidenceLevel: String

    var peakVolumeMiles: Double {
        peakVolumeKm * 0.621371
    }

    var currentVolumeMiles: Double {
        currentVolumeKm * 0.621371
    }

    var taperStatus: String {
        let diff = currentVolumePercent - targetVolumePercent
        if abs(diff) < 5 {
            return "On Track"
        } else if diff > 0 {
            return "Taper More"
        } else {
            return "Volume Low"
        }
    }

    var taperStatusColor: Color {
        let diff = currentVolumePercent - targetVolumePercent
        if abs(diff) < 5 {
            return .green
        } else if diff > 0 {
            return .orange
        } else {
            return .yellow
        }
    }
}

// MARK: - Volume Consistency Metrics

/// Metrics for volume consistency tracking
struct VolumeConsistencyMetrics {
    let currentWeekKm: Double
    let previousWeekKm: Double
    let fourWeekAverageKm: Double
    let weekOverWeekChange: Double
    let consistencyScore: Double // 0-100
    let streakWeeks: Int
    let targetWeeklyKm: Double?

    var currentWeekMiles: Double {
        currentWeekKm * 0.621371
    }

    var previousWeekMiles: Double {
        previousWeekKm * 0.621371
    }

    var fourWeekAverageMiles: Double {
        fourWeekAverageKm * 0.621371
    }

    var targetWeeklyMiles: Double? {
        targetWeeklyKm.map { $0 * 0.621371 }
    }

    var consistencyLevel: String {
        if consistencyScore >= 80 {
            return "Excellent"
        } else if consistencyScore >= 60 {
            return "Good"
        } else if consistencyScore >= 40 {
            return "Moderate"
        } else {
            return "Building"
        }
    }

    var consistencyColor: Color {
        if consistencyScore >= 80 {
            return .green
        } else if consistencyScore >= 60 {
            return .blue
        } else if consistencyScore >= 40 {
            return .orange
        } else {
            return .gray
        }
    }
}

// MARK: - Recovery Metrics

/// Metrics for recovery status
struct RecoveryMetrics {
    let recoveryScore: Double // 0-100
    let status: String // well_recovered, adequate, fatigued, etc.
    let acwr: Double
    let restDaysLast7: Int
    let qualityRunsLast7: Int
    let suggestedRestDays: Int
    let recommendations: [String]

    var statusDisplay: String {
        status.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var statusColor: Color {
        switch status {
        case "well_recovered": return .green
        case "adequate": return .blue
        case "fatigued": return .orange
        case "overreaching": return .red
        case "overtrained": return .purple
        default: return .gray
        }
    }

    var recoveryLevel: String {
        if recoveryScore >= 80 {
            return "Ready"
        } else if recoveryScore >= 60 {
            return "Adequate"
        } else if recoveryScore >= 40 {
            return "Fatigued"
        } else {
            return "Exhausted"
        }
    }
}

// MARK: - Progression Metrics (New User)

/// Metrics for new users
struct ProgressionMetrics {
    let totalActivities: Int
    let totalDistanceKm: Double
    let averagePaceMinPerKm: Double
    let longestRunKm: Double
    let firstActivityDate: Date?
    let milestones: [ProgressionMilestone]

    var totalDistanceMiles: Double {
        totalDistanceKm * 0.621371
    }

    var longestRunMiles: Double {
        longestRunKm * 0.621371
    }

    var daysSinceStart: Int {
        guard let start = firstActivityDate else { return 0 }
        return Calendar.current.dateComponents([.day], from: start, to: Date()).day ?? 0
    }
}

struct ProgressionMilestone: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let isAchieved: Bool
    let icon: String

    static let defaultMilestones: [ProgressionMilestone] = [
        ProgressionMilestone(title: "First Run", description: "Complete your first activity", isAchieved: false, icon: "1.circle.fill"),
        ProgressionMilestone(title: "5 Runs", description: "Complete 5 activities", isAchieved: false, icon: "5.circle.fill"),
        ProgressionMilestone(title: "First 5K", description: "Run 5 kilometers", isAchieved: false, icon: "flag.fill"),
        ProgressionMilestone(title: "10 Runs", description: "Complete 10 activities", isAchieved: false, icon: "10.circle.fill"),
        ProgressionMilestone(title: "First 10K", description: "Run 10 kilometers", isAchieved: false, icon: "star.fill")
    ]
}
