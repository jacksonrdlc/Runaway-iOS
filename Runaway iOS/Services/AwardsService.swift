//
//  AwardsService.swift
//  Runaway iOS
//
//  Service to calculate and manage athlete awards
//

import Foundation
import Supabase

class AwardsService: ObservableObject {
    static let shared = AwardsService()

    @Published var earnedAwards: [EarnedAward] = []
    @Published var isLoading = false

    private init() {}

    // MARK: - Public Methods

    /// Calculate all earned awards based on activities
    func calculateEarnedAwards(activities: [Activity], athleteId: Int) -> [String] {
        var earnedIds: [String] = []

        // Calculate stats from activities
        let stats = calculateStats(from: activities)

        for award in AwardsLibrary.allAwards {
            if checkRequirement(award.requirement, stats: stats, activities: activities) {
                earnedIds.append(award.id)
            }
        }

        return earnedIds
    }

    /// Get earned awards with full details
    func getEarnedAwardsWithDetails(activities: [Activity], athleteId: Int) -> [(award: AwardDefinition, earnedDate: Date?)] {
        let earnedIds = calculateEarnedAwards(activities: activities, athleteId: athleteId)

        return AwardsLibrary.allAwards.compactMap { award in
            if earnedIds.contains(award.id) {
                // Find the activity that earned this award
                let earnedDate = findEarnedDate(for: award, activities: activities)
                return (award, earnedDate)
            }
            return nil
        }
    }

    /// Get all awards with earned status
    func getAllAwardsWithStatus(activities: [Activity], athleteId: Int) -> [(award: AwardDefinition, isEarned: Bool, progress: Double)] {
        let stats = calculateStats(from: activities)

        return AwardsLibrary.allAwards.map { award in
            let isEarned = checkRequirement(award.requirement, stats: stats, activities: activities)
            let progress = calculateProgress(for: award.requirement, stats: stats, activities: activities)
            return (award, isEarned, progress)
        }
    }

    // MARK: - Stats Calculation

    private struct ActivityStats {
        var totalDistanceMiles: Double = 0
        var totalRuns: Int = 0
        var totalTimeHours: Double = 0
        var totalElevationFeet: Double = 0
        var fastestPace: Double = Double.infinity // min/mile
        var longestRunMiles: Double = 0
        var weeklyStreak: Int = 0
    }

    private func calculateStats(from activities: [Activity]) -> ActivityStats {
        var stats = ActivityStats()

        // Filter to running activities only
        let runningActivities = activities.filter { activity in
            guard let type = activity.type?.lowercased() else { return false }
            return type.contains("run") || type.contains("running")
        }

        stats.totalRuns = runningActivities.count

        for activity in runningActivities {
            // Distance
            if let distance = activity.distance {
                let miles = distance * 0.000621371
                stats.totalDistanceMiles += miles
                if miles > stats.longestRunMiles {
                    stats.longestRunMiles = miles
                }
            }

            // Time
            if let time = activity.elapsed_time {
                stats.totalTimeHours += time / 3600.0
            }

            // Pace
            if let distance = activity.distance, let time = activity.elapsed_time,
               distance > 0, time > 0 {
                let miles = distance * 0.000621371
                let pace = (time / 60.0) / miles // min/mile
                if pace < stats.fastestPace && miles >= 1.0 { // Only count if at least 1 mile
                    stats.fastestPace = pace
                }
            }

            // Elevation
            if let elevation = activity.elevation_gain {
                stats.totalElevationFeet += elevation * 3.28084 // meters to feet
            }
        }

        // Calculate weekly streak
        stats.weeklyStreak = calculateWeeklyStreak(activities: runningActivities)

        return stats
    }

