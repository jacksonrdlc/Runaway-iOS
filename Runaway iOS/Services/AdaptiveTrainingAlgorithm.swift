//
//  AdaptiveTrainingAlgorithm.swift
//  Runaway iOS
//
//  Evidence-based adaptive training plan generation
//  Implements physiological principles for injury prevention and performance
//
//  Research-backed principles:
//  - Lactate threshold > VO2 max for marathon (0.91 vs 0.63 correlation)
//  - Single-session spikes predict injury (10-30% increase = 64% higher risk)
//  - Running economy: heavy strength (>=80% 1RM), plyometrics, hill training
//  - Long runs capped at 2.5-3 hours, 20-30% of weekly mileage
//  - Tempo runs at 25-30s/mi slower than 5K pace
//  - Progressive increases: 20-25% at low mileage, 10-15% above 30 mpw
//  - Step-back weeks every 3-4 weeks (reduce 20-40%)
//  - Consistency over sporadic high volume
//

import Foundation

// MARK: - Adaptive Training Algorithm

@MainActor
class AdaptiveTrainingAlgorithm {

    // MARK: - Evidence-Based Constants

    struct TrainingConstants {
        // Mileage progression limits
        static let lowMileageProgressionRate: ClosedRange<Double> = 0.20...0.25  // 20-25% when < 30 mpw
        static let highMileageProgressionRate: ClosedRange<Double> = 0.10...0.15 // 10-15% when >= 30 mpw
        static let lowMileageThreshold: Double = 30.0 // miles per week

        // Injury prevention (single-session spikes are key predictor)
        static let acuteChronicRatioSafe: ClosedRange<Double> = 0.8...1.3
        static let maxSingleSessionIncrease: Double = 0.10 // 10% max spike
        static let spikeInjuryRiskThreshold: Double = 0.30 // 30% = 64% higher injury risk

        // Long run constraints
        static let maxLongRunDuration: Double = 180.0 // minutes (3 hours max)
        static let longRunMileagePercentage: ClosedRange<Double> = 0.20...0.30 // 20-30% of weekly

        // Tempo run pacing (relative to 5K pace)
        static let tempoSlowerThan5K: ClosedRange<Double> = 25.0...30.0 // seconds per mile

        // Step-back weeks (every 3-4 weeks)
        static let stepBackFrequency: ClosedRange<Int> = 3...4 // weeks between step-backs
        static let stepBackReduction: ClosedRange<Double> = 0.20...0.40 // 20-40% reduction

        // Recovery
        static let minRestDaysPerWeek: Int = 2
        static let maxConsecutiveHardDays: Int = 2

        // Default paces (min/mile) - used when no history available
        static let defaultEasyPace: Double = 9.5
        static let default5KPace: Double = 7.5

        // Minimum baseline to prevent overly conservative plans
        // Even if recent data shows low volume, we don't want a 3-mile long run
        static let minimumWeeklyMileage: Double = 15.0
        static let minimumLongRun: Double = 5.0  // miles
    }

    // MARK: - Dependencies

    private let dataManager: DataManager

    // MARK: - Initialization

    init(dataManager: DataManager? = nil) {
        self.dataManager = dataManager ?? .shared
    }

    // MARK: - Plan Generation

    func generateAdaptivePlan(
        athleteId: Int,
        goal: RunningGoal?,
        settings: PlanGenerationSettings
    ) async -> WeeklyTrainingPlan {

        // 1. Calculate baseline from recent activities
        let baseline = calculateTrainingBaseline(activities: dataManager.activities)

        // 2. Determine week type (build vs step-back)
        let weekType = determineWeekType(
            recentWeeks: getRecentWeeklyMileages(),
            consecutiveBuildWeeks: settings.consecutiveBuildWeeks
        )

        // 3. Calculate target weekly mileage
        let targetMileage = calculateTargetMileage(
            baseline: baseline,
            weekType: weekType,
            goal: goal
        )

        // 4. Distribute mileage across days
        let distribution = calculateMileageDistribution(
            totalMileage: targetMileage,
            weekType: weekType,
            baseline: baseline
        )

        // 5. Assign workout types based on goal
        let workouts = assignWorkoutTypes(
            distribution: distribution,
            goal: goal,
            athlete5KPace: baseline.estimated5KPace
        )

        // 6. Build the plan
        let plan = buildWeeklyPlan(
            athleteId: athleteId,
            workouts: workouts,
            focusArea: determineFocusArea(goal: goal, weekType: weekType),
            goalId: goal?.id
        )

        return plan
    }

