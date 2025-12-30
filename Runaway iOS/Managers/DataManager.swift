//
//  DataManager.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 9/14/25.
//  Refactored to coordinate focused stores on 12/23/25.
//

import Foundation
import SwiftUI
import WidgetKit

// MARK: - Centralized Data Manager
// Acts as a facade/coordinator for focused stores while maintaining backward compatibility

@MainActor
class DataManager: ObservableObject {

    // MARK: - Focused Stores

    private let activityStore: ActivityStore
    private let athleteStore: AthleteStore
    private let commitmentManager: CommitmentManager
    private let goalManager: GoalManager
    private let widgetSyncService: WidgetSyncService

    // MARK: - Published Properties (Forwarded from stores for backward compatibility)

    @Published var activities: [Activity] = []
    @Published var athlete: Athlete?
    @Published var stats: AthleteStats?
    @Published var currentGoal: RunningGoal?
    @Published var todaysCommitment: DailyCommitment?
    @Published var currentWeeklyPlan: WeeklyTrainingPlan?
    @Published var isLoadingActivities = false
    @Published var isLoadingAthlete = false
    @Published var isLoadingCommitment = false
    @Published var isRegeneratingPlan = false
    @Published var lastDataRefresh: Date?

    // MARK: - Singleton

    static let shared = DataManager()

    // MARK: - Initialization

    private init(
        activityStore: ActivityStore = .shared,
        athleteStore: AthleteStore = .shared,
        commitmentManager: CommitmentManager = .shared,
        goalManager: GoalManager = .shared,
        widgetSyncService: WidgetSyncService = .shared
    ) {
        self.activityStore = activityStore
        self.athleteStore = athleteStore
        self.commitmentManager = commitmentManager
        self.goalManager = goalManager
        self.widgetSyncService = widgetSyncService

        setupStoreBindings()
    }

    // MARK: - Store Bindings

    private func setupStoreBindings() {
        // Bind ActivityStore changes
        activityStore.onActivitiesChanged = { [weak self] activities in
            Task { @MainActor in
                self?.activities = activities
                // Use database-based widget update for accurate yearly/monthly stats
                self?.updateWidgetData()
            }
        }

        activityStore.onNewActivityAdded = { [weak self] activity in
            Task { @MainActor in
                await self?.handleNewActivity(activity)
            }
        }
    }

    private func handleNewActivity(_ activity: Activity) async {
        // Check if from today before checking commitment
        let today = Calendar.current.startOfDay(for: Date())
        let activityDate = activity.activity_date ?? activity.start_date
        let isFromToday = activityDate.map {
            Calendar.current.isDate(Date(timeIntervalSince1970: $0), inSameDayAs: today)
        } ?? false

        if isFromToday {
            await commitmentManager.checkActivityFulfillsCommitment(activity)
        }
    }

    // MARK: - Data Loading Methods

