import Foundation
import Testing
@testable import Runaway_iOS

struct TodayRecommendationPolicyTests {
    @Test func poorReadinessRecommendsRecovery() {
        let recommendation = TodayRecommendationPolicy.recommendation(readinessScore: 29)

        #expect(recommendation.directive == .recover)
        #expect(recommendation.status == "Recovery")
        #expect(recommendation.title == "Recovery Day")
    }

    @Test func lowReadinessRecommendsRecovery() {
        let recommendation = TodayRecommendationPolicy.recommendation(readinessScore: 30)

        #expect(recommendation.directive == .recover)
    }

    @Test func moderateReadinessReducesIntensity() {
        let recommendation = TodayRecommendationPolicy.recommendation(readinessScore: 50)

        #expect(recommendation.directive == .reduceIntensity)
        #expect(recommendation.status == "Adjusted")
    }

    @Test func goodReadinessPreservesThePlan() {
        let recommendation = TodayRecommendationPolicy.recommendation(readinessScore: 70)

        #expect(recommendation.directive == .proceed)
    }

    @Test func missingReadinessDoesNotInventRecoveryAdvice() {
        let recommendation = TodayRecommendationPolicy.recommendation(readinessScore: nil)

        #expect(recommendation.directive == .unknown)
        #expect(recommendation.status == "Check In")
    }

    @Test func recoveryChoiceOnlyReplacesTargetDayAndRecalculatesMileage() throws {
        let fixture = makePlan()
        let result = try #require(TodayRecommendationPolicy.applying(
            .recoveryDay,
            to: fixture.plan,
            on: fixture.today,
            readinessScore: 42
        ))

        #expect(result.updatedWorkout.workoutType == WorkoutType.rest)
        #expect(result.updatedWorkout.distance == nil)
        #expect(result.plan.workouts[1].id == "tomorrow")
        #expect(result.plan.workouts[1].distance == 4)
        #expect(result.plan.totalMileage == 4)
        #expect(result.receiptDetail.contains("42"))
    }

    @Test func easierChoiceReducesDistanceAndRemovesIntensity() throws {
        let fixture = makePlan()
        let result = try #require(TodayRecommendationPolicy.applying(
            .easierWorkout,
            to: fixture.plan,
            on: fixture.today,
            readinessScore: 58
        ))

        #expect(result.updatedWorkout.workoutType == WorkoutType.recoveryRun)
        #expect(abs((result.updatedWorkout.distance ?? 0) - 3.9) < 0.001)
        #expect(result.updatedWorkout.duration == 34)
        #expect(result.updatedWorkout.targetPace == "Conversational effort")
        #expect(abs(result.plan.totalMileage - 7.9) < 0.001)
    }

    @Test func keepingPlanDoesNotCreateAnAdjustment() {
        let fixture = makePlan()
        let result = TodayRecommendationPolicy.applying(
            .keepPlan,
            to: fixture.plan,
            on: fixture.today,
            readinessScore: 40
        )

        #expect(result == nil)
    }

    private func makePlan() -> (plan: WeeklyTrainingPlan, today: Date) {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.date(from: DateComponents(year: 2026, month: 8, day: 26))!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let workouts = [
            DailyWorkout(
                id: "today",
                date: today,
                dayOfWeek: .wednesday,
                workoutType: .tempoRun,
                title: "Tempo Run",
                description: "Planned quality session",
                duration: 45,
                distance: 6,
                targetPace: "8:00/mi",
                exercises: nil,
                isCompleted: false,
                completedActivityId: nil
            ),
            DailyWorkout(
                id: "tomorrow",
                date: tomorrow,
                dayOfWeek: .thursday,
                workoutType: .easyRun,
                title: "Easy Run",
                description: "Easy miles",
                duration: 36,
                distance: 4,
                targetPace: "10:00/mi",
                exercises: nil,
                isCompleted: false,
                completedActivityId: nil
            )
        ]
        return (
            WeeklyTrainingPlan(
                id: "week",
                athleteId: 1,
                weekStartDate: today,
                weekEndDate: tomorrow,
                workouts: workouts,
                weekNumber: 1,
                totalMileage: 10,
                focusArea: "Base",
                notes: nil,
                generatedAt: today,
                goalId: nil
            ),
            today
        )
    }
}
