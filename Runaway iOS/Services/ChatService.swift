//
//  ChatService.swift
//  Runaway iOS
//
//  Service for Chat with AI Running Coach
//  iOS 26+: Uses on-device Apple Foundation Models
//  iOS <26: AI features disabled (no cloud fallback by design)
//

import Foundation

class ChatService {
    // MARK: - On-Device AI Check

    /// Check if on-device AI is available (iOS 26+)
    @MainActor
    static var isOnDeviceAIAvailable: Bool {
        FoundationModelsService.shared.isAvailable
    }

    // MARK: - Public Methods

    /// Send a message to the AI running coach
    /// Uses on-device AI on iOS 26+, throws error on older versions
    static func sendMessage(
        message: String,
        conversationId: String? = nil,
        context: ChatContext? = nil
    ) async throws -> ChatResponse {
        // Check if on-device AI is available
        let foundationModelsService = await MainActor.run {
            FoundationModelsService.shared
        }

        let isAvailable = await MainActor.run {
            foundationModelsService.isAvailable
        }

        guard isAvailable else {
            // No cloud fallback - require iOS 26 upgrade
            throw ChatError.requiresiOS26
        }

        #if DEBUG
        print("💬 Chat Request (On-Device AI):")
        print("   Message: \(message)")
        #endif

        // Build athlete context for personalized responses
        let athleteContext = await buildAthleteContext()
        let recentActivities = await buildRecentActivities()

        do {
            // Use on-device Foundation Models
            let response = try await foundationModelsService.generateCoachResponse(
                message: message,
                athleteContext: athleteContext,
                recentActivities: recentActivities
            )

            #if DEBUG
            print("   ✅ On-device response received")
            print("   Response length: \(response.count) characters")
            #endif

            return ChatResponse(
                success: true,
                message: response,
                conversationId: conversationId ?? UUID().uuidString,
                triggeredAnalysis: nil,
                errorMessage: nil,
                processingTime: 0.0,
                isOnDevice: true
            )

        } catch let error as FoundationModelsError {
            #if DEBUG
            print("   ❌ Foundation Models error: \(error.localizedDescription)")
            #endif

            if error.requiresUpgrade {
                throw ChatError.requiresiOS26
            }
            throw ChatError.onDeviceError(error)
        }
    }

    // MARK: - On-Device Context Builders

    @MainActor
    private static func buildAthleteContext() -> AthleteContext? {
        let dataManager = DataManager.shared
        let activities = dataManager.activities

        // Calculate weekly mileage
        let weeklyMileage = calculateWeeklyMileage(from: activities)

        // Get current goal
        let currentGoal = dataManager.currentGoal?.type.displayName

        return AthleteContext(
            weeklyMileage: weeklyMileage,
            currentGoal: currentGoal,
            fitnessLevel: nil
        )
    }

    @MainActor
    private static func buildRecentActivities() -> [ActivitySummary]? {
        let activities = DataManager.shared.activities

        // Filter to only include actual running activities with meaningful distance
        let runningActivities = activities.filter { activity in
            // Must have distance > 0 (at least 0.1 miles = ~160 meters)
            guard let distance = activity.distance, distance > 160 else {
                return false
            }

            // Must be a running activity type
            guard let activityType = activity.type?.lowercased() else {
                return false
            }

            // Include runs, walks, hikes - common endurance activities
            let validTypes = ["run", "running", "walk", "walking", "hike", "hiking", "trail run"]
            return validTypes.contains { activityType.contains($0) }
        }

        guard !runningActivities.isEmpty else { return nil }

        return runningActivities.prefix(5).map { ActivitySummary(from: $0) }
    }

    /// Get full conversation by ID (Not yet implemented in new backend)
    static func getConversation(id: String) async throws -> Conversation {
        // TODO: Implement conversation storage in new backend
        // For now, return empty conversation
        let now = ISO8601DateFormatter().string(from: Date())
        return Conversation(
            id: id,
            userId: "",
            messages: [],
            context: nil,
            createdAt: now,
            updatedAt: now
        )
    }