    // MARK: - Baseline Calculation

    func calculateTrainingBaseline(activities: [Activity]) -> TrainingBaseline {
        let calendar = Calendar.current
        let runningActivities = activities.filter {
            $0.type?.lowercased().contains("run") == true
        }

        // Get the start of the current week (Sunday) to exclude it
        let today = Date()
        let currentWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today

        // Last 4 COMPLETED weeks (excluding current week)
        let fiveWeeksAgo = calendar.date(byAdding: .weekOfYear, value: -5, to: today) ?? today
        let recentActivities = runningActivities.filter { activity in
            guard let ts = activity.activity_date ?? activity.start_date else { return false }
            let activityDate = Date(timeIntervalSince1970: ts)
            // Include activities from 5 weeks ago up to (but not including) current week
            return activityDate >= fiveWeeksAgo && activityDate < currentWeekStart
        }

        // Calculate weekly mileages
        let weeklyMileages = calculateWeeklyMileages(activities: recentActivities)
        let avgWeeklyMileage = weeklyMileages.isEmpty ? 15.0 :
            weeklyMileages.reduce(0, +) / Double(weeklyMileages.count)

        // Calculate average pace (min/mile)
        let paces = recentActivities.compactMap { activity -> Double? in
            guard let speed = activity.average_speed, speed > 0 else { return nil }
            return (1609.34 / speed) / 60.0 // min/mile
        }
        let avgPace = paces.isEmpty ? TrainingConstants.defaultEasyPace :
            paces.reduce(0, +) / Double(paces.count)

        // Estimate 5K pace (roughly 15% faster than easy pace)
        let estimated5KPace = paces.isEmpty ? TrainingConstants.default5KPace : avgPace * 0.85

        // Calculate longest recent run
        let longestRun = recentActivities.compactMap { $0.distance }.max() ?? 0
        let longestRunMiles = longestRun * 0.000621371

        // Runs per week
        let runsPerWeek = recentActivities.isEmpty ? 3 : recentActivities.count / max(1, weeklyMileages.count)

        return TrainingBaseline(
            averageWeeklyMileage: avgWeeklyMileage,
            averageEasyPace: avgPace,
            estimated5KPace: estimated5KPace,
            longestRecentRun: longestRunMiles,
            runsPerWeek: runsPerWeek,
            weeklyMileages: weeklyMileages
        )
    }

    // MARK: - Week Type Determination

    func determineWeekType(
        recentWeeks: [Double],
        consecutiveBuildWeeks: Int
    ) -> WeekType {
        // Step-back every 3-4 weeks
        if consecutiveBuildWeeks >= TrainingConstants.stepBackFrequency.lowerBound {
            return .stepBack
        }

        // Check for overload using ACWR
        if let acwr = calculateACWR(recentWeeks: recentWeeks) {
            if acwr > TrainingConstants.acuteChronicRatioSafe.upperBound {
                return .stepBack
            }
        }

        return .build
    }

    // MARK: - Target Mileage Calculation

