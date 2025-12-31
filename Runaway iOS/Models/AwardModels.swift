//
//  AwardModels.swift
//  Runaway iOS
//
//  Awards and achievements system for celebrating milestones
//

import Foundation
import SwiftUI

// MARK: - Award Definition

struct AwardDefinition: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let category: AwardCategory
    let tier: AwardTier
    let requirement: AwardRequirement

    var color: Color {
        tier.color
    }
}

// MARK: - Award Category

enum AwardCategory: String, Codable, CaseIterable {
    case distance = "distance"
    case consistency = "consistency"
    case speed = "speed"
    case milestone = "milestone"
    case special = "special"

    var displayName: String {
        switch self {
        case .distance: return "Distance"
        case .consistency: return "Consistency"
        case .speed: return "Speed"
        case .milestone: return "Milestone"
        case .special: return "Special"
        }
    }

    var icon: String {
        switch self {
        case .distance: return "road.lanes"
        case .consistency: return "calendar"
        case .speed: return "bolt.fill"
        case .milestone: return "flag.fill"
        case .special: return "star.fill"
        }
    }
}

// MARK: - Award Tier

enum AwardTier: String, Codable, CaseIterable {
    case bronze = "bronze"
    case silver = "silver"
    case gold = "gold"
    case platinum = "platinum"

    var displayName: String {
        rawValue.capitalized
    }

    var color: Color {
        switch self {
        case .bronze: return Color(red: 0.8, green: 0.5, blue: 0.2)
        case .silver: return Color(red: 0.75, green: 0.75, blue: 0.75)
        case .gold: return Color(red: 1.0, green: 0.84, blue: 0.0)
        case .platinum: return Color(red: 0.9, green: 0.9, blue: 1.0)
        }
    }
}

// MARK: - Award Requirement

struct AwardRequirement: Codable {
    let type: RequirementType
    let value: Double
    let unit: String?

    enum RequirementType: String, Codable {
        case totalDistance = "total_distance"
        case singleRunDistance = "single_run_distance"
        case totalRuns = "total_runs"
        case weeklyStreak = "weekly_streak"
        case dailyStreak = "daily_streak"
        case fastestPace = "fastest_pace"
        case totalTime = "total_time"
        case runsInWeek = "runs_in_week"
        case runsInMonth = "runs_in_month"
        case elevationGain = "elevation_gain"
    }
}

// MARK: - Earned Award

struct EarnedAward: Identifiable, Codable {
    let id: UUID
    let awardId: String
    let athleteId: Int
    let earnedAt: Date
    let activityId: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case awardId = "award_id"
        case athleteId = "athlete_id"
        case earnedAt = "earned_at"
        case activityId = "activity_id"
    }
}

// MARK: - All Available Awards

