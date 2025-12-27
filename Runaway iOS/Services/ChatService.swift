//
//  ChatService.swift
//  Runaway iOS
//
//  Service for Chat API communication with AI Running Coach
//

import Foundation

class ChatService {
    // MARK: - Endpoints

    // Supabase Edge Functions (Migrated from Cloud Run)
    #if DEBUG
    private static let stravaDataBaseURL = "http://localhost:54321"  // Local Supabase development
    #else
    private static let stravaDataBaseURL = "https://nkxvjcdxiyjbndjvfmqy.supabase.co"  // Production Supabase
    #endif
    private static let chatEndpoint = "/functions/v1/chat"

    // MARK: - Public Methods

    /// Send a message to the AI running coach (New Backend)
    static func sendMessage(
        message: String,
        conversationId: String? = nil,
        context: ChatContext? = nil
    ) async throws -> ChatResponse {
        // Use new strava-data chat API
        let url = URL(string: stravaDataBaseURL + chatEndpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30.0

        // Add auth headers (kept for compatibility)
        let authHeaders = await APIConfiguration.RunawayCoach.getAuthHeaders()
        for (key, value) in authHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Get athlete ID from DataManager
        let athleteId = await MainActor.run {
            DataManager.shared.athlete?.id ?? 94451852 // Fallback to known ID
        }

        // Create request body for new API (simplified format)
        var requestBody: [String: Any] = [
            "athlete_id": athleteId,
            "message": message
        ]

        // Include conversation_id if provided (for multi-turn conversations)
        if let conversationId = conversationId {
            requestBody["conversation_id"] = conversationId
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        #if DEBUG
        print("💬 Chat API Request (New Backend):")
        print("   URL: \(url)")
        print("   Athlete ID: \(athleteId)")
        print("   Message: \(message)")
        #endif

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatError.invalidResponse
        }

        #if DEBUG
        print("   Response Code: \(httpResponse.statusCode)")
        #endif

        switch httpResponse.statusCode {
        case 200:
            do {
                // New API response format
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let answer = json?["answer"] as? String else {
                    throw ChatError.decodingError(NSError(domain: "ChatService", code: -1))
                }

                // Extract conversation_id from response (returned by backend for threading)
                let returnedConversationId = json?["conversation_id"] as? String ?? UUID().uuidString

                // Convert to existing ChatResponse format
                let chatResponse = ChatResponse(
                    success: true,
                    message: answer,
                    conversationId: returnedConversationId,
                    triggeredAnalysis: nil,
                    errorMessage: nil,
                    processingTime: 0.0
                )

                #if DEBUG


                print("   ✅ Chat response received from new backend")
                print("   Answer length: \(answer.count) characters")
                print("   Conversation ID: \(returnedConversationId)")
                #endif
                return chatResponse
            } catch {
                #if DEBUG
                print("   ❌ Decoding error: \(error)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("   Raw Response: \(jsonString)")
                }
                #endif
                throw ChatError.decodingError(error)
            }

        case 401:
            throw ChatError.unauthorized

        case 404:
            throw ChatError.notFound

        case 500:
            throw ChatError.serverError("Internal server error")

        default:
            throw ChatError.invalidResponse
        }
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
        // Recent activity (last run)
        let recentActivity = activities.first.flatMap { activity -> RecentActivityContext? in
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
        let activityContexts = activities.prefix(10).compactMap { activity -> ActivityContext? in
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