    func loadAllData(for userId: Int) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadActivities(for: userId) }
            group.addTask { await self.loadAthlete(for: userId) }
            group.addTask { await self.loadStats(for: userId) }
            group.addTask { await self.loadCurrentGoal(for: userId) }
            group.addTask { await self.loadTodaysCommitment(for: userId) }
        }

        syncFromStores()
        updateWidgetData()
        lastDataRefresh = Date()
    }

    func loadActivities(for userId: Int) async {
        isLoadingActivities = true
        defer { isLoadingActivities = false }

        widgetSyncService.startBackgroundTask()
        defer { widgetSyncService.endBackgroundTask() }

        await activityStore.loadActivities(for: userId)
        activities = activityStore.activities
        updateWidgetData()
    }

    func loadAthlete(for userId: Int) async {
        isLoadingAthlete = true
        defer { isLoadingAthlete = false }

        await athleteStore.loadAthlete(for: userId)
        athlete = athleteStore.athlete
    }

    func loadStats(for userId: Int) async {
        await athleteStore.loadStats(for: userId)
        stats = athleteStore.stats
    }

    func loadCurrentGoal(for userId: Int) async {
        await goalManager.loadCurrentGoal(for: userId)
        currentGoal = goalManager.currentGoal
    }

    func loadTodaysCommitment(for userId: Int) async {
        isLoadingCommitment = true
        defer { isLoadingCommitment = false }

        await commitmentManager.loadTodaysCommitment(for: userId)
        todaysCommitment = commitmentManager.todaysCommitment
    }

    // MARK: - Data Refresh Methods

    func refreshAllData() async {
        guard let userId = UserSession.shared.userId else {
            print("❌ DataManager: No user ID available for refresh")
            return
        }

        await loadAllData(for: userId)
    }

    func refreshActivities() async {
        guard let userId = UserSession.shared.userId else {
            print("❌ DataManager: No user ID available for activities refresh")
            return
        }

        print("🔄 DataManager: Refreshing activities...")
        await loadActivities(for: userId)
        print("✅ DataManager: Activities refreshed. Total: \(activities.count)")

        // Check if plan needs regeneration based on new activities
        await checkAndRegeneratePlanIfNeeded()
    }

    // MARK: - Adaptive Training Plan

    /// Load the current week's training plan
    func loadCurrentWeeklyPlan() async {
        guard let userId = UserSession.shared.userId else { return }

        // Check cache first
        if let cachedPlan = TrainingPlanService.getCachedPlan() {
            currentWeeklyPlan = cachedPlan
            return
        }

        // Try to fetch from server
        do {
            let sunday = TrainingPlanService.currentWeekSunday()
            if let plan = try await TrainingPlanService.getWeeklyPlan(athleteId: userId, weekStartDate: sunday) {
                currentWeeklyPlan = plan
                TrainingPlanService.cachePlan(plan)
            }
        } catch {
            #if DEBUG
            print("📋 DataManager: Could not load weekly plan: \(error)")
            #endif
        }
    }

    /// Check if any new activities require plan regeneration and regenerate if needed
    func checkAndRegeneratePlanIfNeeded() async {
        guard let plan = currentWeeklyPlan ?? TrainingPlanService.getCachedPlan() else {
            #if DEBUG
            print("📋 DataManager: No current plan to check for regeneration")
            #endif
            return
        }

        guard let userId = UserSession.shared.userId else { return }

        // Get activities from this week
        let calendar = Calendar.current
        let weekActivities = activities.filter { activity in
            guard let ts = activity.activity_date ?? activity.start_date else { return false }
            let activityDate = Date(timeIntervalSince1970: ts)
            return activityDate >= plan.weekStartDate && activityDate <= plan.weekEndDate
        }

        // Check if any activity warrants regeneration
        var needsRegeneration = false
        for activity in weekActivities {
            if TrainingPlanService.shouldRegeneratePlan(currentPlan: plan, newActivity: activity) {
                needsRegeneration = true
                break
            }
        }

        if needsRegeneration {
            #if DEBUG
            print("📋 DataManager: Triggering plan regeneration based on activity differences")
            #endif
            await regenerateWeeklyPlan(currentPlan: plan, activities: weekActivities)
        }
    }

    /// Regenerate the weekly plan based on completed activities
    func regenerateWeeklyPlan(currentPlan: WeeklyTrainingPlan, activities: [Activity]) async {
        guard let userId = UserSession.shared.userId else { return }

        isRegeneratingPlan = true
        defer { isRegeneratingPlan = false }

        do {
            let regeneratedPlan = try await TrainingPlanService.regeneratePlanWithActivities(
                athleteId: userId,
                currentPlan: currentPlan,
                completedActivities: activities,
                goal: currentGoal
            )

            currentWeeklyPlan = regeneratedPlan

            #if DEBUG
            print("📋 DataManager: Plan regenerated successfully")
            #endif
        } catch {
            #if DEBUG
            print("📋 DataManager: Plan regeneration failed: \(error)")
            #endif
        }
    }

    /// Force regenerate the plan (user-triggered)
    func forceRegeneratePlan() async {
        guard let plan = currentWeeklyPlan ?? TrainingPlanService.getCachedPlan() else { return }

        let calendar = Calendar.current
        let weekActivities = activities.filter { activity in
            guard let ts = activity.activity_date ?? activity.start_date else { return false }
            let activityDate = Date(timeIntervalSince1970: ts)
            return activityDate >= plan.weekStartDate && activityDate <= plan.weekEndDate
        }

        await regenerateWeeklyPlan(currentPlan: plan, activities: weekActivities)
    }

    // MARK: - Data Modification Methods

    func addActivity(_ activity: Activity) {
        activityStore.addActivity(activity)
        activities = activityStore.activities
    }

    func removeActivity(id: Int) {
        activityStore.removeActivity(id: id)
        activities = activityStore.activities
    }

    func updateActivity(_ updatedActivity: Activity) {
        activityStore.updateActivity(updatedActivity)
        activities = activityStore.activities
    }

    // MARK: - Commitment Management

    func createCommitment(_ activityType: CommitmentActivityType) async throws {
        isLoadingCommitment = true
        defer { isLoadingCommitment = false }

        try await commitmentManager.createCommitment(activityType)
        todaysCommitment = commitmentManager.todaysCommitment
    }

    func checkActivityFulfillsCommitment(_ activity: Activity) async {
        await commitmentManager.checkActivityFulfillsCommitment(activity)
        todaysCommitment = commitmentManager.todaysCommitment
    }

    func refreshTodaysCommitment() async {
        await commitmentManager.refresh()
        todaysCommitment = commitmentManager.todaysCommitment
    }

    func updateCommitment(to activityType: CommitmentActivityType) async throws {
        isLoadingCommitment = true
        defer { isLoadingCommitment = false }

        try await commitmentManager.updateCommitment(to: activityType)
        todaysCommitment = commitmentManager.todaysCommitment
    }

    func deleteCommitment() async throws {
        isLoadingCommitment = true
        defer { isLoadingCommitment = false }

        try await commitmentManager.deleteCommitment()
        todaysCommitment = commitmentManager.todaysCommitment
    }

    // MARK: - Widget Data Management

    func updateWidgetData() {
        // Use database-based stats when athlete ID is available (accurate totals)
        if let athleteId = athlete?.id {
            widgetSyncService.updateWidgetDataFromDatabase(athleteId: athleteId, activities: activities)
        } else if let userId = UserSession.shared.userId {
            widgetSyncService.updateWidgetDataFromDatabase(athleteId: userId, activities: activities)
        } else {
            // Fallback to client-side calculation
            widgetSyncService.updateWidgetData(with: activities)
        }
    }

    // MARK: - Sync Helpers

    private func syncFromStores() {
        activities = activityStore.activities
        athlete = athleteStore.athlete
        stats = athleteStore.stats
        currentGoal = goalManager.currentGoal
        todaysCommitment = commitmentManager.todaysCommitment
    }

    // MARK: - Cache Management

    func clearCache() {
        activityStore.clearCache()
        PerformanceCache.shared.clearAll()
    }
}

