//
//  TrainingPlanService.swift
//  Runaway iOS
//
//  Service for generating and managing weekly training plans
//  Includes rest day awareness for adaptive planning
//

import Foundation

class TrainingPlanService {

    // MARK: - Rest Day Integration

    /// Check if today should be a rest day based on recovery status
    static func shouldTakeRestDay(athleteId: Int) async -> (shouldRest: Bool, reason: String) {
        do {
            let restDayService = await RestDayService.shared
            let recoveryStatus = try await restDayService.calculateRecoveryStatus(athleteId: athleteId)
            let daysSinceRest = try await restDayService.getDaysSinceLastRest(athleteId: athleteId)

            switch recoveryStatus {
            case .overdue:
                return (true, "You haven't had a rest day in \(daysSinceRest) days. Rest is strongly recommended.")
            case .needsRest:
                return (true, "Recovery indicators suggest you need a rest day today.")
            case .adequate:
                if daysSinceRest >= 5 {
                    return (true, "Consider taking a rest day - it's been \(daysSinceRest) days since your last one.")
                }
                return (false, "Recovery is adequate. You can train today, but listen to your body.")
            case .wellRested, .fullyRecovered:
                return (false, "You're well rested and ready to train!")
            }
        } catch {
            #if DEBUG
            print("📋 TrainingPlan: Failed to check rest day status: \(error)")
            #endif
            return (false, "Unable to determine recovery status.")
        }
    }

    /// Get today's recommendation considering rest days
    static func getTodaysRecommendation(
        athleteId: Int,
        currentPlan: WeeklyTrainingPlan?
    ) async -> String {
        let (shouldRest, restReason) = await shouldTakeRestDay(athleteId: athleteId)

        if shouldRest {
            return restReason
        }

        // If not a rest day, check what's planned
        if let plan = currentPlan {
            let today = DayOfWeek.from(date: Date())
            if let workout = plan.workout(for: today) {
                return "Today's planned workout: \(workout.title). \(workout.description)"
            }
        }

        return "No workout planned for today. Consider an easy run or active recovery."
    }

    // MARK: - Cache Keys
    private static let cacheKey = "cached_weekly_training_plan"
    private static let cacheExpirationKey = "weekly_plan_cache_expiration"

    // MARK: - Cache Management

    /// Save plan to local cache with expiration at next Sunday midnight
    static func cachePlan(_ plan: WeeklyTrainingPlan) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        if let encoded = try? encoder.encode(plan) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
            // Cache expires at next Sunday midnight
            let expiration = nextSundayMidnight()
            UserDefaults.standard.set(expiration.timeIntervalSince1970, forKey: cacheExpirationKey)

