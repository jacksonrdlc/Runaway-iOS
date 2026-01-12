//
//  TrainingPhaseService.swift
//  Runaway iOS
//
//  Service for detecting training phase and generating context
//

import Foundation

// MARK: - Training Phase Service

class TrainingPhaseService {

    // MARK: - Phase Detection

    /// Detect the current training phase based on activities and training load data
    static func detectPhase(
        activities: [Activity],
        trainingLoad: TrainingLoadAnalysis?
    ) -> TrainingPhaseContext {

        let activityCount = activities.count

        // New user check (< 5 activities)
        if activityCount < 5 {
            return createContext(
                phase: .newUser,
                confidence: 1.0,
                activities: activities,
                trainingLoad: trainingLoad
            )
        }

        // If we have training load data, use it for more accurate detection
        if let load = trainingLoad {
            return detectPhaseFromTrainingLoad(load, activities: activities)
        }

        // Fallback to activity-based detection
        return detectPhaseFromActivities(activities)
    }

    // MARK: - Training Load Based Detection

    private static func detectPhaseFromTrainingLoad(
        _ load: TrainingLoadAnalysis,
        activities: [Activity]
    ) -> TrainingPhaseContext {

        // Check recovery status first - fatigued takes priority
        if load.recoveryStatus == "fatigued" || load.recoveryStatus == "overreaching" || load.recoveryStatus == "overtrained" {
            return createContext(
                phase: .recovery,
                confidence: 0.85,
                activities: activities,
                trainingLoad: load
            )
        }

        // Use training trend from API
        let phase: TrainingPhase
        let confidence: Double

        switch load.trainingTrend {
        case "ramping_up":
            phase = .rampingUp
            confidence = 0.9
        case "tapering":
            phase = .tapering
            confidence = 0.9
        case "detraining":
            phase = .detraining
            confidence = 0.85
        case "steady":
            phase = .steady
            confidence = 0.85
        default:
            phase = .steady
            confidence = 0.5
        }

        return createContext(
            phase: phase,
            confidence: confidence,
            activities: activities,
            trainingLoad: load
        )
    }

    // MARK: - Activity Based Detection (Fallback)

    private static func detectPhaseFromActivities(_ activities: [Activity]) -> TrainingPhaseContext {
        let recentActivities = activities.filter { activity in
            guard let date = activity.date else { return false }
            return date >= Calendar.current.date(byAdding: .day, value: -28, to: Date())!
        }

        let weeklyVolumes = calculateWeeklyVolumes(from: activities)

        // Check for detraining (no activities in last 10 days)
        let daysSinceLastActivity = daysSinceLastActivity(activities)
        if daysSinceLastActivity > 10 {
            return createContext(
                phase: .detraining,
                confidence: 0.8,
                activities: activities,
                trainingLoad: nil
            )
        }

        // Calculate volume trend
        if weeklyVolumes.count >= 2 {
            let recentAvg = weeklyVolumes.prefix(2).reduce(0, +) / Double(min(2, weeklyVolumes.count))
            let olderAvg = weeklyVolumes.dropFirst(2).prefix(2).reduce(0, +) / Double(min(2, max(1, weeklyVolumes.count - 2)))

            if olderAvg > 0 {
                let changePercent = ((recentAvg - olderAvg) / olderAvg) * 100

                if changePercent > 15 {
                    return createContext(
                        phase: .rampingUp,
                        confidence: 0.7,
                        activities: activities,
                        trainingLoad: nil
                    )
                } else if changePercent < -20 {
                    // Could be tapering or detraining - need more context
                    // For now, assume tapering if activity count is high
                    if recentActivities.count >= 3 {
                        return createContext(
                            phase: .tapering,
                            confidence: 0.6,
                            activities: activities,
                            trainingLoad: nil
                        )
                    } else {
                        return createContext(
                            phase: .detraining,
                            confidence: 0.6,
                            activities: activities,
                            trainingLoad: nil
                        )
                    }
                }
            }
        }

        // Default to steady
        return createContext(
            phase: .steady,
            confidence: 0.6,
            activities: activities,
            trainingLoad: nil
        )
    }

    // MARK: - Context Creation

