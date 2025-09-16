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
        updateDataManager(with: activities)
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
                updateDataManager(with: activities)
            }
            
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
    
    private func updateDataManager(with activities: [Activity]) {
        Task { @MainActor in
            DataManager.shared.handleRealtimeUpdate(activities: activities)
        }
    }
}