    /// List recent conversations (Not yet implemented in new backend)
    static func listConversations(limit: Int = 10) async throws -> [ConversationSummary] {
        // TODO: Implement conversation list in new backend
        // For now, return empty list
        return []
    }

    /// Delete a conversation (Not yet implemented in new backend)
    static func deleteConversation(id: String) async throws {
        // TODO: Implement conversation deletion in new backend
        // For now, do nothing
        return
    }

    // MARK: - Context Builders

    /// Build chat context from current app state
    static func buildContext(
        from activities: [Activity],
        goal: RunningGoal? = nil,
        athlete: Athlete? = nil
    ) -> ChatContext {
        // Filter to only meaningful running activities
        let filteredActivities = activities.filter { activity in
            guard let distance = activity.distance, distance > 160 else { return false }
            guard let activityType = activity.type?.lowercased() else { return false }
            let validTypes = ["run", "running", "walk", "walking", "hike", "hiking", "trail run"]
            return validTypes.contains { activityType.contains($0) }
        }

        // Recent activity (last run)
        let recentActivity = filteredActivities.first.flatMap { activity -> RecentActivityContext? in
            guard let distance = activity.distance,
                  let speed = activity.average_speed,
                  let dateInterval = activity.activity_date ?? activity.start_date else {
                return nil
            }

            let miles = distance * 0.000621371
            let pace = calculatePace(from: speed)
            let date = Date(timeIntervalSince1970: dateInterval)

            return RecentActivityContext(
                distance: miles,
                avgPace: formatPace(pace),
                duration: activity.moving_time,
                date: ISO8601DateFormatter().string(from: date),
                heartRateAvg: activity.average_heart_rate,
                elevationGain: activity.elevation_gain
            )
        }

        // Recent activities (last 10)
        let activityContexts = filteredActivities.prefix(10).compactMap { activity -> ActivityContext? in
            guard let distance = activity.distance,
                  let speed = activity.average_speed,
                  let dateInterval = activity.activity_date ?? activity.start_date else {
                return nil
            }

            let miles = distance * 0.000621371
            let pace = calculatePace(from: speed)
            let date = Date(timeIntervalSince1970: dateInterval)

            return ActivityContext(
                distance: miles,
                avgPace: formatPace(pace),
                date: ISO8601DateFormatter().string(from: date)
            )
        }

        // Weekly mileage
        let weeklyMileage = calculateWeeklyMileage(from: activities)

        // Goal context
        let goalContext = goal.flatMap { goal -> GoalContext? in
            let distance = goal.type == .distance ? goal.formattedTarget() : nil
            let targetTime = goal.type == .time ? goal.formattedTarget() : nil

            return GoalContext(
                type: goal.type.rawValue,
                distance: distance,
                targetTime: targetTime,
                raceDate: ISO8601DateFormatter().string(from: goal.deadline)
            )
        }

        // Profile context
        let profileContext: ProfileContext? = nil  // TODO: Add profile data when available

        return ChatContext(
            recentActivity: recentActivity,
            activities: activityContexts.isEmpty ? nil : activityContexts,
            weeklyMileage: weeklyMileage,
            goal: goalContext,
            profile: profileContext
        )
    }

    // MARK: - Private Helpers

    private static func calculatePace(from speed: Double) -> Double {
        guard speed > 0 else { return 0 }
        let milesPerHour = speed * 2.23694
        let minutesPerMile = 60.0 / milesPerHour
        return minutesPerMile
    }

    private static func formatPace(_ pace: Double) -> String {
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }

    private static func calculateWeeklyMileage(from activities: [Activity]) -> Double? {
        let calendar = Calendar.current
        let now = Date()
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) else {
            return nil
        }

        let weeklyActivities = activities.filter { activity in
            guard let dateInterval = activity.activity_date ?? activity.start_date else {
                return false
            }
            let activityDate = Date(timeIntervalSince1970: dateInterval)
            return activityDate >= weekAgo
        }

        let totalMeters = weeklyActivities.compactMap { $0.distance }.reduce(0, +)
        return totalMeters * 0.000621371  // Convert to miles
    }
}