    private static func createContext(
        phase: TrainingPhase,
        confidence: Double,
        activities: [Activity],
        trainingLoad: TrainingLoadAnalysis?
    ) -> TrainingPhaseContext {

        let weeklyVolumeKm = trainingLoad?.totalVolumeKm ?? calculateCurrentWeekVolume(from: activities)
        let volumeChange = calculateVolumeChange(from: activities)
        let streakDays = calculateStreakDays(from: activities)

        let recommendations = generateRecommendations(
            for: phase,
            trainingLoad: trainingLoad,
            streakDays: streakDays
        )

        return TrainingPhaseContext(
            phase: phase,
            confidence: confidence,
            activityCount: activities.count,
            weeklyVolumeKm: weeklyVolumeKm,
            volumeChange: volumeChange,
            streakDays: streakDays,
            daysUntilRace: nil, // Would need goal data
            recoveryStatus: trainingLoad?.recoveryStatus,
            recommendations: recommendations
        )
    }

    // MARK: - Metrics Generation

    /// Generate taper metrics for tapering phase
    static func generateTaperMetrics(
        activities: [Activity],
        trainingLoad: TrainingLoadAnalysis?,
        daysUntilRace: Int,
        raceGoal: String?,
        racePredictions: [RacePrediction]?
    ) -> TaperMetrics {

        let peakVolumeKm = calculatePeakWeeklyVolume(from: activities)
        let currentVolumeKm = trainingLoad?.totalVolumeKm ?? calculateCurrentWeekVolume(from: activities)

        let currentVolumePercent = peakVolumeKm > 0 ? (currentVolumeKm / peakVolumeKm) * 100 : 100

        // Calculate target volume based on days until race
        // Standard taper: 2 weeks, reducing to ~60% by race week
        let targetVolumePercent: Double
        if daysUntilRace <= 7 {
            targetVolumePercent = 50
        } else if daysUntilRace <= 14 {
            targetVolumePercent = 70
        } else {
            targetVolumePercent = 85
        }

        // Get race prediction if available
        let predictedTime = racePredictions?.first { $0.distance.lowercased().contains(raceGoal?.lowercased() ?? "") }?.predictedTime

        return TaperMetrics(
            daysUntilRace: daysUntilRace,
            currentVolumePercent: currentVolumePercent,
            targetVolumePercent: targetVolumePercent,
            peakVolumeKm: peakVolumeKm,
            currentVolumeKm: currentVolumeKm,
            raceGoal: raceGoal,
            predictedRaceTime: predictedTime,
            confidenceLevel: racePredictions?.first?.confidence ?? "medium"
        )
    }

    /// Generate volume consistency metrics
    static func generateVolumeMetrics(
        activities: [Activity],
        trainingLoad: TrainingLoadAnalysis?
    ) -> VolumeConsistencyMetrics {

        let weeklyVolumes = calculateWeeklyVolumes(from: activities)

        let currentWeekKm = weeklyVolumes.first ?? 0
        let previousWeekKm = weeklyVolumes.dropFirst().first ?? 0
        let fourWeekAverageKm = weeklyVolumes.prefix(4).reduce(0, +) / Double(min(4, max(1, weeklyVolumes.count)))

        let weekOverWeekChange = previousWeekKm > 0 ? ((currentWeekKm - previousWeekKm) / previousWeekKm) * 100 : 0

        let consistencyScore = calculateConsistencyScore(weeklyVolumes: weeklyVolumes)
        let streakWeeks = calculateStreakWeeks(weeklyVolumes: weeklyVolumes)

        return VolumeConsistencyMetrics(
            currentWeekKm: currentWeekKm,
            previousWeekKm: previousWeekKm,
            fourWeekAverageKm: fourWeekAverageKm,
            weekOverWeekChange: weekOverWeekChange,
            consistencyScore: consistencyScore,
            streakWeeks: streakWeeks,
            targetWeeklyKm: nil
        )
    }

