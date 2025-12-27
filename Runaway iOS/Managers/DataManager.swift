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
    @Published var isLoadingActivities = false
    @Published var isLoadingAthlete = false
    @Published var isLoadingCommitment = false
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

        // Auto-generate journal
        await autoGenerateJournalForCurrentWeek()
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

    // MARK: - Journal Management

    func autoGenerateJournalForCurrentWeek() async {
        guard let athleteId = athlete?.id else {
            print("⚠️ DataManager: No athlete ID for journal generation")
            return
        }

        let calendar = Calendar.current
        let now = Date()
        guard let weekStart = calendar.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: now).date else {
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let weekStartString = formatter.string(from: weekStart)

        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? now
        let weekStartTimestamp = weekStart.timeIntervalSince1970
        let weekEndTimestamp = weekEnd.timeIntervalSince1970

        let activitiesThisWeek = activities.filter { activity in
            guard let activityDate = activity.start_date else { return false }
            return activityDate >= weekStartTimestamp && activityDate < weekEndTimestamp
        }

        guard !activitiesThisWeek.isEmpty else { return }

        do {
            _ = try await JournalService.generateJournalEntry(
                athleteId: athleteId,
                weekStartDate: weekStartString
            )
            #if DEBUG
            print("✅ DataManager: Journal generated for week starting \(weekStartString)")
            #endif
        } catch let error as JournalError {
            switch error {
            case .noActivitiesFound:
                break // Expected if week just started
            case .httpError(let code):
                print("❌ DataManager: Journal HTTP error: \(code)")
            default:
                print("❌ DataManager: Journal error: \(error)")
            }
        } catch {
            print("❌ DataManager: Journal generation failed: \(error)")
        }
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