    func calculateTargetMileage(
        baseline: TrainingBaseline,
        weekType: WeekType,
        goal: RunningGoal?
    ) -> Double {
        // Use detected baseline but enforce minimum to avoid overly conservative plans
        let currentMileage = max(baseline.averageWeeklyMileage, TrainingConstants.minimumWeeklyMileage)

        var targetMileage: Double
        switch weekType {
        case .build:
            // Progressive increase based on current volume
            let progressionRate: Double
            if currentMileage < TrainingConstants.lowMileageThreshold {
                progressionRate = TrainingConstants.lowMileageProgressionRate.lowerBound
            } else {
                progressionRate = TrainingConstants.highMileageProgressionRate.lowerBound
            }
            targetMileage = currentMileage * (1 + progressionRate)

        case .stepBack:
            // Reduce by 20-40%
            targetMileage = currentMileage * (1 - TrainingConstants.stepBackReduction.lowerBound)

        case .recovery:
            targetMileage = currentMileage * 0.5

        case .race:
            targetMileage = currentMileage * 0.6
        }

        // Enforce minimum weekly mileage
        return max(targetMileage, TrainingConstants.minimumWeeklyMileage)
    }

    // MARK: - Mileage Distribution

    func calculateMileageDistribution(
        totalMileage: Double,
        weekType: WeekType,
        baseline: TrainingBaseline
    ) -> [DayMileageAllocation] {
        // Long run: 20-30% of weekly, capped at 3-hour equivalent
        let longRunPercentage = TrainingConstants.longRunMileagePercentage.upperBound
        var longRunMileage = totalMileage * longRunPercentage

        // Cap long run at 3 hours (estimate based on baseline pace)
        let longRunPace = baseline.averageEasyPace * 1.05 // Slightly slower than easy
        let maxLongRunMileage = TrainingConstants.maxLongRunDuration / longRunPace
        longRunMileage = min(longRunMileage, maxLongRunMileage)

        // Enforce minimum long run distance
        longRunMileage = max(longRunMileage, TrainingConstants.minimumLongRun)

        let remainingMileage = totalMileage - longRunMileage

        // Distribute remaining across 4 run days
        let avgOtherMileage = remainingMileage / 4.0

        var allocations: [DayMileageAllocation] = []

        // Sunday: Long Run
        allocations.append(DayMileageAllocation(day: .sunday, mileage: longRunMileage, type: .longRun))

        // Monday: Rest
        allocations.append(DayMileageAllocation(day: .monday, mileage: 0, type: .rest))

        // Tuesday: Easy Run
        allocations.append(DayMileageAllocation(day: .tuesday, mileage: avgOtherMileage * 0.9, type: .easyRun))

        // Wednesday: Tempo (quality day)
        allocations.append(DayMileageAllocation(day: .wednesday, mileage: avgOtherMileage * 1.2, type: .tempoRun))

        // Thursday: Easy Run
        allocations.append(DayMileageAllocation(day: .thursday, mileage: avgOtherMileage * 0.9, type: .easyRun))

        // Friday: Rest
        allocations.append(DayMileageAllocation(day: .friday, mileage: 0, type: .rest))

        // Saturday: Moderate Run
        allocations.append(DayMileageAllocation(day: .saturday, mileage: avgOtherMileage * 1.0, type: .easyRun))

        return allocations
    }

    // MARK: - Workout Type Assignment

    func assignWorkoutTypes(
        distribution: [DayMileageAllocation],
        goal: RunningGoal?,
        athlete5KPace: Double
    ) -> [DailyWorkout] {
        let calendar = Calendar.current
        let weekStart = TrainingPlanService.currentWeekSunday()

        return distribution.compactMap { allocation -> DailyWorkout? in
            guard let dayDate = calendar.date(
                byAdding: .day,
                value: allocation.day.calendarWeekday - 1,
                to: weekStart
            ) else { return nil }

            // Rest days still get entries
            if allocation.type == .rest {
                return createRestDayWorkout(date: dayDate, day: allocation.day)
            }

            // Calculate target pace for the workout type
            let targetPace = calculateTargetPace(
                workoutType: allocation.type,
                athlete5KPace: athlete5KPace
            )

            // Estimate duration
            let estimatedDuration = Int(allocation.mileage * targetPace)

            return DailyWorkout(
                id: UUID().uuidString,
                date: dayDate,
                dayOfWeek: allocation.day,
                workoutType: allocation.type,
                title: workoutTitle(for: allocation.type),
                description: workoutDescription(for: allocation.type, distance: allocation.mileage, goal: goal),
                duration: estimatedDuration,
                distance: allocation.mileage,
                targetPace: formatPace(targetPace),
                exercises: nil,
                isCompleted: false,
                completedActivityId: nil
            )
        }
    }

