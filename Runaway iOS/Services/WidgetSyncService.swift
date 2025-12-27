//
//  WidgetSyncService.swift
//  Runaway iOS
//
//  Created by Claude on 12/23/25.
//

import Foundation
import WidgetKit
import UIKit

// MARK: - Widget Sync Service

@MainActor
final class WidgetSyncService {

    // MARK: - Constants

    private static let appGroupIdentifier = "group.com.jackrudelic.runawayios"
    private static let debounceInterval: TimeInterval = 0.5

    // MARK: - Private Properties

    private var updateTask: Task<Void, Never>?
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid

    // MARK: - Singleton

    static let shared = WidgetSyncService()

    private init() {}

    // MARK: - Public Methods

    /// Update widget data with debouncing (uses client-side calculation for weekly data)
    func updateWidgetData(with activities: [Activity]) {
        // Cancel any pending update
        updateTask?.cancel()

        // Debounce widget updates
        updateTask = Task.detached(priority: .utility) { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.debounceInterval * 1_000_000_000))

            guard !Task.isCancelled else { return }

            await self?.performWidgetUpdate(with: activities)
        }
    }

    /// Update widget data using database aggregation for yearly/monthly stats
    /// This method fetches accurate totals from the database, not affected by pagination
    func updateWidgetDataFromDatabase(athleteId: Int, activities: [Activity]) {
        // Don't cancel if already running - let it complete
        guard updateTask == nil else {
            print("🔄 WidgetSyncService: Update already in progress, skipping")
            return
        }

        updateTask = Task { [weak self] in
            defer { Task { @MainActor in self?.updateTask = nil } }

            try? await Task.sleep(nanoseconds: UInt64(Self.debounceInterval * 1_000_000_000))

            guard !Task.isCancelled else { return }

            await self?.performDatabaseWidgetUpdate(athleteId: athleteId, activities: activities)
        }
    }

    /// Force immediate widget update
    func forceUpdate(with activities: [Activity]) {
        updateTask?.cancel()

        Task.detached(priority: .utility) { [weak self] in
            await self?.performWidgetUpdate(with: activities)
        }
    }

    /// Force immediate widget update using database stats
    func forceUpdateFromDatabase(athleteId: Int, activities: [Activity]) {
        updateTask?.cancel()
        updateTask = nil

        Task { [weak self] in
            await self?.performDatabaseWidgetUpdate(athleteId: athleteId, activities: activities)
        }
    }

    /// Trigger widget timeline reload
    func reloadWidgetTimelines() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Private Methods

    private func performWidgetUpdate(with activities: [Activity]) async {
        await Task.detached(priority: .utility) { [activities] in
            guard let userDefaults = UserDefaults(suiteName: Self.appGroupIdentifier) else {
                print("❌ WidgetSyncService: Failed to access shared UserDefaults")
                return
            }

            autoreleasepool {
                // Clear existing data
                let arrayKeys = ["sunArray", "monArray", "tueArray", "wedArray", "thuArray", "friArray", "satArray"]
                arrayKeys.forEach { userDefaults.removeObject(forKey: $0) }

                // Calculate date ranges
                let currentYear = Calendar.current.component(.year, from: Date())
                let currentMonth = Calendar.current.component(.month, from: Date())
                let weekStartDate = Date().startOfWeek()

                // Single-pass filtering
                struct FilteredActivities {
                    var widgetActivities: [Activity] = []
                    var yearlyRunning: [Activity] = []
                    var monthlyRunning: [Activity] = []
                }

                let filtered = activities.reduce(into: FilteredActivities()) { result, activity in
                    let normalizedType = (activity.type ?? "").lowercased()

                    let dateInterval = activity.activity_date ?? activity.start_date
                    let activityDate = dateInterval.map { Date(timeIntervalSince1970: $0) }
                    let activityYear = activityDate.map { Calendar.current.component(.year, from: $0) }
                    let activityMonth = activityDate.map { Calendar.current.component(.month, from: $0) }

                    // Widget-relevant activity types
                    let isWidgetRelevant = ["run", "trail run", "trailrun", "trail_run", "walk",
                                           "weight training", "weighttraining", "yoga",
                                           "bike ride", "bike_ride", "hike", "swim",
                                           "elliptical", "rowing", "stairmaster"].contains(normalizedType)

                    if isWidgetRelevant {
                        result.widgetActivities.append(activity)
                    }

                    let isRunning = normalizedType.contains("run")

                    if isRunning && activityYear == currentYear {
                        result.yearlyRunning.append(activity)

                        if activityMonth == currentMonth {
                            result.monthlyRunning.append(activity)
                        }
                    }
                }

                // Calculate totals
                let yearlyMiles = filtered.yearlyRunning.reduce(0) { $0 + ($1.distance ?? 0.0) } * 0.000621371
                let monthlyMiles = filtered.monthlyRunning.reduce(0) { $0 + ($1.distance ?? 0.0) } * 0.000621371
                let totalRuns = filtered.yearlyRunning.count

                // Store totals
                userDefaults.set(yearlyMiles, forKey: "miles")
                userDefaults.set(monthlyMiles, forKey: "monthlyMiles")
                userDefaults.set(totalRuns, forKey: "runs")

                // Process weekly activities
                var weeklyArrays: [String: [String]] = [
                    "Sunday": [], "Monday": [], "Tuesday": [],
                    "Wednesday": [], "Thursday": [], "Friday": [], "Saturday": []
                ]

                let encoder = JSONEncoder()

                for activity in filtered.widgetActivities {
                    let activityDateInterval = activity.activity_date ?? activity.start_date

                    guard let dateInterval = activityDateInterval,
                          let distance = activity.distance,
                          let elapsedTime = activity.elapsed_time,
                          dateInterval > weekStartDate else {
                        continue
                    }

                    let dayOfWeek = Date(timeIntervalSince1970: dateInterval).dayOfTheWeek

                    // Normalize activity types for widget
                    var normalizedType = activity.type ?? "Run"
                    if normalizedType.lowercased() == "weighttraining" {
                        normalizedType = "Weight Training"
                    }
                    if normalizedType.lowercased() == "trailrun" {
                        normalizedType = "Trail Run"
                    }

                    let raActivity = RAActivity(
                        day: String(dayOfWeek.prefix(2)),
                        type: normalizedType,
                        distance: distance * 0.000621371,
                        time: elapsedTime / 60
                    )

                    do {
                        let jsonData = try encoder.encode(raActivity)
                        if let jsonString = String(data: jsonData, encoding: .utf8) {
                            weeklyArrays[dayOfWeek]?.append(jsonString)
                        }
                    } catch {
                        print("❌ WidgetSyncService: Failed to encode activity: \(error)")
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
            await MainActor.run {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }.value
    }

    // MARK: - Database-Based Widget Update

    private func performDatabaseWidgetUpdate(athleteId: Int, activities: [Activity]) async {
        // Fetch stats from database (not affected by pagination)
        let yearlyStats: ActivityService.YearlyRunningStats
        let monthlyStats: ActivityService.MonthlyRunningStats

        print("🔄 WidgetSyncService: Fetching stats from database for athlete \(athleteId)...")

        do {
            yearlyStats = try await ActivityService.getYearlyRunningStats(athleteId: athleteId)
            monthlyStats = try await ActivityService.getMonthlyRunningStats(athleteId: athleteId)
            print("✅ WidgetSyncService: DB stats fetched - \(yearlyStats.total_runs) runs, \(yearlyStats.total_distance_miles) miles YTD")
        } catch {
            print("❌ WidgetSyncService: Failed to fetch stats from database: \(error)")
            print("❌ WidgetSyncService: Falling back to client-side calculation")
            // Fall back to client-side calculation
            await performWidgetUpdate(with: activities)
            return
        }

        await Task.detached(priority: .utility) { [activities, yearlyStats, monthlyStats] in
            guard let userDefaults = UserDefaults(suiteName: Self.appGroupIdentifier) else {
                print("❌ WidgetSyncService: Failed to access shared UserDefaults")
                return
            }

            autoreleasepool {
                // Clear existing weekly data
                let arrayKeys = ["sunArray", "monArray", "tueArray", "wedArray", "thuArray", "friArray", "satArray"]
                arrayKeys.forEach { userDefaults.removeObject(forKey: $0) }

                // Store database-fetched totals (accurate regardless of pagination)
                userDefaults.set(yearlyStats.total_distance_miles, forKey: "miles")
                userDefaults.set(monthlyStats.total_distance_miles, forKey: "monthlyMiles")
                userDefaults.set(yearlyStats.total_runs, forKey: "runs")

                // Process weekly activities (only need current week, so pagination doesn't affect this)
                let weekStartDate = Date().startOfWeek()

                var weeklyArrays: [String: [String]] = [
                    "Sunday": [], "Monday": [], "Tuesday": [],
                    "Wednesday": [], "Thursday": [], "Friday": [], "Saturday": []
                ]

                let encoder = JSONEncoder()

                for activity in activities {
                    let normalizedType = (activity.type ?? "").lowercased()

                    // Widget-relevant activity types
                    let isWidgetRelevant = ["run", "trail run", "trailrun", "trail_run", "walk",
                                           "weight training", "weighttraining", "yoga",
                                           "bike ride", "bike_ride", "hike", "swim",
                                           "elliptical", "rowing", "stairmaster"].contains(normalizedType)

                    guard isWidgetRelevant else { continue }

                    let activityDateInterval = activity.activity_date ?? activity.start_date

                    guard let dateInterval = activityDateInterval,
                          let distance = activity.distance,
                          let elapsedTime = activity.elapsed_time,
                          dateInterval > weekStartDate else {
                        continue
                    }

                    let dayOfWeek = Date(timeIntervalSince1970: dateInterval).dayOfTheWeek

                    // Normalize activity types for widget
                    var displayType = activity.type ?? "Run"
                    if displayType.lowercased() == "weighttraining" {
                        displayType = "Weight Training"
                    }
                    if displayType.lowercased() == "trailrun" {
                        displayType = "Trail Run"
                    }

                    let raActivity = RAActivity(
                        day: String(dayOfWeek.prefix(2)),
                        type: displayType,
                        distance: distance * 0.000621371,
                        time: elapsedTime / 60
                    )

                    do {
                        let jsonData = try encoder.encode(raActivity)
                        if let jsonString = String(data: jsonData, encoding: .utf8) {
                            weeklyArrays[dayOfWeek]?.append(jsonString)
                        }
                    } catch {
                        print("❌ WidgetSyncService: Failed to encode activity: \(error)")
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
            await MainActor.run {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }.value

        print("✅ WidgetSyncService: Updated widget with database stats - \(yearlyStats.total_runs) runs, \(String(format: "%.1f", yearlyStats.total_distance_miles)) miles YTD")
    }

    // MARK: - Background Task Management

    func startBackgroundTask() {
        backgroundTaskId = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }

    func endBackgroundTask() {
        if backgroundTaskId != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskId)
            backgroundTaskId = .invalid
        }
    }
}
