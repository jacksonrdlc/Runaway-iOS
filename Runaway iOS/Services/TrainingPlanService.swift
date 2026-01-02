//
//  TrainingPlanService.swift
//  Runaway iOS
//
//  Service for generating and managing weekly training plans
//  Includes rest day awareness for adaptive planning
//

import Foundation

class TrainingPlanService {

    // MARK: - Supabase Edge Function URL
    private static let baseURL = "https://nkxvjcdxiyjbndjvfmqy.supabase.co"

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
                return "Today's planned workout: \(workout.title). \(workout.description ?? "")"
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
        let nextSunday = calendar.date(byAdding: .day, value: daysUntilSunday, to: calendar.startOfDay(for: today))!
        return nextSunday
    }

    // MARK: - Generate Weekly Plan

    /// Generate a training plan for the current or specified week
    static func generateWeeklyPlan(
        athleteId: Int,
        goal: RunningGoal?,
        weekStartDate: Date? = nil
    ) async throws -> WeeklyTrainingPlan {

        // Calculate week start (Sunday) if not provided
        let startDate = weekStartDate ?? currentWeekSunday()

        #if DEBUG
        print("📋 TrainingPlan Generation Request:")
        print("   Athlete ID: \(athleteId)")
        print("   Week Start: \(startDate)")
        if let goal = goal {
            print("   Goal: \(goal.title) - \(goal.formattedTarget())")
        }
        #endif

        let url = URL(string: "\(baseURL)/functions/v1/generate-training-plan")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60.0
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add JWT authentication
        if let session = try? await supabase.auth.session {
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        }

        // Build request body
        var requestBody: [String: Any] = [
            "athlete_id": athleteId,
            "week_start_date": ISO8601DateFormatter().string(from: startDate)
        ]

        if let goal = goal {
            requestBody["goal"] = [
                "id": goal.id as Any,
                "type": goal.type.rawValue,
                "target_value": goal.targetValue,
                "deadline": ISO8601DateFormatter().string(from: goal.deadline),
                "title": goal.title,
                "weeks_remaining": goal.weeksRemaining
            ]
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw TrainingPlanError.invalidResponse
            }

            #if DEBUG
            print("   Response Code: \(httpResponse.statusCode)")
            #endif

            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let apiResponse = try decoder.decode(TrainingPlanAPIResponse.self, from: data)

                if let plan = apiResponse.plan {
                    #if DEBUG
                    print("   ✅ Plan generated with \(plan.workouts.count) workouts")
                    #endif
                    return plan
                } else {
                    throw TrainingPlanError.generationFailed(apiResponse.error ?? "Unknown error")
                }
            } else {
                // Fall back to local generation
                #if DEBUG
                print("   ⚠️ API unavailable, using local generation")
                #endif
                return generateLocalPlan(athleteId: athleteId, weekStartDate: startDate, goal: goal)
            }
        } catch let error as TrainingPlanError {
            throw error
        } catch {
            // Fall back to local generation on network errors
            #if DEBUG
            print("   ⚠️ Network error, using local generation: \(error)")
            #endif
            return generateLocalPlan(athleteId: athleteId, weekStartDate: startDate, goal: goal)
        }
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
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Build activity summaries for completed days
        var completedDays: [[String: Any]] = []
        for activity in completedActivities {
            guard let activityTimestamp = activity.activity_date ?? activity.start_date else { continue }
            let activityDate = Date(timeIntervalSince1970: activityTimestamp)

            // Only include activities from this week
            guard activityDate >= currentPlan.weekStartDate && activityDate <= currentPlan.weekEndDate else { continue }

            let dayOfWeek = DayOfWeek.from(date: activityDate)
            let distanceMiles = (activity.distance ?? 0) * 0.000621371
            let durationMinutes = Int((activity.elapsed_time ?? 0) / 60)

            // Calculate pace
            var paceString = "N/A"
            if let speed = activity.average_speed, speed > 0 {
                let minutesPerMile = (1609.34 / speed) / 60.0
                let minutes = Int(minutesPerMile)
                let seconds = Int((minutesPerMile - Double(minutes)) * 60)
                paceString = String(format: "%d:%02d/mi", minutes, seconds)
            }

            // Find what was originally planned for this day
            let plannedWorkout = currentPlan.workout(for: dayOfWeek)

            completedDays.append([
                "day": dayOfWeek.rawValue,
                "date": ISO8601DateFormatter().string(from: activityDate),
                "actual": [
                    "name": activity.name ?? "Run",
                    "type": activity.type ?? "Run",
                    "distance_miles": distanceMiles,
                    "duration_minutes": durationMinutes,
                    "pace": paceString,
                    "elevation_gain_ft": (activity.elevation_gain ?? 0) * 3.28084,
                    "average_hr": activity.average_heart_rate as Any
                ],
                "planned": plannedWorkout.map { [
                    "type": $0.workoutType.rawValue,
                    "title": $0.title,
                    "distance_miles": $0.distance as Any,
                    "duration_minutes": $0.duration as Any
                ] } as Any
            ])
        }

        // Determine which days still need planning (today and future)
        var remainingDays: [String] = []
        for day in DayOfWeek.allCases {
            guard let dayDate = calendar.date(
                byAdding: .day,
                value: day.calendarWeekday - 1,
                to: currentPlan.weekStartDate
            ) else { continue }

            // Include today and future days that don't have a completed activity
            if dayDate >= today {
                let hasActivity = completedActivities.contains { activity in
                    guard let ts = activity.activity_date ?? activity.start_date else { return false }
                    return calendar.isDate(Date(timeIntervalSince1970: ts), inSameDayAs: dayDate)
                }
                if !hasActivity {
                    remainingDays.append(day.rawValue)
                }
            }
        }

        // If no remaining days need planning, return current plan
        if remainingDays.isEmpty {
            #if DEBUG
            print("📋 TrainingPlan: No remaining days to regenerate")
            #endif
            return currentPlan
        }

        #if DEBUG
        print("📋 TrainingPlan Regeneration Request:")
        print("   Athlete ID: \(athleteId)")
        print("   Completed days: \(completedDays.count)")
        print("   Remaining days: \(remainingDays)")
        #endif

        let url = URL(string: "\(baseURL)/functions/v1/regenerate-training-plan")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60.0
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let session = try? await supabase.auth.session {
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        }

        // Build request body with activity context
        var requestBody: [String: Any] = [
            "athlete_id": athleteId,
            "week_start_date": ISO8601DateFormatter().string(from: currentPlan.weekStartDate),
            "completed_days": completedDays,
            "remaining_days": remainingDays,
            "original_plan": [
                "total_mileage": currentPlan.totalMileage,
                "focus_area": currentPlan.focusArea as Any,
                "notes": currentPlan.notes as Any
            ]
        ]

        if let goal = goal {
            requestBody["goal"] = [
                "id": goal.id as Any,
                "type": goal.type.rawValue,
                "target_value": goal.targetValue,
                "deadline": ISO8601DateFormatter().string(from: goal.deadline),
                "title": goal.title,
                "weeks_remaining": goal.weeksRemaining
            ]
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw TrainingPlanError.invalidResponse
            }

            #if DEBUG
            print("   Response Code: \(httpResponse.statusCode)")
            #endif

            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let apiResponse = try decoder.decode(TrainingPlanAPIResponse.self, from: data)

                if let newPlan = apiResponse.plan {
                    #if DEBUG
                    print("   ✅ Plan regenerated with \(newPlan.workouts.count) workouts")
                    #endif

                    // Merge: keep completed days from current plan, use new workouts for remaining days
                    let mergedPlan = mergePlans(original: currentPlan, regenerated: newPlan, completedActivities: completedActivities)
                    cachePlan(mergedPlan)
                    return mergedPlan
                } else {
                    throw TrainingPlanError.generationFailed(apiResponse.error ?? "Unknown error")
                }
            } else {
                // Fall back to local adjustment
                #if DEBUG
                print("   ⚠️ API unavailable, using local adjustment")
                #endif
                return adjustPlanLocally(currentPlan: currentPlan, completedActivities: completedActivities)
            }
        } catch let error as TrainingPlanError {
            throw error
        } catch {
            #if DEBUG
            print("   ⚠️ Network error, using local adjustment: \(error)")
            #endif
            return adjustPlanLocally(currentPlan: currentPlan, completedActivities: completedActivities)
        }
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
        let calendar = Calendar.current

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
        let dateString = ISO8601DateFormatter().string(from: weekStartDate)
        let url = URL(string: "\(baseURL)/functions/v1/training-plan?athlete_id=\(athleteId)&week_start_date=\(dateString)")!

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let session = try? await supabase.auth.session {
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TrainingPlanError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let apiResponse = try decoder.decode(TrainingPlanAPIResponse.self, from: data)
            return apiResponse.plan
        } else if httpResponse.statusCode == 404 {
            return nil
        } else {
            throw TrainingPlanError.httpError(httpResponse.statusCode)
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
        let weekEndDate = calendar.date(byAdding: .day, value: 6, to: weekStartDate)!

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
            date: calendar.date(byAdding: .day, value: 1, to: weekStartDate)!,
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
            date: calendar.date(byAdding: .day, value: 2, to: weekStartDate)!,
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
            date: calendar.date(byAdding: .day, value: 3, to: weekStartDate)!,
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
            date: calendar.date(byAdding: .day, value: 4, to: weekStartDate)!,
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
            date: calendar.date(byAdding: .day, value: 5, to: weekStartDate)!,
            dayOfWeek: .friday,
            type: .yoga,
            title: "Yoga & Mobility",
            description: "Active recovery with yoga flow. Focus on hip openers and hamstring stretches.",
            duration: 45
        ))

        // Saturday - Easy Run + Core
        workouts.append(createWorkout(
            date: calendar.date(byAdding: .day, value: 6, to: weekStartDate)!,
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
        return calendar.date(byAdding: .day, value: -daysToSubtract, to: calendar.startOfDay(for: today))!
    }

    /// Get dates for all days in the current week (Sunday to Saturday)
    static func currentWeekDates() -> [Date] {
        let sunday = currentWeekSunday()
        let calendar = Calendar.current
        return (0..<7).map { calendar.date(byAdding: .day, value: $0, to: sunday)! }
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
