import Foundation
import UIKit
import Supabase
import BackgroundTasks
import WidgetKit

@MainActor
public final class RealtimeService: ObservableObject {
    @Published public var isConnected = false
    @Published public var lastUpdateTime: Date?
    
    public static let shared = RealtimeService()
    
    private var subscription: RealtimeSubscription?
    
    private var channel: RealtimeChannelV2?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private let backgroundTaskIdentifier = "com.jackrudelic.runawayios.realtime-background"
    
    private init() {
        print("RealtimeService initialized")
        registerBackgroundTask()
    }
    
    // MARK: - Public Methods
    
    public func startRealtimeSubscription() {
        Task {
            let userId = await MainActor.run {
                UserManager.shared.userId
            }
            guard let userId = userId else {
                print("No authenticated user, cannot start realtime subscription")
                return
            }
            
            await setupRealtimeSubscription(userId: userId)
        }
    }
    
    public func stopRealtimeSubscription() {
        Task {
            await cleanupSubscription()
        }
    }
    
    public func refreshWidget() {
        Task {
            await refreshActivityData()
        }
    }
    
    public func forceRefreshWidget(with activities: [Activity]) {
        createActivityRecord(activities: activities)
    }
    
    // MARK: - Private Methods
    
    private func setupRealtimeSubscription(userId: Int) async {
        // Clean up existing subscription first
        await cleanupSubscription()
        
        // Create channel
        let channel = supabase.channel("activities-realtime")
        self.channel = channel
        
        // Create the observations before subscribing
        let insertions = channel.postgresChange(
            AnyAction.self,
            table: "activities",
            filter: "user_id=eq.\(userId)"
        )
        
        let updates = channel.postgresChange(
            AnyAction.self,
            table: "activities", 
            filter: "user_id=eq.\(userId)"
        )
        
        let deletions = channel.postgresChange(
            AnyAction.self,
            table: "activities",
            filter: "user_id=eq.\(userId)"
        )
        
        print("Subscribing to realtime channel for user: \(userId)")
        await channel.subscribe()
        
        await MainActor.run {
            self.isConnected = true
        }
        
        // Listen for insertions
        Task {
            for await _ in insertions {
                print("Activity inserted - refreshing data")
                await handleRealtimeUpdate()
            }
        }
        
        // Listen for updates
        Task {
            for await _ in updates {
                print("Activity updated - refreshing data")
                await handleRealtimeUpdate()
            }
        }
        
        // Listen for deletions
        Task {
            for await _ in deletions {
                print("Activity deleted - refreshing data")
                await handleRealtimeUpdate()
            }
        }
    }
    
    private func handleRealtimeUpdate() async {
        // Start background task to ensure we have time to process
        startBackgroundTask()
        
        // Update last update time
        await MainActor.run {
            self.lastUpdateTime = Date()
        }
        
        // Refresh data and update widget
        await refreshActivityData()
        
        // End background task
        endBackgroundTask()
    }
    
    private func refreshActivityData() async {
        let userId = await MainActor.run {
            UserManager.shared.userId
        }
        guard let userId = userId else {
            print("No authenticated user for data refresh")
            return
        }
        
        
        do {
            let activities = try await ActivityService.getAllActivitiesByUser(userId: userId)
            
            // Update UserDefaults for widget
            await MainActor.run {
                createActivityRecord(activities: activities)
            }
            
            // Notify UI via NotificationCenter
            NotificationCenter.default.post(name: .activitiesUpdated, object: activities)
            
        } catch {
            print("Error refreshing activity data: \(error)")
        }
    }
    
    private func cleanupSubscription() async {
        if let channel = self.channel {
            await supabase.removeChannel(channel)
            self.channel = nil
        }
        
        await MainActor.run {
            self.isConnected = false
        }
        
        print("Realtime subscription cleaned up")
    }
    
    // MARK: - Background Task Management
    