    // MARK: - Target Pace Calculation

    func calculateTargetPace(
        workoutType: WorkoutType,
        athlete5KPace: Double
    ) -> Double {
        switch workoutType {
        case .easyRun, .recoveryRun:
            return athlete5KPace * 1.25 // 25% slower than 5K pace

        case .longRun:
            return athlete5KPace * 1.20 // 20% slower than 5K pace

        case .tempoRun:
            // 25-30 seconds slower than 5K pace (per mile)
            let tempoSlower = TrainingConstants.tempoSlowerThan5K.lowerBound / 60.0
            return athlete5KPace + tempoSlower

        case .intervalRun:
            return athlete5KPace * 0.95 // Slightly faster than 5K

        case .hillRun:
            return athlete5KPace * 1.10 // Effort-based, not pace

        default:
            return athlete5KPace * 1.25
        }
    }

    // MARK: - ACWR Calculation (Acute:Chronic Workload Ratio)

    func calculateACWR(recentWeeks: [Double]) -> Double? {
        guard recentWeeks.count >= 4 else { return nil }

        let acuteLoad = recentWeeks.first ?? 0 // Last week
        let chronicLoad = recentWeeks.prefix(4).reduce(0, +) / 4.0 // 4-week average

        guard chronicLoad > 0 else { return nil }
        return acuteLoad / chronicLoad
    }

    // MARK: - Adaptive Analysis

    func analyzeAdaptations(
        plan: WeeklyTrainingPlan,
        activities: [Activity]
    ) -> AdaptiveInsights {
        let weekActivities = activities.filter { activity in
            guard let ts = activity.activity_date ?? activity.start_date else { return false }
            let activityDate = Date(timeIntervalSince1970: ts)
            return activityDate >= plan.weekStartDate && activityDate <= plan.weekEndDate
        }

        // Calculate actual vs planned
        let actualMileage = weekActivities.filter { AppConstants.ActivityTypes.isRunning($0.type) }.compactMap { $0.distance }.reduce(0, +) * 0.000621371
        let adherenceRate = plan.totalMileage > 0 ? min(actualMileage / plan.totalMileage, 1.5) : 0

        // Check for spikes
        let spikeWarnings = checkForLoadSpikes(
            activities: weekActivities,
            baselineActivities: activities
        )

        // Generate recommendations
        let recommendations = generateAdaptiveRecommendations(
            adherenceRate: adherenceRate,
            spikeWarnings: spikeWarnings,
            plan: plan
        )

        return AdaptiveInsights(
            adherenceRate: adherenceRate,
            spikeWarnings: spikeWarnings,
            recommendations: recommendations,
            planAdjustments: []
        )
    }

    // MARK: - Load Spike Detection

    func checkForLoadSpikes(
        activities: [Activity],
        baselineActivities: [Activity]
    ) -> [String] {
        var warnings: [String] = []

        // Get running activities from last 30 days for baseline
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recentBaseline = baselineActivities.filter { activity in
            guard let ts = activity.activity_date ?? activity.start_date else { return false }
            let activityDate = Date(timeIntervalSince1970: ts)
            return activityDate >= thirtyDaysAgo && activity.type?.lowercased().contains("run") == true
        }

        let recentDistances = recentBaseline.compactMap { $0.distance }
        guard !recentDistances.isEmpty else { return warnings }

        let avgDistance = recentDistances.reduce(0, +) / Double(recentDistances.count)

        // Check each activity this week for spikes
        for activity in activities {
            guard let distance = activity.distance else { continue }
            let increase = (distance - avgDistance) / avgDistance

            if increase > TrainingConstants.spikeInjuryRiskThreshold {
                let percentIncrease = Int(increase * 100)
                warnings.append("Single-session spike detected: \(percentIncrease)% above your 30-day average. Consider reducing intensity in your next session to allow recovery.")
            }
        }

        return warnings
    }