    private func calculateWeeklyStreak(activities: [Activity]) -> Int {
        guard !activities.isEmpty else { return 0 }

        let calendar = Calendar.current
        let now = Date()

        // Group activities by week
        var weeksWithRuns: Set<Int> = []

        for activity in activities {
            guard let dateInterval = activity.activity_date ?? activity.start_date else { continue }
            let date = Date(timeIntervalSince1970: dateInterval)
            let weekOfYear = calendar.component(.weekOfYear, from: date)
            let year = calendar.component(.year, from: date)
            let weekKey = year * 100 + weekOfYear
            weeksWithRuns.insert(weekKey)
        }

        // Count consecutive weeks from current week backwards
        var streak = 0
        var checkDate = now

        while true {
            let weekOfYear = calendar.component(.weekOfYear, from: checkDate)
            let year = calendar.component(.year, from: checkDate)
            let weekKey = year * 100 + weekOfYear

            if weeksWithRuns.contains(weekKey) {
                streak += 1
                checkDate = calendar.date(byAdding: .weekOfYear, value: -1, to: checkDate) ?? checkDate
            } else {
                break
            }

            // Safety limit
            if streak > 200 { break }
        }

        return streak
    }

    // MARK: - Requirement Checking

    private func checkRequirement(_ requirement: AwardRequirement, stats: ActivityStats, activities: [Activity]) -> Bool {
        switch requirement.type {
        case .totalDistance:
            return stats.totalDistanceMiles >= requirement.value
        case .singleRunDistance:
            return stats.longestRunMiles >= requirement.value
        case .totalRuns:
            return Double(stats.totalRuns) >= requirement.value
        case .weeklyStreak:
            return Double(stats.weeklyStreak) >= requirement.value
        case .dailyStreak:
            return false // TODO: Implement daily streak
        case .fastestPace:
            return stats.fastestPace <= requirement.value && stats.fastestPace > 0
        case .totalTime:
            return stats.totalTimeHours >= requirement.value
        case .runsInWeek:
            return false // TODO: Implement
        case .runsInMonth:
            return false // TODO: Implement
        case .elevationGain:
            return stats.totalElevationFeet >= requirement.value
        }
    }

    private func calculateProgress(for requirement: AwardRequirement, stats: ActivityStats, activities: [Activity]) -> Double {
        switch requirement.type {
        case .totalDistance:
            return min(stats.totalDistanceMiles / requirement.value, 1.0)
        case .singleRunDistance:
            return min(stats.longestRunMiles / requirement.value, 1.0)
        case .totalRuns:
            return min(Double(stats.totalRuns) / requirement.value, 1.0)
        case .weeklyStreak:
            return min(Double(stats.weeklyStreak) / requirement.value, 1.0)
        case .dailyStreak:
            return 0
        case .fastestPace:
            if stats.fastestPace == Double.infinity { return 0 }
            // For pace, lower is better
            return stats.fastestPace <= requirement.value ? 1.0 : min(requirement.value / stats.fastestPace, 0.99)
        case .totalTime:
            return min(stats.totalTimeHours / requirement.value, 1.0)
        case .runsInWeek, .runsInMonth:
            return 0
        case .elevationGain:
            return min(stats.totalElevationFeet / requirement.value, 1.0)
        }
    }

    // MARK: - Helper Methods

    private func findEarnedDate(for award: AwardDefinition, activities: [Activity]) -> Date? {
        // Sort activities by date
        let sortedActivities = activities.sorted { a, b in
            let dateA = a.activity_date ?? a.start_date ?? 0
            let dateB = b.activity_date ?? b.start_date ?? 0
            return dateA < dateB
        }

        // Find first activity that would earn this award
        var cumulativeStats = ActivityStats()

        for activity in sortedActivities {
            guard let type = activity.type?.lowercased(),
                  type.contains("run") || type.contains("running") else { continue }

            // Update cumulative stats
            if let distance = activity.distance {
                let miles = distance * 0.000621371
                cumulativeStats.totalDistanceMiles += miles
                if miles > cumulativeStats.longestRunMiles {
                    cumulativeStats.longestRunMiles = miles
                }
            }
            cumulativeStats.totalRuns += 1

            if let time = activity.elapsed_time {
                cumulativeStats.totalTimeHours += time / 3600.0
            }

            if let elevation = activity.elevation_gain {
                cumulativeStats.totalElevationFeet += elevation * 3.28084
            }

            // Check if this activity earned the award
            if checkRequirement(award.requirement, stats: cumulativeStats, activities: Array(sortedActivities.prefix(cumulativeStats.totalRuns))) {
                if let dateInterval = activity.activity_date ?? activity.start_date {
                    return Date(timeIntervalSince1970: dateInterval)
                }
            }
        }

        return nil
    }
}
