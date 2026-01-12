//
//  OnboardingModels.swift
//  Runaway iOS
//
//  Created by Claude on 1/12/26.
//

import Foundation
import SwiftUI

// MARK: - Onboarding State

struct OnboardingState: Codable, Sendable {
    let id: Int?
    let athleteId: Int
    var isCompleted: Bool
    var currentStep: Int
    var movementTestCadence: Double?
    var movementTestVariance: Double?
    var locationPermissionGranted: Bool
    var coachPersonality: CoachPersonality
    var experienceLevel: ExperienceLevel?
    var completedAt: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case athleteId = "athlete_id"
        case isCompleted = "is_completed"
        case currentStep = "current_step"
        case movementTestCadence = "movement_test_cadence"
        case movementTestVariance = "movement_test_variance"
        case locationPermissionGranted = "location_permission_granted"
        case coachPersonality = "coach_personality"
        case experienceLevel = "experience_level"
        case completedAt = "completed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // Create new onboarding state
    init(athleteId: Int) {
        self.id = nil
        self.athleteId = athleteId
        self.isCompleted = false
        self.currentStep = 0
        self.movementTestCadence = nil
        self.movementTestVariance = nil
        self.locationPermissionGranted = false
        self.coachPersonality = .balanced
        self.experienceLevel = nil
        self.completedAt = nil
        self.createdAt = nil
        self.updatedAt = nil
    }

    // Full initializer for database responses
    init(id: Int?, athleteId: Int, isCompleted: Bool, currentStep: Int,
         movementTestCadence: Double?, movementTestVariance: Double?,
         locationPermissionGranted: Bool, coachPersonality: CoachPersonality,
         experienceLevel: ExperienceLevel?, completedAt: String?,
         createdAt: String?, updatedAt: String?) {
        self.id = id
        self.athleteId = athleteId
        self.isCompleted = isCompleted
        self.currentStep = currentStep
        self.movementTestCadence = movementTestCadence
        self.movementTestVariance = movementTestVariance
        self.locationPermissionGranted = locationPermissionGranted
        self.coachPersonality = coachPersonality
        self.experienceLevel = experienceLevel
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Onboarding Step

enum OnboardingStep: Int, CaseIterable, Sendable {
    case welcome = 0
    case experienceAssessment = 1
    case movementTest = 2
    case locationPermission = 3
    case coachSelection = 4
    case completion = 5

    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .experienceAssessment: return "Your Experience"
        case .movementTest: return "Movement Test"
        case .locationPermission: return "Location"
        case .coachSelection: return "Your Coach"
        case .completion: return "Ready!"
        }
    }

    var subtitle: String {
        switch self {
        case .welcome: return "Let's get you set up"
        case .experienceAssessment: return "Tell us about your running"
        case .movementTest: return "Quick 30-second assessment"
        case .locationPermission: return "Track your runs"
        case .coachSelection: return "Choose your style"
        case .completion: return "You're all set"
        }
    }

    var icon: String {
        switch self {
        case .welcome: return "hand.wave.fill"
        case .experienceAssessment: return "figure.run"
        case .movementTest: return "waveform.path.ecg"
        case .locationPermission: return "location.fill"
        case .coachSelection: return "person.fill.questionmark"
        case .completion: return "checkmark.circle.fill"
        }
    }

    var isSkippable: Bool {
        switch self {
        case .welcome, .completion: return false
        case .experienceAssessment, .movementTest, .locationPermission, .coachSelection: return true
        }
    }

    static var totalSteps: Int {
        return OnboardingStep.allCases.count
    }

    var next: OnboardingStep? {
        return OnboardingStep(rawValue: rawValue + 1)
    }

    var previous: OnboardingStep? {
        return OnboardingStep(rawValue: rawValue - 1)
    }
}

// MARK: - Coach Personality

enum CoachPersonality: String, Codable, CaseIterable, Sendable {
    case motivational = "motivational"
    case analytical = "analytical"
    case balanced = "balanced"

