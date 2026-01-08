//
//  PlanViewModel.swift
//  Runaway iOS
//
//  ViewModel for the Plan tab - manages dynamic training plans
//

import Foundation
import SwiftUI

@MainActor
class PlanViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var currentPlan: WeeklyTrainingPlan?
    @Published var displayedPlan: WeeklyTrainingPlan?
    @Published var isLoading = false
    @Published var isGenerating = false
    @Published var adaptiveInsights: AdaptiveInsights?
    @Published var selectedWeekOffset: Int = 0
    @Published var error: Error?
    @Published var consecutiveBuildWeeks: Int = 0
    @Published var trainingBaseline: TrainingBaseline?

    // MARK: - Dependencies

    private let dataManager: DataManager
    private let algorithmService: AdaptiveTrainingAlgorithm

    // MARK: - Computed Properties

    var todaysWorkout: DailyWorkout? {
        guard let plan = currentPlan, plan.isCurrentWeek else { return nil }
        let today = DayOfWeek.from(date: Date())
        return plan.workout(for: today)
    }

    var todaysActivity: Activity? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return dataManager.activities.first { activity in
            guard let ts = activity.activity_date ?? activity.start_date else { return false }
            let activityDate = calendar.startOfDay(for: Date(timeIntervalSince1970: ts))
            return calendar.isDate(activityDate, inSameDayAs: today)
        }
    }

    var hasPlan: Bool {
        currentPlan != nil
    }

    var weekProgress: (completed: Int, total: Int) {
        guard let plan = currentPlan else { return (0, 0) }
        let entries = plan.mergedWithActivities(dataManager.activities)
        let completed = entries.filter { $0.isCompleted }.count
        let total = plan.workouts.filter { $0.workoutType != .rest }.count
        return (completed, total)
    }

    var weekMileageProgress: (actual: Double, planned: Double) {
        guard let plan = currentPlan else { return (0, 0) }
        let stats = plan.weekStats(with: dataManager.activities)
        return (stats.actualMiles, stats.plannedMiles)
    }

    // MARK: - Initialization

    init(dataManager: DataManager = .shared) {
        self.dataManager = dataManager
        self.algorithmService = AdaptiveTrainingAlgorithm(dataManager: dataManager)
    }

    // MARK: - Public Methods

    func loadPlan() async {
        isLoading = true
        defer { isLoading = false }

        // Always calculate baseline for transparency
        trainingBaseline = algorithmService.calculateTrainingBaseline(activities: dataManager.activities)

        // Check DataManager's cached plan first
        if let cached = dataManager.currentWeeklyPlan {
            currentPlan = cached
            displayedPlan = cached
            await loadAdaptiveInsights()
            return
        }

        // Try to load from service cache
        if let cached = TrainingPlanService.getCachedPlan() {
            currentPlan = cached
            displayedPlan = cached
            dataManager.currentWeeklyPlan = cached
            await loadAdaptiveInsights()
            return
        }

        // No plan exists - user will need to generate one
        currentPlan = nil
        displayedPlan = nil
    }

    func generatePlan() async {
        guard let userId = UserSession.shared.userId else {
            #if DEBUG
            print("❌ PlanViewModel: No user ID available")
            #endif
            return
        }

        isGenerating = true
        defer { isGenerating = false }

        let settings = PlanGenerationSettings(
            preferredRunDays: [.sunday, .tuesday, .wednesday, .thursday, .saturday],
            consecutiveBuildWeeks: consecutiveBuildWeeks,
            includeStrength: false,
            targetRaceDate: dataManager.currentGoal?.deadline
        )

        let plan = await algorithmService.generateAdaptivePlan(
            athleteId: userId,
            goal: dataManager.currentGoal,
            settings: settings
        )

        currentPlan = plan
        displayedPlan = plan
        dataManager.currentWeeklyPlan = plan
        TrainingPlanService.cachePlan(plan)

        // Calculate and store baseline for transparency
        let baseline = algorithmService.calculateTrainingBaseline(activities: dataManager.activities)
        trainingBaseline = baseline
        let weekType = algorithmService.determineWeekType(
            recentWeeks: baseline.weeklyMileages,
            consecutiveBuildWeeks: consecutiveBuildWeeks
        )

        if weekType == .stepBack {
            consecutiveBuildWeeks = 0
        } else {
            consecutiveBuildWeeks += 1
        }

        await loadAdaptiveInsights()

        #if DEBUG
        print("✅ PlanViewModel: Generated plan with \(plan.workouts.count) workouts, \(String(format: "%.1f", plan.totalMileage)) miles")
        #endif
    }

    func regeneratePlan() async {
        guard let plan = currentPlan else {
            await generatePlan()
            return
        }

        isGenerating = true
        defer { isGenerating = false }

        // Get this week's activities
        let weekActivities = getWeekActivities(for: plan)

        // Use the existing service regeneration if available
        await dataManager.regenerateWeeklyPlan(currentPlan: plan, activities: weekActivities)

        if let newPlan = dataManager.currentWeeklyPlan {
            currentPlan = newPlan
            displayedPlan = newPlan
        } else {
            // Fallback to generating a new plan
            await generatePlan()
        }

        await loadAdaptiveInsights()
    }

    func selectWeek(offset: Int) {
        selectedWeekOffset = offset
        // For now, we only show current week
        // Future: support viewing past/future weeks
        displayedPlan = currentPlan
    }

    func refresh() async {
        await loadPlan()
    }

    // MARK: - Private Methods

    private func loadAdaptiveInsights() async {
        guard let plan = currentPlan else {
            adaptiveInsights = nil
            return
        }

        adaptiveInsights = algorithmService.analyzeAdaptations(
            plan: plan,
            activities: dataManager.activities
        )
    }

    private func getWeekActivities(for plan: WeeklyTrainingPlan) -> [Activity] {
        return dataManager.activities.filter { activity in
            guard let ts = activity.activity_date ?? activity.start_date else { return false }
            let activityDate = Date(timeIntervalSince1970: ts)
            return activityDate >= plan.weekStartDate && activityDate <= plan.weekEndDate
        }
    }
}
