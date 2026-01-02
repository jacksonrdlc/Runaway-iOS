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
    @Published var lifetimeStats: LifetimeRunningStats? = nil
    @Published var lastLoadedUserId: Int? = nil

    private init() {}

    // MARK: - Lifetime Stats Model (from database)

    struct LifetimeRunningStats: Codable {
        let totalDistanceMeters: Double
        let totalRuns: Int
        let totalTimeSeconds: Double
        let totalElevationMeters: Double
        let longestRunMeters: Double
        let fastestPaceSecondsPerMeter: Double?
        let weeklyStreak: Int

        enum CodingKeys: String, CodingKey {
            case totalDistanceMeters = "total_distance_meters"
            case totalRuns = "total_runs"
            case totalTimeSeconds = "total_time_seconds"
            case totalElevationMeters = "total_elevation_meters"
            case longestRunMeters = "longest_run_meters"
            case fastestPaceSecondsPerMeter = "fastest_pace_seconds_per_meter"
            case weeklyStreak = "weekly_streak"
        }

        // Computed properties for awards (converted to miles, hours, feet, min/mile)
        var totalDistanceMiles: Double { totalDistanceMeters * 0.000621371 }
        var totalTimeHours: Double { totalTimeSeconds / 3600.0 }
        var totalElevationFeet: Double { totalElevationMeters * 3.28084 }
        var longestRunMiles: Double { longestRunMeters * 0.000621371 }
        var fastestPaceMinPerMile: Double? {
            guard let pace = fastestPaceSecondsPerMeter, pace > 0 else { return nil }
            // Convert seconds/meter to min/mile
            return (pace * 1609.34) / 60.0
        }
    }

    // MARK: - Load Lifetime Stats from Database

    /// Load lifetime stats with a single database call (efficient!)
    func loadLifetimeStats(for athleteId: Int) async {
        // Skip if already loaded for this user
        if lastLoadedUserId == athleteId && lifetimeStats != nil {
            print("✅ AwardsService: Using cached lifetime stats")
            return
        }

        await MainActor.run { isLoading = true }

        do {
            print("🔄 AwardsService: Loading lifetime stats for athlete \(athleteId)...")

            let stats: LifetimeRunningStats = try await supabase
                .rpc("get_lifetime_running_stats", params: ["p_athlete_id": athleteId])
                .execute()
                .value

            await MainActor.run {
                self.lifetimeStats = stats
                self.lastLoadedUserId = athleteId
                self.isLoading = false
            }
            print("✅ AwardsService: Loaded stats - \(stats.totalRuns) runs, \(String(format: "%.1f", stats.totalDistanceMiles)) miles")
        } catch {
            print("❌ AwardsService: Failed to load stats from DB: \(error)")
            print("⚠️ AwardsService: Falling back to client-side calculation...")
            // Fallback to client-side calculation if RPC doesn't exist yet
            await loadLifetimeStatsFallback(for: athleteId)
        }
    }

    /// Fallback: Calculate stats client-side (used if database function doesn't exist)
    private func loadLifetimeStatsFallback(for athleteId: Int) async {
        do {
            let activities = try await SupabaseActivityRepository.shared.getAllActivities(userId: athleteId)
            let stats = calculateStats(from: activities)

            await MainActor.run {
                self.lifetimeStats = LifetimeRunningStats(
                    totalDistanceMeters: stats.totalDistanceMiles / 0.000621371,
                    totalRuns: stats.totalRuns,
                    totalTimeSeconds: stats.totalTimeHours * 3600,
                    totalElevationMeters: stats.totalElevationFeet / 3.28084,
                    longestRunMeters: stats.longestRunMiles / 0.000621371,
                    fastestPaceSecondsPerMeter: stats.fastestPace == Double.infinity ? nil : (stats.fastestPace * 60) / 1609.34,
                    weeklyStreak: stats.weeklyStreak
                )
                self.lastLoadedUserId = athleteId
                self.isLoading = false
            }
            print("✅ AwardsService: Loaded stats via fallback - \(activities.count) activities processed")
        } catch {
            print("❌ AwardsService: Fallback also failed: \(error)")
            await MainActor.run { isLoading = false }
        }
    }

    /// Force refresh stats
    func refreshStats(for athleteId: Int) async {
        lastLoadedUserId = nil
        lifetimeStats = nil
        await loadLifetimeStats(for: athleteId)
    }

    // MARK: - Public Methods (using lifetime stats)

    /// Get all awards with earned status using lifetime stats (efficient - no activities needed)
    func getAllAwardsWithStatusFromStats() -> [(award: AwardDefinition, isEarned: Bool, progress: Double)] {
        guard let stats = lifetimeStats else {
            return AwardsLibrary.allAwards.map { ($0, false, 0.0) }
        }

        return AwardsLibrary.allAwards.map { award in
            let isEarned = checkRequirementFromStats(award.requirement, stats: stats)
            let progress = calculateProgressFromStats(for: award.requirement, stats: stats)
            return (award, isEarned, progress)
        }
    }

    /// Get earned awards using lifetime stats
    func getEarnedAwardsFromStats() -> [(award: AwardDefinition, earnedDate: Date?)] {
        guard let stats = lifetimeStats else { return [] }

        return AwardsLibrary.allAwards.compactMap { award in
            if checkRequirementFromStats(award.requirement, stats: stats) {
                return (award, nil) // Date not available from aggregate stats
            }
            return nil
        }
    }

    /// Get progress details for a specific award using lifetime stats
    func getProgressDetailsFromStats(for award: AwardDefinition) -> (current: Double, target: Double, unit: String, formattedCurrent: String, formattedTarget: String) {
        guard let stats = lifetimeStats else {
            return (0, award.requirement.value, award.requirement.unit ?? "", "0", String(format: "%.0f", award.requirement.value))
        }

        let req = award.requirement

        switch req.type {
        case .totalDistance:
            return (
                current: stats.totalDistanceMiles,
                target: req.value,
                unit: "miles",
                formattedCurrent: String(format: "%.1f", stats.totalDistanceMiles),
                formattedTarget: String(format: "%.0f", req.value)
            )
        case .singleRunDistance:
            return (
                current: stats.longestRunMiles,
                target: req.value,
                unit: "miles",
                formattedCurrent: String(format: "%.1f", stats.longestRunMiles),
                formattedTarget: String(format: "%.1f", req.value)
            )
        case .totalRuns:
            return (
                current: Double(stats.totalRuns),
                target: req.value,
                unit: "runs",
                formattedCurrent: "\(stats.totalRuns)",
                formattedTarget: String(format: "%.0f", req.value)
            )
        case .weeklyStreak:
            return (
                current: Double(stats.weeklyStreak),
                target: req.value,
                unit: "weeks",
                formattedCurrent: "\(stats.weeklyStreak)",
                formattedTarget: String(format: "%.0f", req.value)
            )
        case .dailyStreak:
            return (current: 0, target: req.value, unit: "days", formattedCurrent: "0", formattedTarget: String(format: "%.0f", req.value))
        case .fastestPace:
            let currentPace = stats.fastestPaceMinPerMile ?? 0
            let paceMin = Int(currentPace)
            let paceSec = Int((currentPace - Double(paceMin)) * 60)
            let targetMin = Int(req.value)
            let targetSec = Int((req.value - Double(targetMin)) * 60)
            return (
                current: currentPace,
                target: req.value,
                unit: "min/mile",
                formattedCurrent: currentPace > 0 ? String(format: "%d:%02d", paceMin, paceSec) : "--:--",
                formattedTarget: String(format: "%d:%02d", targetMin, targetSec)
            )
        case .totalTime:
            return (
                current: stats.totalTimeHours,
                target: req.value,
                unit: "hours",
                formattedCurrent: String(format: "%.1f", stats.totalTimeHours),
                formattedTarget: String(format: "%.0f", req.value)
            )
        case .runsInWeek, .runsInMonth:
            return (current: 0, target: req.value, unit: "runs", formattedCurrent: "0", formattedTarget: String(format: "%.0f", req.value))
        case .elevationGain:
            return (
                current: stats.totalElevationFeet,
                target: req.value,
                unit: "feet",
                formattedCurrent: String(format: "%.0f", stats.totalElevationFeet),
                formattedTarget: String(format: "%.0f", req.value)
            )
        }
    }

    // MARK: - Requirement Checking (from lifetime stats)

    private func checkRequirementFromStats(_ requirement: AwardRequirement, stats: LifetimeRunningStats) -> Bool {
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
            return false
        case .fastestPace:
            guard let pace = stats.fastestPaceMinPerMile else { return false }
            return pace <= requirement.value && pace > 0
        case .totalTime:
            return stats.totalTimeHours >= requirement.value
        case .runsInWeek, .runsInMonth:
            return false
        case .elevationGain:
            return stats.totalElevationFeet >= requirement.value
        }
    }

    private func calculateProgressFromStats(for requirement: AwardRequirement, stats: LifetimeRunningStats) -> Double {
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
            guard let pace = stats.fastestPaceMinPerMile, pace > 0 else { return 0 }
            return pace <= requirement.value ? 1.0 : min(requirement.value / pace, 0.99)
        case .totalTime:
            return min(stats.totalTimeHours / requirement.value, 1.0)
        case .runsInWeek, .runsInMonth:
            return 0
        case .elevationGain:
            return min(stats.totalElevationFeet / requirement.value, 1.0)
        }
    }

    // MARK: - Legacy Methods (using activities - for backwards compatibility)

    /// Calculate all earned awards based on activities
    func calculateEarnedAwards(activities: [Activity], athleteId: Int) -> [String] {
        var earnedIds: [String] = []
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

    struct ActivityStats {
        var totalDistanceMiles: Double = 0
        var totalRuns: Int = 0
        var totalTimeHours: Double = 0
        var totalElevationFeet: Double = 0
        var fastestPace: Double = Double.infinity // min/mile
        var longestRunMiles: Double = 0
        var weeklyStreak: Int = 0
    }

    /// Get current stats from activities (public for UI display)
    func getStats(from activities: [Activity]) -> ActivityStats {
        return calculateStats(from: activities)
    }

    /// Get current value and target for a specific award requirement
    func getProgressDetails(for award: AwardDefinition, activities: [Activity]) -> (current: Double, target: Double, unit: String, formattedCurrent: String, formattedTarget: String) {
        let stats = calculateStats(from: activities)
        let req = award.requirement

        switch req.type {
        case .totalDistance:
            return (
                current: stats.totalDistanceMiles,
                target: req.value,
                unit: "miles",
                formattedCurrent: String(format: "%.1f", stats.totalDistanceMiles),
                formattedTarget: String(format: "%.0f", req.value)
            )
        case .singleRunDistance:
            return (
                current: stats.longestRunMiles,
                target: req.value,
                unit: "miles",
                formattedCurrent: String(format: "%.1f", stats.longestRunMiles),
                formattedTarget: String(format: "%.1f", req.value)
            )
        case .totalRuns:
            return (
                current: Double(stats.totalRuns),
                target: req.value,
                unit: "runs",
                formattedCurrent: "\(stats.totalRuns)",
                formattedTarget: String(format: "%.0f", req.value)
            )
        case .weeklyStreak:
            return (
                current: Double(stats.weeklyStreak),
                target: req.value,
                unit: "weeks",
                formattedCurrent: "\(stats.weeklyStreak)",
                formattedTarget: String(format: "%.0f", req.value)
            )
        case .dailyStreak:
            return (
                current: 0,
                target: req.value,
                unit: "days",
                formattedCurrent: "0",
                formattedTarget: String(format: "%.0f", req.value)
            )
        case .fastestPace:
            let currentPace = stats.fastestPace == Double.infinity ? 0 : stats.fastestPace
            let paceMin = Int(currentPace)
            let paceSec = Int((currentPace - Double(paceMin)) * 60)
            let targetMin = Int(req.value)
            let targetSec = Int((req.value - Double(targetMin)) * 60)
            return (
                current: currentPace,
                target: req.value,
                unit: "min/mile",
                formattedCurrent: currentPace > 0 ? String(format: "%d:%02d", paceMin, paceSec) : "--:--",
                formattedTarget: String(format: "%d:%02d", targetMin, targetSec)
            )
        case .totalTime:
            return (
                current: stats.totalTimeHours,
                target: req.value,
                unit: "hours",
                formattedCurrent: String(format: "%.1f", stats.totalTimeHours),
                formattedTarget: String(format: "%.0f", req.value)
            )
        case .runsInWeek, .runsInMonth:
            return (
                current: 0,
                target: req.value,
                unit: "runs",
                formattedCurrent: "0",
                formattedTarget: String(format: "%.0f", req.value)
            )
        case .elevationGain:
            return (
                current: stats.totalElevationFeet,
                target: req.value,
                unit: "feet",
                formattedCurrent: String(format: "%.0f", stats.totalElevationFeet),
                formattedTarget: String(format: "%.0f", req.value)
            )
        }
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