struct AwardsLibrary {
    static let allAwards: [AwardDefinition] = [
        // Distance Awards
        AwardDefinition(
            id: "first_mile",
            name: "First Mile",
            description: "Complete your first mile",
            icon: "figure.run",
            category: .milestone,
            tier: .bronze,
            requirement: AwardRequirement(type: .totalDistance, value: 1, unit: "miles")
        ),
        AwardDefinition(
            id: "marathon_total",
            name: "Marathon Distance",
            description: "Run 26.2 miles total",
            icon: "flag.checkered",
            category: .distance,
            tier: .bronze,
            requirement: AwardRequirement(type: .totalDistance, value: 26.2, unit: "miles")
        ),
        AwardDefinition(
            id: "century_club",
            name: "Century Club",
            description: "Run 100 miles total",
            icon: "100.circle.fill",
            category: .distance,
            tier: .silver,
            requirement: AwardRequirement(type: .totalDistance, value: 100, unit: "miles")
        ),
        AwardDefinition(
            id: "500_miles",
            name: "500 Mile Club",
            description: "Run 500 miles total",
            icon: "star.circle.fill",
            category: .distance,
            tier: .gold,
            requirement: AwardRequirement(type: .totalDistance, value: 500, unit: "miles")
        ),
        AwardDefinition(
            id: "1000_miles",
            name: "Thousand Miler",
            description: "Run 1,000 miles total",
            icon: "crown.fill",
            category: .distance,
            tier: .platinum,
            requirement: AwardRequirement(type: .totalDistance, value: 1000, unit: "miles")
        ),

        // Single Run Awards
        AwardDefinition(
            id: "5k_run",
            name: "5K Finisher",
            description: "Complete a 5K run (3.1 miles)",
            icon: "5.circle.fill",
            category: .milestone,
            tier: .bronze,
            requirement: AwardRequirement(type: .singleRunDistance, value: 3.1, unit: "miles")
        ),
        AwardDefinition(
            id: "10k_run",
            name: "10K Finisher",
            description: "Complete a 10K run (6.2 miles)",
            icon: "10.circle.fill",
            category: .milestone,
            tier: .silver,
            requirement: AwardRequirement(type: .singleRunDistance, value: 6.2, unit: "miles")
        ),
        AwardDefinition(
            id: "half_marathon",
            name: "Half Marathon",
            description: "Complete a half marathon (13.1 miles)",
            icon: "medal.fill",
            category: .milestone,
            tier: .gold,
            requirement: AwardRequirement(type: .singleRunDistance, value: 13.1, unit: "miles")
        ),
        AwardDefinition(
            id: "full_marathon",
            name: "Marathoner",
            description: "Complete a full marathon (26.2 miles)",
            icon: "trophy.fill",
            category: .milestone,
            tier: .platinum,
            requirement: AwardRequirement(type: .singleRunDistance, value: 26.2, unit: "miles")
        ),

        // Consistency Awards
        AwardDefinition(
            id: "first_run",
            name: "First Steps",
            description: "Complete your first run",
            icon: "shoe.fill",
            category: .milestone,
            tier: .bronze,
            requirement: AwardRequirement(type: .totalRuns, value: 1, unit: nil)
        ),
        AwardDefinition(
            id: "10_runs",
            name: "Getting Started",
            description: "Complete 10 runs",
            icon: "flame.fill",
            category: .consistency,
            tier: .bronze,
            requirement: AwardRequirement(type: .totalRuns, value: 10, unit: nil)
        ),
        AwardDefinition(
            id: "50_runs",
            name: "Dedicated Runner",
            description: "Complete 50 runs",
            icon: "heart.fill",
            category: .consistency,
            tier: .silver,
            requirement: AwardRequirement(type: .totalRuns, value: 50, unit: nil)
        ),
        AwardDefinition(
            id: "100_runs",
            name: "Century Runner",
            description: "Complete 100 runs",
            icon: "star.fill",
            category: .consistency,
            tier: .gold,
            requirement: AwardRequirement(type: .totalRuns, value: 100, unit: nil)
        ),
        AwardDefinition(
            id: "365_runs",
            name: "Year of Running",
            description: "Complete 365 runs",
            icon: "calendar.badge.checkmark",
            category: .consistency,
            tier: .platinum,
            requirement: AwardRequirement(type: .totalRuns, value: 365, unit: nil)
        ),

        // Weekly Streak Awards
        AwardDefinition(
            id: "week_streak_4",
            name: "Month Strong",
            description: "Run every week for 4 weeks",
            icon: "calendar",
            category: .consistency,
            tier: .bronze,
            requirement: AwardRequirement(type: .weeklyStreak, value: 4, unit: "weeks")
        ),
        AwardDefinition(
            id: "week_streak_12",
            name: "Quarter Champion",
            description: "Run every week for 12 weeks",
            icon: "calendar.badge.plus",
            category: .consistency,
            tier: .silver,
            requirement: AwardRequirement(type: .weeklyStreak, value: 12, unit: "weeks")
        ),
        AwardDefinition(
            id: "week_streak_52",
            name: "Year-Round Runner",
            description: "Run every week for a full year",
            icon: "sparkles",
            category: .consistency,
            tier: .platinum,
            requirement: AwardRequirement(type: .weeklyStreak, value: 52, unit: "weeks")
        ),

        // Speed Awards
        AwardDefinition(
            id: "sub_10_pace",
            name: "Sub-10 Pace",
            description: "Run a mile under 10 minutes",
            icon: "hare.fill",
            category: .speed,
            tier: .bronze,
            requirement: AwardRequirement(type: .fastestPace, value: 10, unit: "min/mile")
        ),
        AwardDefinition(
            id: "sub_8_pace",
            name: "Speed Demon",
            description: "Run a mile under 8 minutes",
            icon: "bolt.fill",
            category: .speed,
            tier: .silver,
            requirement: AwardRequirement(type: .fastestPace, value: 8, unit: "min/mile")
        ),
        AwardDefinition(
            id: "sub_7_pace",
            name: "Lightning Fast",
            description: "Run a mile under 7 minutes",
            icon: "bolt.horizontal.fill",
            category: .speed,
            tier: .gold,
            requirement: AwardRequirement(type: .fastestPace, value: 7, unit: "min/mile")
        ),

        // Elevation Awards
        AwardDefinition(
            id: "climber_1000",
            name: "Hill Climber",
            description: "Gain 1,000 feet of elevation total",
            icon: "mountain.2.fill",
            category: .special,
            tier: .bronze,
            requirement: AwardRequirement(type: .elevationGain, value: 1000, unit: "feet")
        ),
        AwardDefinition(
            id: "climber_10000",
            name: "Mountain Goat",
            description: "Gain 10,000 feet of elevation total",
            icon: "mountain.2.fill",
            category: .special,
            tier: .silver,
            requirement: AwardRequirement(type: .elevationGain, value: 10000, unit: "feet")
        ),
        AwardDefinition(
            id: "climber_everest",
            name: "Everest Equivalent",
            description: "Gain 29,032 feet (height of Everest)",
            icon: "crown.fill",
            category: .special,
            tier: .platinum,
            requirement: AwardRequirement(type: .elevationGain, value: 29032, unit: "feet")
        ),

        // Time Awards
        AwardDefinition(
            id: "time_10_hours",
            name: "10 Hour Runner",
            description: "Spend 10 hours running total",
            icon: "clock.fill",
            category: .milestone,
            tier: .bronze,
            requirement: AwardRequirement(type: .totalTime, value: 10, unit: "hours")
        ),
        AwardDefinition(
            id: "time_100_hours",
            name: "Century Hours",
            description: "Spend 100 hours running total",
            icon: "clock.badge.checkmark.fill",
            category: .milestone,
            tier: .gold,
            requirement: AwardRequirement(type: .totalTime, value: 100, unit: "hours")
        ),
    ]

    static func getAward(byId id: String) -> AwardDefinition? {
        allAwards.first { $0.id == id }
    }

    static func getAwards(for category: AwardCategory) -> [AwardDefinition] {
        allAwards.filter { $0.category == category }
    }
}
