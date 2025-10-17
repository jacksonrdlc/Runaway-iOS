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
    @Published var todaysCommitment: DailyCommitment?
    @Published var isLoadingActivities = false
    @Published var isLoadingAthlete = false
    @Published var isLoadingCommitment = false
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

            // Load today's commitment
            group.addTask {
                await self.loadTodaysCommitment(for: userId)
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
            let previousActivityCount = self.activities.count
            let fetchedActivities = try await ActivityService.getAllActivitiesByUser(userId: userId)

            print("🔍 DataManager: Loaded \(fetchedActivities.count) activities (previously had \(previousActivityCount))")

            self.activities = fetchedActivities

            // Check if we have new activities and check commitment fulfillment for the latest one
            if fetchedActivities.count > previousActivityCount, let latestActivity = fetchedActivities.first {
                print("🔍 DataManager: New activity detected during load - checking commitment fulfillment")

                // Debug: Check if the latest activity is from today
                let today = Calendar.current.startOfDay(for: Date())
                let activityDate = latestActivity.activity_date ?? latestActivity.start_date
                let isFromToday = activityDate.map {
                    Calendar.current.isDate(Date(timeIntervalSince1970: $0), inSameDayAs: today)
                } ?? false

                print("🔍 DataManager: Latest activity '\(latestActivity.name ?? "Unknown")' type '\(latestActivity.type ?? "Unknown")' is from today: \(isFromToday)")

                // Only check commitment if the activity is from today
                if isFromToday {
                    Task {
                        await checkActivityFulfillsCommitment(latestActivity)
                    }
                } else {
                    print("💡 DataManager: Skipping commitment check - activity is not from today")
                }
            }

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
            print("🔍 DataManager: Loading athlete for user ID: \(userId)")
            let fetchedAthlete = try await AthleteService.getAthleteByUserId(userId: userId)
            print("✅ DataManager: Successfully loaded athlete: \(fetchedAthlete.firstname ?? "Unknown") \(fetchedAthlete.lastname ?? "Athlete")")
            print("🔍 DataManager: Athlete details - ID: \(fetchedAthlete.id ?? -1), Email: \(fetchedAthlete.email ?? "No email")")
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
            if fetchedStats == nil {
                print("⚠️ DataManager: No athlete stats available (athlete_stats table doesn't exist)")
            }
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

    /// Load today's commitment
    func loadTodaysCommitment(for userId: Int) async {
        isLoadingCommitment = true
        defer { isLoadingCommitment = false }

        do {
            self.todaysCommitment = try await CommitmentService.getTodaysCommitment(for: userId)
        } catch {
            print("❌ DataManager: Failed to load today's commitment: \(error)")
        }
    }

    // MARK: - Data Refresh Methods

    /// Refresh all data
    func refreshAllData() async {
        guard let userId = UserSession.shared.userId else {
            print("❌ DataManager: No user ID available for refresh")
            return
        }

        await loadAllData(for: userId)
    }

    /// Refresh only activities
    func refreshActivities() async {
        guard let userId = UserSession.shared.userId else {
            print("❌ DataManager: No user ID available for activities refresh")
            return
        }

        print("🔄 DataManager: Refreshing activities for user \(userId)...")
        await loadActivities(for: userId)
        print("✅ DataManager: Activities refreshed. Total count: \(activities.count)")
    }

    // MARK: - Data Modification Methods

    /// Add a new activity to the data store
    func addActivity(_ activity: Activity) {
        activities.insert(activity, at: 0) // Add at beginning for chronological order
        updateWidgetData()
        metricsCache.invalidateActivityCaches()

        // Check if this activity fulfills today's commitment
        Task {
            await checkActivityFulfillsCommitment(activity)
        }
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

    // MARK: - Commitment Management

    /// Create a daily commitment
    func createCommitment(_ activityType: CommitmentActivityType) async throws {
        guard let userId = UserSession.shared.userId else {
            throw DataManagerError.noUserId
        }

        isLoadingCommitment = true
        defer { isLoadingCommitment = false }

        do {
            let commitment = DailyCommitment(athleteId: userId, activityType: activityType)
            let createdCommitment = try await CommitmentService.createCommitment(commitment)
            self.todaysCommitment = createdCommitment
        } catch {
            print("❌ DataManager: Failed to create commitment: \(error)")
            throw error
        }
    }

    /// Check if a new activity fulfills today's commitment
    func checkActivityFulfillsCommitment(_ activity: Activity) async {
        guard let userId = UserSession.shared.userId else {
            print("❌ DataManager: No user ID available for commitment check")
            return
        }

        print("🔍 DataManager: Checking if activity '\(activity.type ?? "unknown")' fulfills commitment for user \(userId)")

        do {
            let fulfilled = try await CommitmentService.checkAndFulfillCommitment(
                for: userId,
                activityType: activity.type
            )

            if fulfilled {
                print("🎉 DataManager: Commitment fulfilled by activity type: \(activity.type ?? "unknown")!")
                // Reload today's commitment to get updated data
                await loadTodaysCommitment(for: userId)
            } else {
                print("💡 DataManager: Activity type '\(activity.type ?? "unknown")' did not fulfill commitment")
            }
        } catch {
            print("❌ DataManager: Failed to check commitment fulfillment: \(error)")
        }
    }

    /// Refresh today's commitment
    func refreshTodaysCommitment() async {
        guard let userId = UserSession.shared.userId else {
            print("❌ DataManager: No user ID available for commitment refresh")
            return
        }

        await loadTodaysCommitment(for: userId)
    }

    // MARK: - Widget Data Management

    /// Single method for updating all widget data in UserDefaults
    /// Optimized to run heavy processing on background queue to avoid blocking main thread
    func updateWidgetData() {
        // Capture activities on main thread
        let activitiesCopy = self.activities

        // Run heavy processing on background queue
        Task.detached(priority: .utility) {
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

                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short

                #if DEBUG
                // Debug all activity types
                print("📊 DataManager: All activity types:")
                for (index, activity) in activitiesCopy.prefix(5).enumerated() {
                    print("📊 Activity \(index): \(activity.name ?? "Unknown") - Type: '\(activity.type ?? "nil")'")
                }
                #endif

                // Filter for widget-relevant activities (Run, Walk, Weight Training, Workout)
                let widgetActivities = activitiesCopy.filter { activity in
                    // Normalize WeightTraining to "Weight Training" before filtering
                    var activityType = activity.type ?? ""
                    if activityType.lowercased() == "weighttraining" {
                        activityType = "Weight Training"
                    }
                    let normalizedType = activityType.lowercased()

                    let isIncluded = normalizedType == "run" ||
                                   normalizedType == "walk" ||
                                   normalizedType == "weight training"
                    #if DEBUG
                    if !isIncluded && !normalizedType.isEmpty {
                        print("📊 DataManager: Excluding activity type: '\(normalizedType)'")
                    }
                    #endif
                    return isIncluded
                }

                let monthlyActivities = widgetActivities.filter { activity in
                    // Use activity_date if available, otherwise fall back to start_date
                    let dateInterval = activity.activity_date ?? activity.start_date
                    guard let dateInterval = dateInterval else { return false }
                    let activityDate = Date(timeIntervalSince1970: dateInterval)
                    return Calendar.current.component(.year, from: activityDate) == currentYear &&
                           Calendar.current.component(.month, from: activityDate) == currentMonth
                }

                // Calculate totals
                let yearlyMiles = widgetActivities.reduce(0) { $0 + ($1.distance ?? 0.0) }
                let monthlyMiles = monthlyActivities.reduce(0) { $0 + ($1.distance ?? 0.0) }
                let totalRuns = widgetActivities.count

                #if DEBUG
                print("📊 DataManager: Total activities: \(activitiesCopy.count)")
                print("📊 DataManager: Widget activities (Run/Walk/Weight): \(widgetActivities.count)")
                print("📊 DataManager: Monthly activities: \(monthlyActivities.count)")
                print("📊 DataManager: Current month: \(currentMonth), year: \(currentYear)")

                // Debug first few monthly activities
                for (index, activity) in monthlyActivities.prefix(3).enumerated() {
                    let dateInterval = activity.activity_date ?? activity.start_date
                    if let dateInterval = dateInterval {
                        let activityDate = Date(timeIntervalSince1970: dateInterval)
                        let activityMonth = Calendar.current.component(.month, from: activityDate)
                        let activityYear = Calendar.current.component(.year, from: activityDate)
                        print("📊 Monthly Activity \(index): \(activity.name ?? "Unknown") - Date: \(activityDate) - Month: \(activityMonth), Year: \(activityYear) - Distance: \(activity.distance ?? 0) meters")
                    } else {
                        print("📊 Monthly Activity \(index): \(activity.name ?? "Unknown") - NO DATE AVAILABLE - Distance: \(activity.distance ?? 0) meters")
                    }
                }

                print("📊 DataManager: Yearly Miles: \(yearlyMiles * 0.000621371), Monthly Miles: \(monthlyMiles * 0.000621371), Total Runs: \(totalRuns)")
                #endif

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

                #if DEBUG
                print("📊 DataManager: Processing \(widgetActivities.count) activities for widget...")
                print("📊 DataManager: Week start date: \(weekStartDate)")
                #endif

                for activity in widgetActivities {
                    #if DEBUG
                    print("📊 DataManager: Processing activity '\(activity.name ?? "Unknown")' - Type: '\(activity.type ?? "nil")'")
                    #endif

                    // Use activity_date first, fall back to start_date
                    let activityDateInterval = activity.activity_date ?? activity.start_date

                    #if DEBUG
                    // Enhanced debugging for date comparison
                    if let dateInterval = activityDateInterval {
                        let activityDate = Date(timeIntervalSince1970: dateInterval)
                        let weekStartDateFormatted = Date(timeIntervalSince1970: weekStartDate)
                        print("📊 DataManager: Activity date: \(activityDate)")
                        print("📊 DataManager: Week start: \(weekStartDateFormatted)")
                        print("📊 DataManager: Activity is after week start: \(dateInterval > weekStartDate)")
                    } else {
                        print("📊 DataManager: Activity has no date!")
                    }
                    #endif

                    guard let dateInterval = activityDateInterval,
                          let distance = activity.distance,
                          let elapsedTime = activity.elapsed_time,
                          dateInterval > weekStartDate else {
                        #if DEBUG
                        print("📊 DataManager: Skipping activity '\(activity.name ?? "Unknown")' - missing data or too old")
                        #endif
                        continue
                    }

                    let dayOfWeek = Date(timeIntervalSince1970: dateInterval).dayOfTheWeek

                    #if DEBUG
                    print("📊 DataManager: Activity '\(activity.name ?? "Unknown")' is on \(dayOfWeek)")
                    #endif

                    // Normalize WeightTraining to "Weight Training" for widget
                    var normalizedType = activity.type ?? "Run"
                    if normalizedType.lowercased() == "weighttraining" {
                        normalizedType = "Weight Training"
                    }

                    let raActivity = RAActivity(
                        day: String(dayOfWeek.prefix(2)),
                        type: normalizedType, // Use normalized type for widget compatibility
                        distance: distance * 0.000621371,
                        time: elapsedTime / 60
                    )

                    #if DEBUG
                    print("📊 DataManager: Adding activity '\(activity.name ?? "Unknown")' to \(dayOfWeek) - Distance: \(distance * 0.000621371) mi, Time: \(elapsedTime / 60) min")
                    #endif

                    do {
                        let jsonData = try encoder.encode(raActivity)
                        if let jsonString = String(data: jsonData, encoding: .utf8) {
                            weeklyArrays[dayOfWeek]?.append(jsonString)
                            #if DEBUG
                            print("📊 DataManager: Successfully encoded activity for \(dayOfWeek)")
                            #endif
                        }
                    } catch {
                        print("❌ DataManager: Failed to encode activity for widget: \(error)")
                    }
                }

                #if DEBUG
                // Debug weekly arrays before storing
                print("📊 DataManager: Widget data summary:")
                for (day, activities) in weeklyArrays {
                    print("📊   \(day): \(activities.count) activities")
                    if !activities.isEmpty {
                        print("📊     First activity: \(activities.first ?? "nil")")
                    }
                }
                #endif

                // Store weekly arrays
                userDefaults.set(weeklyArrays["Sunday"], forKey: "sunArray")
                userDefaults.set(weeklyArrays["Monday"], forKey: "monArray")
                userDefaults.set(weeklyArrays["Tuesday"], forKey: "tueArray")
                userDefaults.set(weeklyArrays["Wednesday"], forKey: "wedArray")
                userDefaults.set(weeklyArrays["Thursday"], forKey: "thuArray")
                userDefaults.set(weeklyArrays["Friday"], forKey: "friArray")
                userDefaults.set(weeklyArrays["Saturday"], forKey: "satArray")

                #if DEBUG
                // Log what was actually stored in UserDefaults
                print("📊 DataManager: Activities stored in UserDefaults:")
                print("📊   sunArray: \(userDefaults.stringArray(forKey: "sunArray")?.count ?? 0) activities")
                print("📊   monArray: \(userDefaults.stringArray(forKey: "monArray")?.count ?? 0) activities")
                print("📊   tueArray: \(userDefaults.stringArray(forKey: "tueArray")?.count ?? 0) activities")
                print("📊   wedArray: \(userDefaults.stringArray(forKey: "wedArray")?.count ?? 0) activities")
                print("📊   thuArray: \(userDefaults.stringArray(forKey: "thuArray")?.count ?? 0) activities")
                print("📊   friArray: \(userDefaults.stringArray(forKey: "friArray")?.count ?? 0) activities")
                print("📊   satArray: \(userDefaults.stringArray(forKey: "satArray")?.count ?? 0) activities")

                // Log sample activity data for debugging
                if let sundayActivities = userDefaults.stringArray(forKey: "sunArray"), !sundayActivities.isEmpty {
                    print("📊   Sample Sunday activity: \(sundayActivities.first!)")
                }
                if let mondayActivities = userDefaults.stringArray(forKey: "monArray"), !mondayActivities.isEmpty {
                    print("📊   Sample Monday activity: \(mondayActivities.first!)")
                }

                print("📊 DataManager: Widget data updated successfully. Triggering widget refresh...")
                #endif
            }

            // Trigger widget refresh on main thread
            await MainActor.run {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    // MARK: - Computed Properties

    /// Get activities for the current week
//    var currentWeekActivities: [Activity] {
//        let weekStart = Date().startOfWeek()
//        return activities.filter { activity in
//            guard let startDate = activity.start_date else { return false }
//            return startDate > weekStart
//        }
//    }
//
//    /// Get activities for the current month
//    var currentMonthActivities: [Activity] {
//        let currentMonth = Calendar.current.component(.month, from: Date())
//        let currentYear = Calendar.current.component(.year, from: Date())
//
//        return activities.filter { activity in
//            guard let startDate = activity.start_date else { return false }
//            let activityDate = Date(timeIntervalSince1970: startDate)
//            return Calendar.current.component(.month, from: activityDate) == currentMonth &&
//                   Calendar.current.component(.year, from: activityDate) == currentYear
//        }
//    }

//    /// Get total miles for current year
//    var totalYearMiles: Double {
//        let currentYear = Calendar.current.component(.year, from: Date())
//        let yearlyActivities = activities.filter { activity in
//            guard let startDate = activity.start_date else { return false }
//            let activityDate = Date(timeIntervalSince1970: startDate)
//            return Calendar.current.component(.year, from: activityDate) == currentYear
//        }
//        let totalMeters = yearlyActivities.reduce(0) { $0 + ($1.distance ?? 0.0) }
//        return totalMeters * 0.000621371
//    }

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
        let previousActivityCount = self.activities.count

        // Update activities with new data
        self.activities = activities

        // Update widget data
        updateWidgetData()

        // Update last refresh time
        lastDataRefresh = Date()

        // Check if new activities fulfill commitment (only if we have more activities now)
        if activities.count > previousActivityCount, let latestActivity = activities.first {
            Task {
                await checkActivityFulfillsCommitment(latestActivity)
            }
        }
    }

    /// Force refresh widget data (called from RealtimeService)
    func forceRefreshWidget(with activities: [Activity]) {
        self.activities = activities
        updateWidgetData()
    }

    // MARK: - Computed Properties

    /// Days since last activity
    var daysSinceLastActivity: Int {
        guard let lastActivity = activities.first?.start_date else {
            return -1 // Indicates no activities
        }

        let lastActivityDate = Date(timeIntervalSince1970: lastActivity)
        let today = Date()

        // Get the start of today and the start of the activity day
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: today)
        let startOfActivityDay = calendar.startOfDay(for: lastActivityDate)

        let components = calendar.dateComponents([.day], from: startOfActivityDay, to: startOfToday)
        return components.day ?? 0
    }

    /// Text for days since last activity
    var daysSinceLastActivityText: String {
        let days = daysSinceLastActivity

        if days == -1 {
            return "Let's log your first activity."
        } else if days == 0 {
            return "0 days since last activity"
        } else if days == 1 {
            return "1 day since last activity"
        } else {
            return "\(days) days since last activity"
        }
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
