//
//  DataManager.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 9/14/25.
//

import Foundation
import SwiftUI
import WidgetKit

// MARK: - Centralized Data Manager

@MainActor
class DataManager: ObservableObject {

    // MARK: - Published Properties (Single Source of Truth)

    @Published var activities: [Activity] = []
    @Published var athlete: Athlete?
    @Published var stats: AthleteStats?
    @Published var currentGoal: RunningGoal?
    @Published var isLoadingActivities = false
    @Published var isLoadingAthlete = false
    @Published var lastDataRefresh: Date?

    // MARK: - Private Properties

    private let metricsCache = ActivityMetricsCache()
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid

    // MARK: - Singleton

    static let shared = DataManager()

    private init() {
        // Initialize with cached data if available
        loadCachedData()
    }

    // MARK: - Data Loading Methods

    /// Load all user data for the given userId
    func loadAllData(for userId: Int) async {
        await withTaskGroup(of: Void.self) { group in
            // Load activities
            group.addTask {
                await self.loadActivities(for: userId)
            }

            // Load athlete profile
            group.addTask {
                await self.loadAthlete(for: userId)
            }

            // Load stats
            group.addTask {
                await self.loadStats(for: userId)
            }

            // Load current goal
            group.addTask {
                await self.loadCurrentGoal(for: userId)
            }
        }

        // Update widgets after all data is loaded
        updateWidgetData()
        lastDataRefresh = Date()
    }

    /// Load activities for the user
    func loadActivities(for userId: Int) async {
        isLoadingActivities = true
        defer { isLoadingActivities = false }

        // Start background task to prevent interruption
        startBackgroundTask()
        defer { endBackgroundTask() }

        do {
            let fetchedActivities = try await ActivityService.getAllActivitiesByUser(userId: userId)
            self.activities = fetchedActivities

            // Update widget data after activities refresh
            updateWidgetData()

            // Invalidate related caches
            metricsCache.invalidateActivityCaches()

        } catch {
            print("❌ DataManager: Failed to load activities: \(error)")
        }
    }

    /// Load athlete profile
    func loadAthlete(for userId: Int) async {
        isLoadingAthlete = true
        defer { isLoadingAthlete = false }

        do {
            let fetchedAthlete = try await AthleteService.getAthleteByUserId(userId: userId)
            self.athlete = fetchedAthlete
        } catch {
            print("❌ DataManager: Failed to load athlete: \(error)")
        }
    }

    /// Load athlete statistics
    func loadStats(for userId: Int) async {
        do {
            let fetchedStats = try await AthleteService.getAthleteStats(userId: userId)
            self.stats = fetchedStats
        } catch {
            print("❌ DataManager: Failed to load stats: \(error)")
        }
    }

    /// Load current running goal
    func loadCurrentGoal(for userId: Int) async {
        do {
            let goals = try await GoalService.getActiveGoals()
            self.currentGoal = goals.first { !$0.isCompleted }
        } catch {
            print("❌ DataManager: Failed to load goals: \(error)")
        }
    }

    // MARK: - Data Refresh Methods

    /// Refresh all data
    func refreshAllData() async {
        guard let userId = UserManager.shared.userId else {
            print("❌ DataManager: No user ID available for refresh")
            return
        }

        await loadAllData(for: userId)
    }

    /// Refresh only activities
    func refreshActivities() async {
        guard let userId = UserManager.shared.userId else {
            print("❌ DataManager: No user ID available for activities refresh")
            return
        }

        await loadActivities(for: userId)
    }

    // MARK: - Data Modification Methods

    /// Add a new activity to the data store
    func addActivity(_ activity: Activity) {
        activities.insert(activity, at: 0) // Add at beginning for chronological order
        updateWidgetData()
        metricsCache.invalidateActivityCaches()
    }

    /// Remove an activity from the data store
    func removeActivity(id: Int) {
        activities.removeAll { $0.id == id }
        updateWidgetData()
        metricsCache.invalidateActivityCaches()
    }

    /// Update an existing activity
    func updateActivity(_ updatedActivity: Activity) {
        if let index = activities.firstIndex(where: { $0.id == updatedActivity.id }) {
            activities[index] = updatedActivity
            updateWidgetData()
            metricsCache.invalidateActivityCaches()
        }
    }

    // MARK: - Widget Data Management