            #if DEBUG
            print("📋 TrainingPlan: Cached plan, expires \(expiration)")
            #endif
        }
    }

    /// Get cached plan if valid (not expired and for current week)
    static func getCachedPlan() -> WeeklyTrainingPlan? {
        // Check if cache has expired
        let expirationTimestamp = UserDefaults.standard.double(forKey: cacheExpirationKey)
        guard expirationTimestamp > 0 else { return nil }

        let expirationDate = Date(timeIntervalSince1970: expirationTimestamp)
        guard Date() < expirationDate else {
            #if DEBUG
            print("📋 TrainingPlan: Cache expired")
            #endif
            clearCache()
            return nil
        }

        // Load and decode cached plan
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let plan = try? decoder.decode(WeeklyTrainingPlan.self, from: data) else {
            clearCache()
            return nil
        }

        // Verify plan is for current week
        let currentSunday = currentWeekSunday()
        let calendar = Calendar.current
        if !calendar.isDate(plan.weekStartDate, inSameDayAs: currentSunday) {
            #if DEBUG
            print("📋 TrainingPlan: Cached plan is for different week")
            #endif
            clearCache()
            return nil
        }

        #if DEBUG
        print("📋 TrainingPlan: Loaded cached plan (expires \(expirationDate))")
        #endif

        return plan
    }

    /// Clear the cached plan
    static func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: cacheExpirationKey)
    }

    /// Calculate next Sunday at midnight (end of current week)
    private static func nextSundayMidnight() -> Date {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)

        // Days until next Sunday (weekday 1 = Sunday)
        let daysUntilSunday = weekday == 1 ? 7 : (8 - weekday)

        // Get next Sunday at start of day (midnight)
        let nextSunday = calendar.safeDate(byAdding: .day, value: daysUntilSunday, to: calendar.startOfDay(for: today))
        return nextSunday
    }

    // MARK: - Generate Weekly Plan

    /// Generate a training plan for the current or specified week
    static func generateWeeklyPlan(
        athleteId: Int,
        goal: RunningGoal?,
        weekStartDate: Date? = nil
    ) async throws -> WeeklyTrainingPlan {
        let startDate = weekStartDate ?? currentWeekSunday()
        let safePlan = generateLocalPlan(athleteId: athleteId, weekStartDate: startDate, goal: goal)
        let personalizedPlan = await personalizePlanLocally(safePlan)
        cachePlan(personalizedPlan)
        return personalizedPlan
    }

    // MARK: - Adaptive Plan Regeneration

    /// Regenerate the remaining days of the plan based on completed activities
    /// Called when activities are synced that differ significantly from the plan
    static func regeneratePlanWithActivities(
        athleteId: Int,
        currentPlan: WeeklyTrainingPlan,
        completedActivities: [Activity],
        goal: RunningGoal?
    ) async throws -> WeeklyTrainingPlan {
        _ = athleteId
        _ = goal
        let adjusted = adjustPlanLocally(
            currentPlan: currentPlan,
            completedActivities: completedActivities
        )
        cachePlan(adjusted)
        return adjusted
    }

    /// Check if plan regeneration is needed based on activity differences
    static func shouldRegeneratePlan(
        currentPlan: WeeklyTrainingPlan,
        newActivity: Activity
    ) -> Bool {
        guard let activityTimestamp = newActivity.activity_date ?? newActivity.start_date else {
            return false
        }

        let activityDate = Date(timeIntervalSince1970: activityTimestamp)

        // Only consider activities from the current week
        guard activityDate >= currentPlan.weekStartDate && activityDate <= currentPlan.weekEndDate else {
            return false
        }

        // Find planned workout for this day
        let dayOfWeek = DayOfWeek.from(date: activityDate)
        guard let plannedWorkout = currentPlan.workout(for: dayOfWeek) else {
            // No planned workout - might want to regenerate to add recovery
            let activityDistance = (newActivity.distance ?? 0) * 0.000621371
            return activityDistance > 3.0 // Regenerate if unplanned run > 3 miles
        }

        // Compare actual vs planned
        let actualDistanceMiles = (newActivity.distance ?? 0) * 0.000621371
        let plannedDistance = plannedWorkout.distance ?? 0

        // Regenerate if:
        // 1. Distance differs by more than 30%
        // 2. Did a hard workout when easy was planned (or vice versa)

        if plannedDistance > 0 {
            let distanceRatio = actualDistanceMiles / plannedDistance
            if distanceRatio < 0.7 || distanceRatio > 1.3 {
                #if DEBUG
                print("📋 TrainingPlan: Distance deviation detected (\(String(format: "%.1f", actualDistanceMiles)) vs \(String(format: "%.1f", plannedDistance)) mi)")
                #endif
                return true
            }
        }

        // Check workout type mismatch
        let activityType = newActivity.type?.lowercased() ?? ""
        let plannedType = plannedWorkout.workoutType

        // If planned was easy but actual was hard (based on pace or name)
        if plannedType == .easyRun || plannedType == .recoveryRun {
            if activityType.contains("tempo") || activityType.contains("interval") || activityType.contains("race") {
                #if DEBUG
                print("📋 TrainingPlan: Workout type mismatch (planned easy, did hard)")
                #endif
                return true
            }
        }

        return false
    }

    /// Merge original plan with regenerated plan
    private static func mergePlans(
        original: WeeklyTrainingPlan,
        regenerated: WeeklyTrainingPlan,
        completedActivities: [Activity]
    ) -> WeeklyTrainingPlan {
        let calendar = Calendar.current
        var mergedWorkouts: [DailyWorkout] = []

        for day in DayOfWeek.allCases {
            guard let dayDate = calendar.date(
                byAdding: .day,
                value: day.calendarWeekday - 1,
                to: original.weekStartDate
            ) else { continue }

            // Check if this day has a completed activity
            let hasCompletedActivity = completedActivities.contains { activity in
                guard let ts = activity.activity_date ?? activity.start_date else { return false }
                return calendar.isDate(Date(timeIntervalSince1970: ts), inSameDayAs: dayDate)
            }

            if hasCompletedActivity {
                // Keep original planned workout (will be shown as completed in UI)
                if let originalWorkout = original.workout(for: day) {
                    mergedWorkouts.append(originalWorkout)
                }
            } else {
                // Use regenerated workout for this day
                if let newWorkout = regenerated.workout(for: day) {
                    mergedWorkouts.append(newWorkout)
                } else if let originalWorkout = original.workout(for: day) {
                    // Fallback to original if regenerated doesn't have this day
                    mergedWorkouts.append(originalWorkout)
                }
            }
        }

        // Calculate new total mileage
        let totalMileage = mergedWorkouts.compactMap { $0.distance }.reduce(0, +)

        return WeeklyTrainingPlan(
            id: original.id,
            athleteId: original.athleteId,
            weekStartDate: original.weekStartDate,
            weekEndDate: original.weekEndDate,
            workouts: mergedWorkouts,
            weekNumber: original.weekNumber,
            totalMileage: totalMileage,
            focusArea: regenerated.focusArea ?? original.focusArea,
            notes: regenerated.notes ?? original.notes,
            generatedAt: Date(),
            goalId: original.goalId
        )
    }

    /// Local fallback: adjust plan based on simple heuristics
    private static func adjustPlanLocally(
        currentPlan: WeeklyTrainingPlan,
        completedActivities: [Activity]
    ) -> WeeklyTrainingPlan {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Calculate total actual load from completed activities this week
        var actualMileage: Double = 0
        var hardWorkoutDone = false

        for activity in completedActivities {
            guard let ts = activity.activity_date ?? activity.start_date else { continue }
            let activityDate = Date(timeIntervalSince1970: ts)
            guard activityDate >= currentPlan.weekStartDate && activityDate <= currentPlan.weekEndDate else { continue }

            let miles = (activity.distance ?? 0) * 0.000621371
            actualMileage += miles

            // Check if it was a hard effort
            if let speed = activity.average_speed, speed > 0 {
                let paceMinPerMile = (1609.34 / speed) / 60.0
                if paceMinPerMile < 8.0 {
                    hardWorkoutDone = true
                }
            }
        }

        // Adjust remaining workouts based on accumulated load
        var adjustedWorkouts: [DailyWorkout] = []

        for workout in currentPlan.workouts {
            // If workout is in the past or today is past, keep as-is
            if workout.date < today {
                adjustedWorkouts.append(workout)
                continue
            }

            var adjustedWorkout = workout

            // If we've done more than planned, reduce future intensity
            let plannedMileageSoFar = currentPlan.workouts
                .filter { $0.date < today }
                .compactMap { $0.distance }
                .reduce(0, +)

            let loadRatio = plannedMileageSoFar > 0 ? actualMileage / plannedMileageSoFar : 1.0

            if loadRatio > 1.3 {
                // Overloaded - convert hard workouts to easy
                if workout.workoutType == .tempoRun || workout.workoutType == .intervalRun {
                    adjustedWorkout = DailyWorkout(
                        id: workout.id,
                        date: workout.date,
                        dayOfWeek: workout.dayOfWeek,
                        workoutType: .recoveryRun,
                        title: "Recovery Run (Adjusted)",
                        description: "Adjusted to recovery due to higher training load earlier this week. Keep it easy!",
                        duration: workout.duration,
                        distance: (workout.distance ?? 4.0) * 0.6,
                        targetPace: "10:00-11:00/mi",
                        exercises: nil,
                        isCompleted: false,
                        completedActivityId: nil
                    )
                } else if workout.workoutType == .longRun {
                    // Reduce long run distance
                    adjustedWorkout = DailyWorkout(
                        id: workout.id,
                        date: workout.date,
                        dayOfWeek: workout.dayOfWeek,
                        workoutType: .easyRun,
                        title: "Easy Run (Adjusted)",
                        description: "Long run shortened due to higher training load. Focus on recovery.",
                        duration: (workout.duration ?? 60) / 2,
                        distance: (workout.distance ?? 8.0) * 0.5,
                        targetPace: "9:30-10:30/mi",
                        exercises: nil,
                        isCompleted: false,
                        completedActivityId: nil
                    )
                }
            } else if loadRatio < 0.7 && !hardWorkoutDone {
                // Underloaded - could suggest adding intensity (but be conservative)
                // Keep workout as-is but maybe add a note
            }

            adjustedWorkouts.append(adjustedWorkout)
        }

        let totalMileage = adjustedWorkouts.compactMap { $0.distance }.reduce(0, +)

        return WeeklyTrainingPlan(
            id: currentPlan.id,
            athleteId: currentPlan.athleteId,
            weekStartDate: currentPlan.weekStartDate,
            weekEndDate: currentPlan.weekEndDate,
            workouts: adjustedWorkouts,
            weekNumber: currentPlan.weekNumber,
            totalMileage: totalMileage,
            focusArea: currentPlan.focusArea,
            notes: "Plan adjusted based on your actual training load this week.",
            generatedAt: Date(),
            goalId: currentPlan.goalId
        )
    }

    /// Adjust plan based on rest day status
    /// If user needs rest, convert today's workout to a rest day
    static func adjustPlanForRestDays(
        currentPlan: WeeklyTrainingPlan,
        athleteId: Int
    ) async -> WeeklyTrainingPlan {
        let (shouldRest, reason) = await shouldTakeRestDay(athleteId: athleteId)

        guard shouldRest else {
            return currentPlan
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayDayOfWeek = DayOfWeek.from(date: today)

        var adjustedWorkouts: [DailyWorkout] = []

        for workout in currentPlan.workouts {
            if workout.dayOfWeek == todayDayOfWeek && workout.date >= today {
                // Convert today's workout to rest
                let restWorkout = DailyWorkout(
                    id: workout.id,
                    date: workout.date,
                    dayOfWeek: workout.dayOfWeek,
                    workoutType: .rest,
                    title: "Rest Day (Recovery)",
                    description: reason,
                    duration: nil,
                    distance: nil,
                    targetPace: nil,
                    exercises: nil,
                    isCompleted: false,
                    completedActivityId: nil
                )
                adjustedWorkouts.append(restWorkout)
            } else {
                adjustedWorkouts.append(workout)
            }
        }

        let totalMileage = adjustedWorkouts.compactMap { $0.distance }.reduce(0, +)

        return WeeklyTrainingPlan(
            id: currentPlan.id,
            athleteId: currentPlan.athleteId,
            weekStartDate: currentPlan.weekStartDate,
            weekEndDate: currentPlan.weekEndDate,
            workouts: adjustedWorkouts,
            weekNumber: currentPlan.weekNumber,
            totalMileage: totalMileage,
            focusArea: currentPlan.focusArea,
            notes: "Plan adjusted: \(reason)",
            generatedAt: Date(),
            goalId: currentPlan.goalId
        )
    }

    // MARK: - Get Existing Plan

    /// Fetch existing plan for a specific week
    static func getWeeklyPlan(athleteId: Int, weekStartDate: Date) async throws -> WeeklyTrainingPlan? {
        guard let plan = getCachedPlan(), plan.athleteId == athleteId else { return nil }
        return Calendar.current.isDate(plan.weekStartDate, inSameDayAs: weekStartDate) ? plan : nil
    }

    private static func personalizePlanLocally(_ plan: WeeklyTrainingPlan) async -> WeeklyTrainingPlan {
        let model = await FoundationModelsService.shared
        guard await model.isAvailable else { return plan }

        let schedule = plan.workouts.map { workout in
            let distance = workout.distance.map { String(format: "%.1f miles", $0) } ?? "no running distance"
            return "\(workout.dayOfWeek.rawValue): \(workout.title), \(distance)"
        }.joined(separator: "\n")

        do {
            let notes = try await model.generateResponse(
                prompt: "Write a concise weekly coaching note for this fixed, safety-checked schedule:\n\(schedule)",
                systemPrompt: "You are a grounded running coach. Explain the week's rhythm in 2-3 short sentences. Do not alter mileage, prescribe medical care, or invent athlete facts.",
                maxTokens: 256
            )
            return WeeklyTrainingPlan(
                id: plan.id,
                athleteId: plan.athleteId,
                weekStartDate: plan.weekStartDate,
                weekEndDate: plan.weekEndDate,
                workouts: plan.workouts,
                weekNumber: plan.weekNumber,
                totalMileage: plan.totalMileage,
                focusArea: plan.focusArea,
                notes: notes,
                generatedAt: plan.generatedAt,
                goalId: plan.goalId
            )
        } catch {
            return plan
        }
    }

    // MARK: - Local Plan Generation (Fallback)

    /// Generate a training plan locally when API is unavailable
    private static func generateLocalPlan(
        athleteId: Int,
        weekStartDate: Date,
        goal: RunningGoal?
    ) -> WeeklyTrainingPlan {
        let calendar = Calendar.current
        let weekEndDate = calendar.safeDate(byAdding: .day, value: 6, to: weekStartDate)

        var workouts: [DailyWorkout] = []

        // Sunday - Long Run
        workouts.append(createWorkout(
            date: weekStartDate,
            dayOfWeek: .sunday,
            type: .longRun,
            title: "Long Run",
            description: "Build your aerobic base with a comfortable long run. Keep the pace conversational.",
            distance: 8.0,
            duration: 70,
            targetPace: "9:00-10:00/mi"
        ))

        // Monday - Upper Body Strength
        workouts.append(createWorkout(
            date: calendar.safeDate(byAdding: .day, value: 1, to: weekStartDate),
            dayOfWeek: .monday,
            type: .upperBody,
            title: "Upper Body Strength",
            description: "Focus on pushing and pulling movements to build upper body strength.",
            duration: 45,
            exercises: [
                Exercise(name: "Bench Press", sets: 4, reps: "8-10"),
                Exercise(name: "Bent Over Rows", sets: 4, reps: "8-10"),
                Exercise(name: "Overhead Press", sets: 3, reps: "10-12"),
                Exercise(name: "Lat Pulldowns", sets: 3, reps: "10-12"),
                Exercise(name: "Face Pulls", sets: 3, reps: "15"),
                Exercise(name: "Bicep Curls", sets: 3, reps: "12"),
                Exercise(name: "Tricep Pushdowns", sets: 3, reps: "12")
            ]
        ))

        // Tuesday - Easy Run
        workouts.append(createWorkout(
            date: calendar.safeDate(byAdding: .day, value: 2, to: weekStartDate),
            dayOfWeek: .tuesday,
            type: .easyRun,
            title: "Easy Run",
            description: "Recover from your long run with an easy effort. Stay in zone 2.",
            distance: 4.0,
            duration: 35,
            targetPace: "9:30-10:30/mi"
        ))

        // Wednesday - Lower Body Strength
        workouts.append(createWorkout(
            date: calendar.safeDate(byAdding: .day, value: 3, to: weekStartDate),
            dayOfWeek: .wednesday,
            type: .lowerBody,
            title: "Lower Body Strength",
            description: "Build leg strength to improve running power and prevent injuries.",
            duration: 50,
            exercises: [
                Exercise(name: "Barbell Squats", sets: 4, reps: "6-8"),
                Exercise(name: "Romanian Deadlifts", sets: 4, reps: "8-10"),
                Exercise(name: "Walking Lunges", sets: 3, reps: "12 each leg"),
                Exercise(name: "Leg Press", sets: 3, reps: "10-12"),
                Exercise(name: "Calf Raises", sets: 4, reps: "15"),
                Exercise(name: "Leg Curls", sets: 3, reps: "12")
            ]
        ))

        // Thursday - Tempo Run
        workouts.append(createWorkout(
            date: calendar.safeDate(byAdding: .day, value: 4, to: weekStartDate),
            dayOfWeek: .thursday,
            type: .tempoRun,
            title: "Tempo Run",
            description: "Comfortably hard effort. Warm up 1 mile, tempo 3 miles, cool down 1 mile.",
            distance: 5.0,
            duration: 40,
            targetPace: "7:30-8:00/mi tempo"
        ))

        // Friday - Yoga & Mobility
        workouts.append(createWorkout(
            date: calendar.safeDate(byAdding: .day, value: 5, to: weekStartDate),
            dayOfWeek: .friday,
            type: .yoga,
            title: "Yoga & Mobility",
            description: "Active recovery with yoga flow. Focus on hip openers and hamstring stretches.",
            duration: 45
        ))

        // Saturday - Easy Run + Core
        workouts.append(createWorkout(
            date: calendar.safeDate(byAdding: .day, value: 6, to: weekStartDate),
            dayOfWeek: .saturday,
            type: .easyRun,
            title: "Easy Run + Core",
            description: "Short easy run followed by core work. Prepare for tomorrow's long run.",
            distance: 3.0,
            duration: 50,
            targetPace: "9:30-10:30/mi",
            exercises: [
                Exercise(name: "Plank", sets: 3, reps: "45 sec"),
                Exercise(name: "Dead Bug", sets: 3, reps: "10 each side"),
                Exercise(name: "Bird Dog", sets: 3, reps: "10 each side"),
                Exercise(name: "Russian Twists", sets: 3, reps: "20"),
                Exercise(name: "Glute Bridges", sets: 3, reps: "15")
            ]
        ))

        // Calculate total mileage
        let totalMileage = workouts.compactMap { $0.distance }.reduce(0, +)

        return WeeklyTrainingPlan(
            id: UUID().uuidString,
            athleteId: athleteId,
            weekStartDate: weekStartDate,
            weekEndDate: weekEndDate,
            workouts: workouts,
            weekNumber: nil,
            totalMileage: totalMileage,
            focusArea: "Base Building",
            notes: "Focus on building your aerobic base while maintaining strength. Keep easy runs truly easy!",
            generatedAt: Date(),
            goalId: goal?.id
        )
    }

    private static func createWorkout(
        date: Date,
        dayOfWeek: DayOfWeek,
        type: WorkoutType,
        title: String,
        description: String,
        distance: Double? = nil,
        duration: Int? = nil,
        targetPace: String? = nil,
        exercises: [Exercise]? = nil
    ) -> DailyWorkout {
        DailyWorkout(
            id: UUID().uuidString,
            date: date,
            dayOfWeek: dayOfWeek,
            workoutType: type,
            title: title,
            description: description,
            duration: duration,
            distance: distance,
            targetPace: targetPace,
            exercises: exercises,
            isCompleted: false,
            completedActivityId: nil
        )
    }

    // MARK: - Helpers

    /// Get the Sunday of the current week
    static func currentWeekSunday() -> Date {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        // weekday: 1 = Sunday, 2 = Monday, etc.
        let daysToSubtract = weekday - 1
        return calendar.safeDate(byAdding: .day, value: -daysToSubtract, to: calendar.startOfDay(for: today))
    }

    /// Get dates for all days in the current week (Sunday to Saturday)
    static func currentWeekDates() -> [Date] {
        let sunday = currentWeekSunday()
        let calendar = Calendar.current
        return (0..<7).map { calendar.safeDate(byAdding: .day, value: $0, to: sunday) }
    }
}

// MARK: - Errors

enum TrainingPlanError: LocalizedError {
    case invalidResponse
    case generationFailed(String)
    case httpError(Int)
    case noPlanFound

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .generationFailed(let message):
            return "Failed to generate plan: \(message)"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .noPlanFound:
            return "No training plan found for this week"
        }
    }
}