    /// Generate recovery metrics
    static func generateRecoveryMetrics(
        activities: [Activity],
        trainingLoad: TrainingLoadAnalysis?
    ) -> RecoveryMetrics {

        let last7Days = activities.filter { activity in
            guard let date = activity.date else { return false }
            return date >= Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        }

        let restDays = 7 - Set(last7Days.compactMap { $0.date?.startOfDay }).count
        let qualityRuns = last7Days.filter { ($0.distanceMeters ?? 0) > 5000 }.count

        let recoveryScore: Double
        let status = trainingLoad?.recoveryStatus ?? "adequate"

        switch status {
        case "well_recovered": recoveryScore = 90
        case "adequate": recoveryScore = 70
        case "fatigued": recoveryScore = 45
        case "overreaching": recoveryScore = 25
        case "overtrained": recoveryScore = 10
        default: recoveryScore = 60
        }

        let suggestedRestDays = max(0, 2 - restDays)

        var recommendations: [String] = []
        if recoveryScore < 50 {
            recommendations.append("Take an extra rest day this week")
            recommendations.append("Focus on sleep quality (7-9 hours)")
            recommendations.append("Consider a recovery run instead of hard workout")
        } else if recoveryScore < 70 {
            recommendations.append("Maintain current training but listen to your body")
            recommendations.append("Prioritize post-run stretching")
        } else {
            recommendations.append("You're well recovered - ready for quality work")
        }

        return RecoveryMetrics(
            recoveryScore: recoveryScore,
            status: status,
            acwr: trainingLoad?.acwr ?? 1.0,
            restDaysLast7: restDays,
            qualityRunsLast7: qualityRuns,
            suggestedRestDays: suggestedRestDays,
            recommendations: recommendations
        )
    }

    /// Generate progression metrics for new users
    static func generateProgressionMetrics(activities: [Activity]) -> ProgressionMetrics {
        let sortedActivities = activities.sorted { ($0.date ?? Date.distantPast) < ($1.date ?? Date.distantPast) }

        let totalDistanceKm = activities.reduce(0) { $0 + (($1.distanceMeters ?? 0) / 1000) }
        let longestRunKm = activities.map { ($0.distanceMeters ?? 0) / 1000 }.max() ?? 0

        let avgPace: Double
        let totalTime = activities.reduce(0) { $0 + ($1.duration ?? 0) }
        if totalDistanceKm > 0 {
            avgPace = (totalTime / 60) / totalDistanceKm // min per km
        } else {
            avgPace = 0
        }

        let milestones = generateMilestones(
            activityCount: activities.count,
            totalDistanceKm: totalDistanceKm,
            longestRunKm: longestRunKm
        )

        return ProgressionMetrics(
            totalActivities: activities.count,
            totalDistanceKm: totalDistanceKm,
            averagePaceMinPerKm: avgPace,
            longestRunKm: longestRunKm,
            firstActivityDate: sortedActivities.first?.date,
            milestones: milestones
        )
    }

    // MARK: - Helper Methods

    private static func calculateWeeklyVolumes(from activities: [Activity]) -> [Double] {
        let calendar = Calendar.current
        var weeklyVolumes: [Double] = []

        for weekOffset in 0..<8 {
            let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: Date())!.startOfWeek
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!

            let weekActivities = activities.filter { activity in
                guard let date = activity.date else { return false }
                return date >= weekStart && date < weekEnd
            }

            let volumeKm = weekActivities.reduce(0) { $0 + (($1.distanceMeters ?? 0) / 1000) }
            weeklyVolumes.append(volumeKm)
        }