// MARK: - DataManager + RealtimeService Integration

extension DataManager {

    func handleRealtimeUpdate(activities: [Activity]) {
        activityStore.handleRealtimeUpdate(activities: activities)
        self.activities = activityStore.activities
        lastDataRefresh = Date()
    }

    func forceRefreshWidget(with activities: [Activity]) {
        activityStore.handleRealtimeUpdate(activities: activities)
        self.activities = activityStore.activities
        // Use database-based widget update for accurate yearly/monthly stats
        if let athleteId = athlete?.id {
            widgetSyncService.forceUpdateFromDatabase(athleteId: athleteId, activities: activities)
        } else if let userId = UserSession.shared.userId {
            widgetSyncService.forceUpdateFromDatabase(athleteId: userId, activities: activities)
        } else {
            widgetSyncService.forceUpdate(with: activities)
        }
    }

    // MARK: - Computed Properties

    var daysSinceLastActivity: Int {
        activityStore.daysSinceLastActivity
    }

    var daysSinceLastActivityText: String {
        activityStore.daysSinceLastActivityText
    }
}

// MARK: - DataManager Errors

enum DataManagerError: Error, LocalizedError {
    case noUserId

    var errorDescription: String? {
        switch self {
        case .noUserId:
            return "No user ID available"
        }
    }
}
