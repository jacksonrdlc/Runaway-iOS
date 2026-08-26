import Foundation

enum TodayTrainingDirective: Equatable {
    case recover
    case reduceIntensity
    case proceed
    case unknown
}

struct TodayRecommendation: Equatable {
    let directive: TodayTrainingDirective
    let status: String
    let title: String
    let detail: String
    let systemImage: String
}

enum TodayWorkoutAdjustment: Equatable {
    case recoveryDay
    case easierWorkout
    case keepPlan
}

struct TodayWorkoutAdjustmentResult {
    let plan: WeeklyTrainingPlan
    let originalWorkout: DailyWorkout
    let updatedWorkout: DailyWorkout
    let receiptTitle: String
    let receiptDetail: String
}

enum TodayRecommendationPolicy {
    static func recommendation(readinessScore: Int?) -> TodayRecommendation {
        guard let readinessScore else {
            return TodayRecommendation(
                directive: .unknown,
                status: "Check In",
                title: "Check Your Readiness",
                detail: "Calculate readiness before choosing today's effort.",
                systemImage: "heart.text.square"
            )
        }

        switch readinessScore {
        case ..<50:
            return TodayRecommendation(
                directive: .recover,
                status: "Recovery",
                title: "Recovery Day",
                detail: "Your readiness is low. Rest or choose very light movement today.",
                systemImage: "moon.zzz.fill"
            )
        case 50..<70:
            return TodayRecommendation(
                directive: .reduceIntensity,
                status: "Adjusted",
                title: "Keep It Easy",
                detail: "Keep today's effort conversational and reduce intensity.",
                systemImage: "figure.walk"
            )
        default:
            return TodayRecommendation(
                directive: .proceed,
                status: "Ready",
                title: "Follow Today's Plan",
                detail: "Your readiness supports the planned training.",
                systemImage: "figure.run"
            )
        }
    }

    static func applying(
        _ adjustment: TodayWorkoutAdjustment,
        to plan: WeeklyTrainingPlan,
        on date: Date = Date(),
        readinessScore: Int?
    ) -> TodayWorkoutAdjustmentResult? {
        guard adjustment != .keepPlan else { return nil }

        let calendar = Calendar.current
        guard let workoutIndex = plan.workouts.firstIndex(where: {
            calendar.isDate($0.date, inSameDayAs: date)
        }) else { return nil }

        let original = plan.workouts[workoutIndex]
        guard original.workoutType != .rest else { return nil }

        let updated: DailyWorkout
        switch adjustment {
        case .recoveryDay:
            updated = DailyWorkout(
                id: original.id,
                date: original.date,
                dayOfWeek: original.dayOfWeek,
                workoutType: .rest,
                title: "Recovery Day (Adjusted)",
                description: "Adjusted for today's readiness. Rest, hydrate, and resume the plan when you feel recovered.",
                duration: nil,
                distance: nil,
                targetPace: nil,
                exercises: nil,
                isCompleted: original.isCompleted,
                completedActivityId: original.completedActivityId
            )
        case .easierWorkout:
            if original.workoutType.isRunning {
                updated = DailyWorkout(
                    id: original.id,
                    date: original.date,
                    dayOfWeek: original.dayOfWeek,
                    workoutType: .recoveryRun,
                    title: "Easy Run (Adjusted)",
                    description: "Adjusted for today's readiness. Keep the effort conversational and stop if recovery feels incomplete.",
                    duration: original.duration.map { max(15, Int((Double($0) * 0.75).rounded())) },
                    distance: original.distance.map { $0 * 0.65 },
                    targetPace: "Conversational effort",
                    exercises: nil,
                    isCompleted: original.isCompleted,
                    completedActivityId: original.completedActivityId
                )
            } else {
                updated = DailyWorkout(
                    id: original.id,
                    date: original.date,
                    dayOfWeek: original.dayOfWeek,
                    workoutType: .stretchMobility,
                    title: "Mobility (Adjusted)",
                    description: "Adjusted for today's readiness. Replace the planned session with gentle mobility and recovery work.",
                    duration: original.duration.map { max(15, Int((Double($0) * 0.6).rounded())) } ?? 20,
                    distance: nil,
                    targetPace: nil,
                    exercises: nil,
                    isCompleted: original.isCompleted,
                    completedActivityId: original.completedActivityId
                )
            }
        case .keepPlan:
            return nil
        }

        var workouts = plan.workouts
        workouts[workoutIndex] = updated
        let updatedPlan = WeeklyTrainingPlan(
            id: plan.id,
            athleteId: plan.athleteId,
            weekStartDate: plan.weekStartDate,
            weekEndDate: plan.weekEndDate,
            workouts: workouts,
            weekNumber: plan.weekNumber,
            totalMileage: workouts.compactMap(\.distance).reduce(0, +),
            focusArea: plan.focusArea,
            notes: plan.notes,
            generatedAt: Date(),
            goalId: plan.goalId
        )

        let scoreContext = readinessScore.map { "Readiness was \($0), so " } ?? "Based on today's readiness, "
        let changeDescription: String
        if adjustment == .recoveryDay {
            changeDescription = "\(original.title) was replaced with recovery."
        } else if let oldDistance = original.distance, let newDistance = updated.distance {
            changeDescription = "\(original.title) changed from \(String(format: "%.1f", oldDistance)) to \(String(format: "%.1f", newDistance)) mi at an easy effort."
        } else {
            changeDescription = "\(original.title) was replaced with \(updated.title.lowercased())."
        }

        return TodayWorkoutAdjustmentResult(
            plan: updatedPlan,
            originalWorkout: original,
            updatedWorkout: updated,
            receiptTitle: adjustment == .recoveryDay ? "Recovery added" : "Today's effort reduced",
            receiptDetail: scoreContext + changeDescription.prefix(1).lowercased() + changeDescription.dropFirst()
        )
    }
}