    var displayName: String {
        switch self {
        case .motivational: return "Motivational"
        case .analytical: return "Analytical"
        case .balanced: return "Balanced"
        }
    }

    var description: String {
        switch self {
        case .motivational:
            return "Focuses on encouragement, celebrates wins, and keeps you pumped up"
        case .analytical:
            return "Data-driven insights, detailed metrics, and performance analysis"
        case .balanced:
            return "A mix of motivation and analysis tailored to the moment"
        }
    }

    var icon: String {
        switch self {
        case .motivational: return "flame.fill"
        case .analytical: return "chart.line.uptrend.xyaxis"
        case .balanced: return "scale.3d"
        }
    }

    var color: Color {
        switch self {
        case .motivational: return .orange
        case .analytical: return .blue
        case .balanced: return .purple
        }
    }

    var sampleMessage: String {
        switch self {
        case .motivational:
            return "\"You're crushing it! That pace is fire! 🔥 Keep pushing!\""
        case .analytical:
            return "\"Your pace is 8:23/mi, 12% faster than your 30-day average. Heart rate zone 3.\""
        case .balanced:
            return "\"Great pace today! You're running 12% faster than usual. Keep it up!\""
        }
    }
}

// MARK: - Experience Level

enum ExperienceLevel: String, Codable, CaseIterable, Sendable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"
    case skip = "skip"

    var displayName: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        case .skip: return "Skip"
        }
    }

    var description: String {
        switch self {
        case .beginner:
            return "New to running or getting back into it"
        case .intermediate:
            return "Run regularly, familiar with training concepts"
        case .advanced:
            return "Experienced runner, focused on performance"
        case .skip:
            return "I'll set this up later"
        }
    }

    var icon: String {
        switch self {
        case .beginner: return "leaf.fill"
        case .intermediate: return "figure.run"
        case .advanced: return "trophy.fill"
        case .skip: return "arrow.right.circle"
        }
    }

    var color: Color {
        switch self {
        case .beginner: return .green
        case .intermediate: return .blue
        case .advanced: return .orange
        case .skip: return .gray
        }
    }

    var weeklyMilesRange: String {
        switch self {
        case .beginner: return "0-10 miles/week"
        case .intermediate: return "10-30 miles/week"
        case .advanced: return "30+ miles/week"
        case .skip: return ""
        }
    }
}

// MARK: - Movement Test Result

struct MovementTestResult: Codable, Sendable {
    let averageCadence: Double  // Steps per minute
    let variance: Double        // Cadence consistency
    let testDuration: TimeInterval
    let sampleCount: Int

    var cadenceAssessment: CadenceAssessment {
        if averageCadence < 150 {
            return .low
        } else if averageCadence < 170 {
            return .moderate
        } else if averageCadence < 185 {
            return .good
        } else {
            return .excellent
        }
    }

    var consistencyAssessment: String {
        if variance < 5 {
            return "Very consistent"
        } else if variance < 10 {
            return "Consistent"
        } else if variance < 15 {
            return "Moderate variation"
        } else {
            return "Variable"
        }
    }
}

enum CadenceAssessment: String {
    case low = "Low"
    case moderate = "Moderate"
    case good = "Good"
    case excellent = "Excellent"

    var color: Color {
        switch self {
        case .low: return .orange
        case .moderate: return .yellow
        case .good: return .green
        case .excellent: return .blue
        }
    }

    var recommendation: String {
        switch self {
        case .low:
            return "Try taking quicker, shorter steps to improve efficiency"
        case .moderate:
            return "Your cadence is developing well, keep practicing"
        case .good:
            return "Great cadence! This helps reduce injury risk"
        case .excellent:
            return "Elite-level cadence! You're running efficiently"
        }
    }
}

// MARK: - Onboarding Progress

struct OnboardingProgress {
    let currentStep: OnboardingStep
    let totalSteps: Int

    var progress: Double {
        return Double(currentStep.rawValue) / Double(totalSteps - 1)
    }

    var isComplete: Bool {
        return currentStep == .completion
    }

    var stepsRemaining: Int {
        return totalSteps - currentStep.rawValue - 1
    }
}