        return weeklyVolumes
    }

    private static func calculateCurrentWeekVolume(from activities: [Activity]) -> Double {
        let weekStart = Date().startOfWeek
        let weekActivities = activities.filter { activity in
            guard let date = activity.date else { return false }
            return date >= weekStart
        }
        return weekActivities.reduce(0) { $0 + (($1.distanceMeters ?? 0) / 1000) }
    }

    private static func calculatePeakWeeklyVolume(from activities: [Activity]) -> Double {
        let volumes = calculateWeeklyVolumes(from: activities)
        return volumes.max() ?? 0
    }

    private static func calculateVolumeChange(from activities: [Activity]) -> Double {
        let volumes = calculateWeeklyVolumes(from: activities)
        guard volumes.count >= 2, volumes[1] > 0 else { return 0 }
        return ((volumes[0] - volumes[1]) / volumes[1]) * 100
    }

    private static func calculateStreakDays(from activities: [Activity]) -> Int {
        let calendar = Calendar.current
        var streakDays = 0
        var currentDate = Date().startOfDay

        let activityDates = Set(activities.compactMap { $0.date?.startOfDay })

        // Count backwards from today
        while activityDates.contains(currentDate) {
            streakDays += 1
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
        }

        return streakDays
    }

    private static func daysSinceLastActivity(_ activities: [Activity]) -> Int {
        guard let lastDate = activities.compactMap({ $0.date }).max() else {
            return Int.max
        }
        return Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
    }

    private static func calculateConsistencyScore(weeklyVolumes: [Double]) -> Double {
        guard weeklyVolumes.count >= 4 else { return 50 }

        let recentVolumes = Array(weeklyVolumes.prefix(4))
        let nonZeroWeeks = recentVolumes.filter { $0 > 0 }.count
        let average = recentVolumes.reduce(0, +) / Double(recentVolumes.count)

        // Calculate coefficient of variation (lower = more consistent)
        if average > 0 {
            let variance = recentVolumes.reduce(0) { $0 + pow($1 - average, 2) } / Double(recentVolumes.count)
            let stdDev = sqrt(variance)
            let cv = stdDev / average

            // Convert CV to score (lower CV = higher score)
            let baseScore = max(0, 100 - (cv * 100))
            let weekBonus = Double(nonZeroWeeks) * 10

            return min(100, baseScore + weekBonus)
        }

        return Double(nonZeroWeeks) * 25
    }

    private static func calculateStreakWeeks(weeklyVolumes: [Double]) -> Int {
        var streak = 0
        for volume in weeklyVolumes {
            if volume > 0 {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    private static func generateRecommendations(
        for phase: TrainingPhase,
        trainingLoad: TrainingLoadAnalysis?,
        streakDays: Int
    ) -> [String] {
        var recommendations: [String] = []

        switch phase {
        case .newUser:
            recommendations.append("Start with 3 runs per week")
            recommendations.append("Keep runs conversational pace")
            recommendations.append("Increase weekly distance by no more than 10%")

        case .rampingUp:
            recommendations.append("Continue gradual progression")
            if streakDays > 5 {
                recommendations.append("Consider a rest day soon")
            }
            recommendations.append("Focus on easy runs (80% of training)")

        case .tapering:
            recommendations.append("Reduce volume but maintain intensity")
            recommendations.append("Trust your training")
            recommendations.append("Focus on sleep and nutrition")

        case .detraining:
            recommendations.append("Start with easy, short runs")
            recommendations.append("Rebuild gradually over 2-4 weeks")
            recommendations.append("Listen to your body")

        case .steady:
            recommendations.append("Great consistency! Consider adding variety")
            if let load = trainingLoad, load.acwr > 1.3 {
                recommendations.append("Monitor training load - slightly elevated")
            }

        case .recovery:
            recommendations.append("Prioritize rest and sleep")
            recommendations.append("Easy runs only this week")
            recommendations.append("Consider cross-training")
        }

        return recommendations
    }

    private static func generateMilestones(
        activityCount: Int,
        totalDistanceKm: Double,
        longestRunKm: Double
    ) -> [ProgressionMilestone] {
        return [
            ProgressionMilestone(
                title: "First Run",
                description: "Complete your first activity",
                isAchieved: activityCount >= 1,
                icon: "1.circle.fill"
            ),
            ProgressionMilestone(
                title: "5 Runs",
                description: "Complete 5 activities",
                isAchieved: activityCount >= 5,
                icon: "5.circle.fill"
            ),
            ProgressionMilestone(
                title: "First 5K",
                description: "Run 5 kilometers",
                isAchieved: longestRunKm >= 5,
                icon: "flag.fill"
            ),
            ProgressionMilestone(
                title: "10 Runs",
                description: "Complete 10 activities",
                isAchieved: activityCount >= 10,
                icon: "10.circle.fill"
            ),
            ProgressionMilestone(
                title: "First 10K",
                description: "Run 10 kilometers",
                isAchieved: longestRunKm >= 10,
                icon: "star.fill"
            )
        ]
    }
}

// MARK: - Date Extensions

private extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var startOfWeek: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components) ?? self
    }
}
