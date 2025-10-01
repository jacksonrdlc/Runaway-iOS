import Foundation
import UIKit
import Supabase
import BackgroundTasks
import WidgetKit

@MainActor
public final class RealtimeService: ObservableObject {
    @Published public var isConnected = false
    @Published public var lastUpdateTime: Date?
    @Published public var connectionHealth: ConnectionHealth = .unknown
    
    public enum ConnectionHealth {
        case healthy
        case degraded
        case disconnected
        case unknown
    }
    
    public static let shared = RealtimeService()
    
    private var subscription: RealtimeSubscription?
    
    private var channel: RealtimeChannelV2?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private let backgroundTaskIdentifier = "com.jackrudelic.runawayios.realtime-background"
    private var reconnectionAttempts = 0
    private let maxReconnectionAttempts = 3
    private var lastHeartbeat: Date?
    private var heartbeatTimer: Timer?
    
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
            
            await setupRealtimeSubscriptionWithRetry(userId: userId)
        }
    }
    
    // MARK: - Connection Resilience
    
    private func setupRealtimeSubscriptionWithRetry(userId: Int) async {
        for attempt in 0...maxReconnectionAttempts {
            do {
                await setupRealtimeSubscription(userId: userId)
                reconnectionAttempts = 0 // Reset on successful connection
                return
            } catch {
                print("❌ Realtime connection attempt \(attempt + 1) failed: \(error)")
                reconnectionAttempts = attempt + 1
                
                if attempt < maxReconnectionAttempts {
                    // Exponential backoff: 2^attempt seconds
                    let delay = pow(2.0, Double(attempt))
                    print("⏳ Retrying in \(delay) seconds...")
                    try? await Task.sleep(for: .seconds(Int(delay)))
                } else {
                    print("❌ Max reconnection attempts reached")
                    await MainActor.run {
                        self.isConnected = false
                    }
                }
            }
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
            self.connectionHealth = .healthy
            self.lastHeartbeat = Date()
        }
        
        // Start connection monitoring
        startConnectionMonitoring()
        
        // Listen for insertions
        Task {
            for await _ in insertions {
                print("Activity inserted - refreshing data")
                await handleRealtimeUpdate()
                await updateConnectionHealth(.healthy)
            }
        }
        
        // Listen for updates
        Task {
            for await _ in updates {
                print("Activity updated - refreshing data")
                await handleRealtimeUpdate()
                await updateConnectionHealth(.healthy)
            }
        }
        
        // Listen for deletions
        Task {
            for await _ in deletions {
                print("Activity deleted - refreshing data")
                await handleRealtimeUpdate()
                await updateConnectionHealth(.healthy)
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
        // Stop connection monitoring
        stopConnectionMonitoring()
        
        if let channel = self.channel {
            await supabase.removeChannel(channel)
            self.channel = nil
        }
        
        await MainActor.run {
            self.isConnected = false
            self.connectionHealth = .disconnected
        }
        
        print("Realtime subscription cleaned up")
    }
    
    // MARK: - Background Task Management
    
    private func registerBackgroundTask() {
        let success = BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
            print("🎯 Background task triggered: \(task.identifier)")
            self.handleBackgroundTask(task: task as! BGAppRefreshTask)
        }
        
        if success {
            print("✅ Background task registered successfully: \(backgroundTaskIdentifier)")
        } else {
            print("❌ Failed to register background task: \(backgroundTaskIdentifier)")
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
        
        // Enhanced background task with better connection management
        Task {
            if isConnected {
                // Attempt to refresh data during background execution
                await refreshActivityData()
                
                // Keep realtime connection alive for longer period
                try? await Task.sleep(for: .seconds(25)) // Increased from 10s to 25s
            } else {
                // Attempt to reconnect if not connected
                let userId = await MainActor.run { UserManager.shared.userId }
                if let userId = userId {
                    await setupRealtimeSubscription(userId: userId)
                    await refreshActivityData()
                }
            }
            task.setTaskCompleted(success: true)
        }
    }
    
    public func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        
        // Use adaptive scheduling based on user activity patterns
        let baseInterval: TimeInterval = 15 * 60 // 15 minutes base
        let adaptiveInterval = calculateAdaptiveInterval(baseInterval: baseInterval)
        
        request.earliestBeginDate = Date(timeIntervalSinceNow: adaptiveInterval)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("🔄 Background refresh scheduled for \(adaptiveInterval/60) minutes from now")
        } catch {
            print("❌ Failed to schedule background refresh: \(error)")
        }
    }
    
    private func calculateAdaptiveInterval(baseInterval: TimeInterval) -> TimeInterval {
        // Adjust interval based on connection health and recent activity
        switch connectionHealth {
        case .healthy:
            return baseInterval * 1.5 // Less frequent when healthy (22.5 min)
        case .degraded:
            return baseInterval * 0.75 // More frequent when degraded (11.25 min)
        case .disconnected:
            return baseInterval * 0.5 // Very frequent when disconnected (7.5 min)
        case .unknown:
            return baseInterval // Default interval
        }
    }
    
    // MARK: - Widget Data Management
    
    private func updateDataManager(with activities: [Activity]) {
        Task { @MainActor in
            DataManager.shared.handleRealtimeUpdate(activities: activities)
        }
    }
    
    // MARK: - Connection Monitoring
    
    private func startConnectionMonitoring() {
        MainActor.assumeIsolated {
            heartbeatTimer?.invalidate()
            heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
                Task {
                    await self?.checkConnectionHealth()
                }
            }
        }
    }
    
    private func stopConnectionMonitoring() {
        MainActor.assumeIsolated {
            heartbeatTimer?.invalidate()
            heartbeatTimer = nil
        }
    }
    
    private func checkConnectionHealth() async {
        let (lastUpdate, needsReconnection, userId): (Date?, Bool, Int?) = await MainActor.run {
            let lastUpdate = lastUpdateTime ?? lastHeartbeat
            guard let lastUpdate = lastUpdate else {
                connectionHealth = .unknown
                return (nil as Date?, false, nil as Int?)
            }

            let timeSinceLastUpdate = Date().timeIntervalSince(lastUpdate)

            if timeSinceLastUpdate < 60 { // 1 minute
                connectionHealth = .healthy
                return (lastUpdate, false, nil as Int?)
            } else if timeSinceLastUpdate < 300 { // 5 minutes
                connectionHealth = .degraded
                return (lastUpdate, false, nil as Int?)
            } else {
                connectionHealth = .disconnected
                // Return whether we need reconnection and the userId
                return (lastUpdate, isConnected, UserManager.shared.userId)
            }
        }

        // Handle reconnection outside of MainActor.run
        if needsReconnection, let userId = userId {
            await setupRealtimeSubscriptionWithRetry(userId: userId)
        }
    }
    
    private func updateConnectionHealth(_ health: ConnectionHealth) async {
        await MainActor.run {
            self.connectionHealth = health
            self.lastHeartbeat = Date()
        }
    }
}