    /// Single method for updating all widget data in UserDefaults
    func updateWidgetData() {
        guard let userDefaults = UserDefaults(suiteName: "group.com.jackrudelic.runawayios") else {
            print("❌ DataManager: Failed to access shared UserDefaults")
            return
        }

        // Use autoreleasepool for memory efficiency
        autoreleasepool {
            // Clear existing data
            let arrayKeys = ["sunArray", "monArray", "tueArray", "wedArray", "thuArray", "friArray", "satArray"]
            arrayKeys.forEach { userDefaults.removeObject(forKey: $0) }

            // Calculate date ranges
            let currentYear = Calendar.current.component(.year, from: Date())
            let currentMonth = Calendar.current.component(.month, from: Date())
            let weekStartDate = Date().startOfWeek()

            // Filter activities by date ranges
            let yearlyActivities = activities.filter { activity in
                guard let startDate = activity.start_date else { return false }
                let activityDate = Date(timeIntervalSince1970: startDate)
                return Calendar.current.component(.year, from: activityDate) == currentYear
            }

            let monthlyActivities = activities.filter { activity in
                guard let startDate = activity.start_date else { return false }
                let activityDate = Date(timeIntervalSince1970: startDate)
                return Calendar.current.component(.year, from: activityDate) == currentYear &&
                       Calendar.current.component(.month, from: activityDate) == currentMonth
            }

            // Calculate totals
            let yearlyMiles = yearlyActivities.reduce(0) { $0 + ($1.distance ?? 0.0) }
            let monthlyMiles = monthlyActivities.reduce(0) { $0 + ($1.distance ?? 0.0) }
            let totalRuns = yearlyActivities.count

            // Store totals
            userDefaults.set(yearlyMiles * 0.000621371, forKey: "miles")
            userDefaults.set(monthlyMiles * 0.000621371, forKey: "monthlyMiles")
            userDefaults.set(totalRuns, forKey: "runs")

            // Process weekly activities for widget display
            var weeklyArrays: [String: [String]] = [
                "Sunday": [],
                "Monday": [],
                "Tuesday": [],
                "Wednesday": [],
                "Thursday": [],
                "Friday": [],
                "Saturday": []
            ]

            let encoder = JSONEncoder()

            for activity in activities {
                guard let startDate = activity.start_date,
                      let distance = activity.distance,
                      let elapsedTime = activity.elapsed_time,
                      startDate > weekStartDate else { continue }

                let dayOfWeek = Date(timeIntervalSince1970: startDate).dayOfTheWeek

                let raActivity = RAActivity(
                    day: String(dayOfWeek.prefix(1)),
                    type: activity.type,
                    distance: distance * 0.000621371,
                    time: elapsedTime / 60
                )

                do {
                    let jsonData = try encoder.encode(raActivity)
                    if let jsonString = String(data: jsonData, encoding: .utf8) {
                        weeklyArrays[dayOfWeek]?.append(jsonString)
                    }
                } catch {
                    print("❌ DataManager: Failed to encode activity for widget: \(error)")
                }
            }

            // Store weekly arrays
            userDefaults.set(weeklyArrays["Sunday"], forKey: "sunArray")
            userDefaults.set(weeklyArrays["Monday"], forKey: "monArray")
            userDefaults.set(weeklyArrays["Tuesday"], forKey: "tueArray")
            userDefaults.set(weeklyArrays["Wednesday"], forKey: "wedArray")
            userDefaults.set(weeklyArrays["Thursday"], forKey: "thuArray")
            userDefaults.set(weeklyArrays["Friday"], forKey: "friArray")
            userDefaults.set(weeklyArrays["Saturday"], forKey: "satArray")
        }

        // Trigger widget refresh
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Computed Properties

    /// Get activities for the current week
    var currentWeekActivities: [Activity] {
        let weekStart = Date().startOfWeek()
        return activities.filter { activity in
            guard let startDate = activity.start_date else { return false }
            return startDate > weekStart
        }
    }

    /// Get activities for the current month
    var currentMonthActivities: [Activity] {
        let currentMonth = Calendar.current.component(.month, from: Date())
        let currentYear = Calendar.current.component(.year, from: Date())

        return activities.filter { activity in
            guard let startDate = activity.start_date else { return false }
            let activityDate = Date(timeIntervalSince1970: startDate)
            return Calendar.current.component(.month, from: activityDate) == currentMonth &&
                   Calendar.current.component(.year, from: activityDate) == currentYear
        }
    }

    /// Get total miles for current year
    var totalYearMiles: Double {
        let currentYear = Calendar.current.component(.year, from: Date())
        let yearlyActivities = activities.filter { activity in
            guard let startDate = activity.start_date else { return false }
            let activityDate = Date(timeIntervalSince1970: startDate)
            return Calendar.current.component(.year, from: activityDate) == currentYear
        }
        let totalMeters = yearlyActivities.reduce(0) { $0 + ($1.distance ?? 0.0) }
        return totalMeters * 0.000621371
    }

    // MARK: - Background Task Management

    private func startBackgroundTask() {
        backgroundTaskId = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        if backgroundTaskId != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskId)
            backgroundTaskId = .invalid
        }
    }

    // MARK: - Cache Management

    private func loadCachedData() {
        // Load any cached data from UserDefaults or other persistence layer
        // This can be implemented based on your caching strategy
    }

    /// Clear all cached data
    func clearCache() {
        metricsCache.invalidateActivityCaches()
        PerformanceCache.shared.clearAll()
    }
}

// MARK: - DataManager + RealtimeService Integration

extension DataManager {

    /// Handle realtime updates from RealtimeService
    func handleRealtimeUpdate(activities: [Activity]) {
        // Update activities with new data
        self.activities = activities

        // Update widget data
        updateWidgetData()

        // Update last refresh time
        lastDataRefresh = Date()
    }

    /// Force refresh widget data (called from RealtimeService)
    func forceRefreshWidget(with activities: [Activity]) {
        self.activities = activities
        updateWidgetData()
    }
}
