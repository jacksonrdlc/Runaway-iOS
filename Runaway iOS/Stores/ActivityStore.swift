//
//  ActivityStore.swift
//  Runaway iOS
//
//  Created by Claude on 12/23/25.
//

import Foundation

// MARK: - Activity Store Protocol

protocol ActivityStoreProtocol: ObservableObject {
    var activities: [Activity] { get }
    var isLoading: Bool { get }

    func loadActivities(for userId: Int) async
    func addActivity(_ activity: Activity)
    func removeActivity(id: Int)
    func updateActivity(_ activity: Activity)
    func refreshActivities() async
}

// MARK: - Activity Store

@MainActor
final class ActivityStore: ObservableObject, ActivityStoreProtocol {

    // MARK: - Published Properties

    @Published private(set) var activities: [Activity] = []
    @Published private(set) var isLoading = false

    // MARK: - Private Properties

    private let metricsCache = ActivityMetricsCache()
    private let repository: ActivityRepositoryProtocol

    // Callbacks for other systems to respond to changes
    var onActivitiesChanged: (([Activity]) -> Void)?
    var onNewActivityAdded: ((Activity) -> Void)?

    // MARK: - Singleton

    static let shared = ActivityStore()

    // MARK: - Initialization

    init(repository: ActivityRepositoryProtocol = SupabaseActivityRepository.shared) {
        self.repository = repository
    }

    // MARK: - Data Loading

    func loadActivities(for userId: Int) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let previousCount = activities.count
            let fetchedActivities = try await repository.getActivities(userId: userId, limit: 50, offset: 0)

            print("🔍 ActivityStore: Loaded \(fetchedActivities.count) activities (previously had \(previousCount))")

            activities = fetchedActivities
            metricsCache.invalidateActivityCaches()
            onActivitiesChanged?(activities)

            // Check if we have a new activity
            if fetchedActivities.count > previousCount, let latestActivity = fetchedActivities.first {
                // Check if it's from today
                let today = Calendar.current.startOfDay(for: Date())
                let activityDate = latestActivity.activity_date ?? latestActivity.start_date
                let isFromToday = activityDate.map {
                    Calendar.current.isDate(Date(timeIntervalSince1970: $0), inSameDayAs: today)
                } ?? false

                if isFromToday {
                    onNewActivityAdded?(latestActivity)
                }
            }
        } catch {
            print("❌ ActivityStore: Failed to load activities: \(error)")
        }
    }

    func refreshActivities() async {
        guard let userId = UserSession.shared.userId else {
            print("❌ ActivityStore: No user ID available for refresh")
            return
        }

        print("🔄 ActivityStore: Refreshing activities...")
        await loadActivities(for: userId)
        print("✅ ActivityStore: Activities refreshed. Total: \(activities.count)")
    }

    // MARK: - Data Modification

    func addActivity(_ activity: Activity) {
        activities.insert(activity, at: 0)
        metricsCache.invalidateActivityCaches()
        onActivitiesChanged?(activities)
        onNewActivityAdded?(activity)
    }

    func removeActivity(id: Int) {
        activities.removeAll { $0.id == id }
        metricsCache.invalidateActivityCaches()
        onActivitiesChanged?(activities)
    }

    func updateActivity(_ activity: Activity) {
        if let index = activities.firstIndex(where: { $0.id == activity.id }) {
            activities[index] = activity
            metricsCache.invalidateActivityCaches()
            onActivitiesChanged?(activities)
        }
    }

    // MARK: - Realtime Updates

    func handleRealtimeUpdate(activities: [Activity]) {
        let previousCount = self.activities.count
        self.activities = activities
        metricsCache.invalidateActivityCaches()
        onActivitiesChanged?(activities)

        // Check for new activity
        if activities.count > previousCount, let latestActivity = activities.first {
            onNewActivityAdded?(latestActivity)
        }
    }

    // MARK: - Computed Properties

    var daysSinceLastActivity: Int {
        guard let lastActivity = activities.first?.start_date else {
            return -1
        }

        let lastActivityDate = Date(timeIntervalSince1970: lastActivity)
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfActivityDay = calendar.startOfDay(for: lastActivityDate)

        let components = calendar.dateComponents([.day], from: startOfActivityDay, to: startOfToday)
        return components.day ?? 0
    }

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

    // MARK: - Cache Management

    func clearCache() {
        metricsCache.invalidateActivityCaches()
    }
}