    // MARK: - Recommendations

    func generateAdaptiveRecommendations(
        adherenceRate: Double,
        spikeWarnings: [String],
        plan: WeeklyTrainingPlan
    ) -> [String] {
        var recommendations: [String] = []

        // Adherence-based recommendations
        if adherenceRate < 0.7 {
            recommendations.append("You're below 70% of your planned mileage. Consider whether the plan is too aggressive, or if you need to prioritize consistency.")
        } else if adherenceRate > 1.2 {
            recommendations.append("You're exceeding your planned mileage by 20%+. Be careful of overtraining - research shows single-session spikes are the biggest injury predictor.")
        } else if adherenceRate >= 0.9 && adherenceRate <= 1.1 {
            recommendations.append("Excellent adherence! You're staying consistent, which research shows matters more than any single workout.")
        }

        // Add spike warnings
        recommendations.append(contentsOf: spikeWarnings)

        // Focus area recommendations
        if let focus = plan.focusArea {
            switch focus.lowercased() {
            case "base building":
                recommendations.append("Keep runs conversational. If you can't hold a conversation, you're running too fast for base building.")
            case "threshold development":
                recommendations.append("Tempo runs should feel 'comfortably hard' - you can speak 3-4 words but not full sentences.")
            case "recovery":
                recommendations.append("This is a step-back week. Honor the recovery - it's when your body adapts to training stress.")
            default:
                break
            }
        }

        return recommendations
    }

    // MARK: - Helper Methods

    private func calculateWeeklyMileages(activities: [Activity]) -> [Double] {
        let calendar = Calendar.current
        var weeklyMileages: [Double] = []

        // Start from week 1 (last completed week), not week 0 (current incomplete week)
        // This gives us the last 4 COMPLETED weeks for a more accurate baseline
        for weekOffset in 1..<5 {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: Date()),
                  let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else {
                continue
            }

            let weekActivities = activities.filter { activity in
                guard let ts = activity.activity_date ?? activity.start_date else { return false }
                let date = Date(timeIntervalSince1970: ts)
                return date >= weekStart && date < weekEnd
            }

            let mileage = weekActivities.filter { AppConstants.ActivityTypes.isRunning($0.type) }.compactMap { $0.distance }.reduce(0, +) * 0.000621371
            weeklyMileages.append(mileage)
        }

