//
//  ChatService.swift
//  Runaway iOS
//
//  Service for Chat API communication with AI Running Coach
//

import Foundation

class ChatService {
    // MARK: - Endpoints

    private static let chatMessageEndpoint = "/chat/message"
    private static let conversationEndpoint = "/chat/conversation"
    private static let conversationsListEndpoint = "/chat/conversations"

    // MARK: - Public Methods

    /// Send a message to the AI running coach
    static func sendMessage(
        message: String,
        conversationId: String? = nil,
        context: ChatContext? = nil
    ) async throws -> ChatResponse {
        let url = URL(string: APIConfiguration.RunawayCoach.currentBaseURL + chatMessageEndpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = APIConfiguration.RunawayCoach.requestTimeout

        // Add auth headers
        let authHeaders = await APIConfiguration.RunawayCoach.getAuthHeaders()
        for (key, value) in authHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        #if DEBUG
        if let authHeader = authHeaders["Authorization"] {
            let token = authHeader.replacingOccurrences(of: "Bearer ", with: "")
            let segments = token.components(separatedBy: ".")
            print("🔐 Chat Auth Token Info:")
            print("   Token length: \(token.count)")
            print("   Segments: \(segments.count) (should be 3 for JWT)")
            print("   First 20 chars: \(String(token.prefix(20)))...")
        } else {
            print("❌ No Authorization header found!")
        }
        #endif

        // Get current user ID from auth session
        let userId = await APIConfiguration.RunawayCoach.getCurrentAuthUserId()

        // Create request body
        let chatRequest = ChatRequest(
            message: message,
            userId: userId,
            conversationId: conversationId,
            context: context
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        request.httpBody = try encoder.encode(chatRequest)

        #if DEBUG
        print("💬 Chat API Request:")
        print("   URL: \(url)")
        print("   Message: \(message)")
        print("   User ID: \(userId ?? "nil")")
        if let conversationId = conversationId {
            print("   Conversation ID: \(conversationId)")
        }
        if let bodyData = request.httpBody,
           let bodyString = String(data: bodyData, encoding: .utf8) {
            print("   Request Body:\n\(bodyString)")
        }
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
                let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
                #if DEBUG
                print("   ✅ Chat response received")
                print("   Processing time: \(chatResponse.processingTime)s")
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
            // Try to decode error message
            if let errorResponse = try? JSONDecoder().decode(ChatResponse.self, from: data),
               let errorMessage = errorResponse.errorMessage {
                throw ChatError.serverError(errorMessage)
            }
            throw ChatError.serverError("Internal server error")

        default:
            throw ChatError.invalidResponse
        }
    }

    /// Get full conversation by ID
    static func getConversation(id: String) async throws -> Conversation {
        let url = URL(string: APIConfiguration.RunawayCoach.currentBaseURL + conversationEndpoint + "/\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = APIConfiguration.RunawayCoach.requestTimeout

        // Add auth headers
        let authHeaders = await APIConfiguration.RunawayCoach.getAuthHeaders()
        for (key, value) in authHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        #if DEBUG
        print("💬 Get Conversation Request:")
        print("   URL: \(url)")
        print("   ID: \(id)")
        #endif

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            let conversationResponse = try JSONDecoder().decode(ConversationResponse.self, from: data)
            return conversationResponse.conversation

        case 401:
            throw ChatError.unauthorized

        case 404:
            throw ChatError.notFound

        default:
            throw ChatError.invalidResponse
        }
    }

    /// List recent conversations
    static func listConversations(limit: Int = 10) async throws -> [ConversationSummary] {
        let url = URL(string: APIConfiguration.RunawayCoach.currentBaseURL + conversationsListEndpoint + "?limit=\(limit)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = APIConfiguration.RunawayCoach.requestTimeout

        // Add auth headers
        let authHeaders = await APIConfiguration.RunawayCoach.getAuthHeaders()
        for (key, value) in authHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        #if DEBUG
        print("💬 List Conversations Request:")
        print("   URL: \(url)")
        print("   Limit: \(limit)")
        #endif

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            let listResponse = try JSONDecoder().decode(ConversationsListResponse.self, from: data)
            return listResponse.conversations

        case 401:
            throw ChatError.unauthorized

        default:
            throw ChatError.invalidResponse
        }
    }

    /// Delete a conversation
    static func deleteConversation(id: String) async throws {
        let url = URL(string: APIConfiguration.RunawayCoach.currentBaseURL + conversationEndpoint + "/\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = APIConfiguration.RunawayCoach.requestTimeout

        // Add auth headers
        let authHeaders = await APIConfiguration.RunawayCoach.getAuthHeaders()
        for (key, value) in authHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        #if DEBUG
        print("💬 Delete Conversation Request:")
        print("   URL: \(url)")
        print("   ID: \(id)")
        #endif

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            _ = try JSONDecoder().decode(DeleteConversationResponse.self, from: data)
            #if DEBUG
            print("   ✅ Conversation deleted")
            #endif

        case 401:
            throw ChatError.unauthorized

        case 404:
            throw ChatError.notFound

        default:
            throw ChatError.invalidResponse
        }
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