    private func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
            self.handleBackgroundTask(task: task as! BGAppRefreshTask)
        }
    }
    
    private func startBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
    
    private func handleBackgroundTask(task: BGAppRefreshTask) {
        scheduleBackgroundRefresh()
        
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        // If we have an active subscription, this will keep it alive briefly
        Task {
            if isConnected {
                // Keep realtime connection alive for a short period
                try? await Task.sleep(for: .seconds(10))
            }
            task.setTaskCompleted(success: true)
        }
    }
    
    private func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        
        try? BGTaskScheduler.shared.submit(request)
    }
    
    // MARK: - Widget Data Management
    
    private func createActivityRecord(activities: [Activity]) {
        guard let userDefaults = UserDefaults(suiteName: "group.com.jackrudelic.runawayios") else {
            print("Failed to access shared UserDefaults")
            return
        }


        // Use autoreleasepool to manage memory during heavy processing
        autoreleasepool {
            // Clear existing arrays first
            let arrayKeys = ["sunArray", "monArray", "tueArray", "wedArray", "thuArray", "friArray", "satArray"]
            arrayKeys.forEach { userDefaults.removeObject(forKey: $0) }

            // Use dictionary instead of separate arrays for better memory management
            var weeklyArrays: [String: [String]] = [
                "Sunday": [],
                "Monday": [],
                "Tuesday": [],
                "Wednesday": [],
                "Thursday": [],
                "Friday": [],
                "Saturday": []
            ]
        
        // Calculate totals for the year and month
        let currentYear = Calendar.current.component(.year, from: Date())
        let currentMonth = Calendar.current.component(.month, from: Date())
        
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
        
        // Print monthly activities start dates
        print("=== Monthly Activities Start Dates ===")
        print("Found \(monthlyActivities.count) activities for current month")
        for (index, activity) in monthlyActivities.enumerated() {
            if let startDate = activity.start_date {
                let activityDate = Date(timeIntervalSince1970: startDate)
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                print("Activity \(index + 1): \(formatter.string(from: activityDate)) - Type: \(activity.type ?? "Unknown")")
            }
        }
        print("=====================================")
        
        let yearlyMiles = yearlyActivities.reduce(0) { $0 + ($1.distance ?? 0.0) }
        let monthlyMiles = monthlyActivities.reduce(0) { $0 + ($1.distance ?? 0.0) }
        let totalRuns = yearlyActivities.count
        
        userDefaults.set((yearlyMiles * 0.000621371), forKey: "miles")
        userDefaults.set((monthlyMiles * 0.000621371), forKey: "monthlyMiles")
        userDefaults.set(totalRuns, forKey: "runs")
        
            // Process weekly activities more efficiently
            let weekStartDate = Date().startOfWeek()
            let encoder = JSONEncoder() // Reuse encoder instance

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

                // Use more efficient encoding with error handling
                do {
                    let jsonData = try encoder.encode(raActivity)
                    if let jsonString = String(data: jsonData, encoding: .utf8) {
                        weeklyArrays[dayOfWeek]?.append(jsonString)
                    }
                } catch {
                    print("Failed to encode activity: \(error)")
                }
            }
        
            // Save all arrays to UserDefaults efficiently
            userDefaults.set(weeklyArrays["Sunday"], forKey: "sunArray")
            userDefaults.set(weeklyArrays["Monday"], forKey: "monArray")
            userDefaults.set(weeklyArrays["Tuesday"], forKey: "tueArray")
            userDefaults.set(weeklyArrays["Wednesday"], forKey: "wedArray")
            userDefaults.set(weeklyArrays["Thursday"], forKey: "thuArray")
            userDefaults.set(weeklyArrays["Friday"], forKey: "friArray")
            userDefaults.set(weeklyArrays["Saturday"], forKey: "satArray")

            let totalWeeklyActivities = weeklyArrays.values.reduce(0) { $0 + $1.count }

        } // End autoreleasepool

        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let activitiesUpdated = Notification.Name("activitiesUpdated")
}