        return weeklyMileages
    }

    private func getRecentWeeklyMileages() -> [Double] {
        return calculateWeeklyMileages(activities: dataManager.activities)
    }

    private func buildWeeklyPlan(
        athleteId: Int,
        workouts: [DailyWorkout],
        focusArea: String,
        goalId: Int?
    ) -> WeeklyTrainingPlan {
        let weekStart = TrainingPlanService.currentWeekSunday()
        let weekEnd = Calendar.current.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        let totalMileage = workouts.compactMap { $0.distance }.reduce(0, +)

        return WeeklyTrainingPlan(
            id: UUID().uuidString,
            athleteId: athleteId,
            weekStartDate: weekStart,
            weekEndDate: weekEnd,
            workouts: workouts,
            weekNumber: nil,
            totalMileage: totalMileage,
            focusArea: focusArea,
            notes: "Generated by adaptive algorithm based on your recent training",
            generatedAt: Date(),
            goalId: goalId
        )
    }

    private func createRestDayWorkout(date: Date, day: DayOfWeek) -> DailyWorkout {
        return DailyWorkout(
            id: UUID().uuidString,
            date: date,
            dayOfWeek: day,
            workoutType: .rest,
            title: "Rest Day",
            description: "Recovery is when your body adapts to training. Honor the rest.",
            duration: nil,
            distance: nil,
            targetPace: nil,
            exercises: nil,
            isCompleted: false,
            completedActivityId: nil
        )
    }

    private func determineFocusArea(goal: RunningGoal?, weekType: WeekType) -> String {
        switch weekType {
        case .stepBack:
            return "Recovery Week"
        case .recovery:
            return "Recovery"
        case .race:
            return "Race Week"
        case .build:
            // Determine based on training phase
            let baseline = calculateTrainingBaseline(activities: dataManager.activities)
            if baseline.averageWeeklyMileage < 20 {
                return "Base Building"
            } else if baseline.averageWeeklyMileage < 35 {
                return "Volume Building"
            } else {
                return "Threshold Development"
            }
        }
    }

    private func workoutTitle(for type: WorkoutType) -> String {
        switch type {
        case .easyRun: return "Easy Run"
        case .longRun: return "Long Run"
        case .tempoRun: return "Tempo Run"
        case .intervalRun: return "Interval Session"
        case .hillRun: return "Hill Workout"
        case .recoveryRun: return "Recovery Run"
        case .rest: return "Rest Day"
        default: return type.displayName
        }
    }

    private func workoutDescription(for type: WorkoutType, distance: Double, goal: RunningGoal?) -> String {
        let distanceStr = String(format: "%.1f", distance)

        switch type {
        case .easyRun:
            return "\(distanceStr) miles at conversational pace. If you can't hold a conversation, slow down."
        case .longRun:
            return "\(distanceStr) miles at easy effort. Build aerobic base and fat oxidation capacity."
        case .tempoRun:
            return "\(distanceStr) miles with middle portion at tempo pace (25-30s slower than 5K). Should feel 'comfortably hard'."
        case .intervalRun:
            return "Speed work session. Research shows lactate threshold training is most predictive of marathon success."
        case .hillRun:
            return "Hill repeats improve running economy with lower injury risk than flat speedwork."
        case .recoveryRun:
            return "\(distanceStr) miles very easy. Active recovery to promote blood flow."
        case .rest:
            return "Rest is when adaptation happens. Your body is getting stronger."
        default:
            return type.displayName
        }
    }

    private func formatPace(_ paceMinPerMile: Double) -> String {
        let minutes = Int(paceMinPerMile)
        let seconds = Int((paceMinPerMile - Double(minutes)) * 60)
        return String(format: "%d:%02d /mi", minutes, seconds)
    }
}

// MARK: - Supporting Types

struct TrainingBaseline {
    let averageWeeklyMileage: Double
    let averageEasyPace: Double      // min/mile
    let estimated5KPace: Double      // min/mile
    let longestRecentRun: Double     // miles
    let runsPerWeek: Int
    let weeklyMileages: [Double]     // Last 4 weeks
}

enum WeekType {
    case build      // Normal progression week
    case stepBack   // Recovery/deload week
    case recovery   // Light recovery
    case race       // Race week taper
}

struct DayMileageAllocation {
    let day: DayOfWeek
    let mileage: Double
    let type: WorkoutType
}

struct PlanGenerationSettings {
    var preferredRunDays: [DayOfWeek]
    var consecutiveBuildWeeks: Int
    var includeStrength: Bool
    var targetRaceDate: Date?

    static let `default` = PlanGenerationSettings(
        preferredRunDays: [.sunday, .tuesday, .wednesday, .thursday, .saturday],
        consecutiveBuildWeeks: 0,
        includeStrength: false,
        targetRaceDate: nil
    )
}

struct AdaptiveInsights {
    let adherenceRate: Double           // 0-1+ (can exceed 1 if over-training)
    let spikeWarnings: [String]         // Injury risk warnings
    let recommendations: [String]       // Actionable recommendations
    let planAdjustments: [String]       // Explanations of plan changes

    var adherencePercentage: Int {
        Int(adherenceRate * 100)
    }

    var adherenceStatus: String {
        if adherenceRate >= 0.9 && adherenceRate <= 1.1 {
            return "On Track"
        } else if adherenceRate < 0.7 {
            return "Below Target"
        } else if adherenceRate > 1.2 {
            return "Exceeding Plan"
        } else {
            return "Close to Target"
        }
    }

    var hasWarnings: Bool {
        !spikeWarnings.isEmpty
    }
}
