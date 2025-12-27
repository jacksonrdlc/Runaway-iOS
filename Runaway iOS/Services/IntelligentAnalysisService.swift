//
//  IntelligentAnalysisService.swift
//  Runaway iOS
//
//  Hybrid AI analysis service that uses on-device Apple Intelligence
//  with fallback to cloud-based API for older devices
//

import Foundation

class IntelligentAnalysisService {
    static let shared = IntelligentAnalysisService()

    private init() {}

    // MARK: - Analysis Methods

    /// Generate activity insights using hybrid approach
    /// - Tries on-device Foundation Models first (iOS 26+)
    /// - Falls back to cloud API for older devices or on failure
    func generateActivityInsights(
        activity: Activity,
        previousActivities: [Activity] = []
    ) async throws -> IntelligentActivityInsight {
        // Try on-device first if available
        if #available(iOS 26.0, *), await isFoundationModelsAvailable() {
            do {
                return try await generateInsightsOnDevice(
                    activity: activity,
                    previousActivities: previousActivities
                )
            } catch {
                print("⚠️ On-device analysis failed: \(error), falling back to cloud")
                return try await generateInsightsViaCloud(activity: activity)
            }
        } else {
            // Fallback to cloud API
            return try await generateInsightsViaCloud(activity: activity)
        }
    }

    /// Generate training suggestions
    func generateTrainingSuggestions(
        currentGoal: RunningGoal?,
        recentActivities: [Activity],
        athleteStats: AthleteStats?
    ) async throws -> String {
        if #available(iOS 26.0, *), await isFoundationModelsAvailable() {
            return try await generateSuggestionsOnDevice(
                goal: currentGoal,
                activities: recentActivities,
                stats: athleteStats
            )
        } else {
            return try await generateSuggestionsViaCloud(
                goal: currentGoal,
                activities: recentActivities
            )
        }
    }

    // MARK: - On-Device Analysis (iOS 26+)

    @available(iOS 26.0, *)
    private func isFoundationModelsAvailable() async -> Bool {
        // Check if Foundation Models framework is available and model is ready
        // Note: This would use actual FoundationModels API when available
        return false // Placeholder - will be true once framework is imported
    }

    @available(iOS 26.0, *)
    private func generateInsightsOnDevice(
        activity: Activity,
        previousActivities: [Activity]
    ) async throws -> IntelligentActivityInsight {
        // TODO: Implement when FoundationModels framework is available
        // Example implementation:
        /*
        import FoundationModels

        let model = FoundationLanguageModel.shared

        let prompt = buildActivityAnalysisPrompt(
            activity: activity,
            previousActivities: previousActivities
        )

        let response = try await model.generate(
            prompt: prompt,
            maxTokens: 150
        )

        return parseInsightFromResponse(response)
        */

        // For now, fall back to cloud
        throw AnalysisError.onDeviceNotAvailable
    }

    @available(iOS 26.0, *)
    private func generateSuggestionsOnDevice(
        goal: RunningGoal?,
        activities: [Activity],
        stats: AthleteStats?
    ) async throws -> String {
        // TODO: Implement when FoundationModels framework is available
        /*
        import FoundationModels

        let model = FoundationLanguageModel.shared

        let prompt = buildTrainingSuggestionPrompt(
            goal: goal,
            activities: activities,
            stats: stats
        )

        return try await model.generate(prompt: prompt, maxTokens: 200)
        */

        throw AnalysisError.onDeviceNotAvailable
    }

    // MARK: - Cloud API Fallback

    private func generateInsightsViaCloud(activity: Activity) async throws -> IntelligentActivityInsight {
        // Direct API call to Runaway Coach API
        guard let apiURL = URL(string: "\(APIConfiguration.RunawayCoach.baseURL)/api/activity-insights") else {
            throw AnalysisError.invalidURL
        }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "activity_id": activity.id,
            "distance": activity.distance ?? 0,
            "moving_time": activity.moving_time ?? 0,
            "average_speed": activity.average_speed ?? 0,
            "type": activity.type ?? "Run"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(IntelligentActivityInsightResponse.self, from: data)

        return IntelligentActivityInsight(
            title: response.title ?? "Performance Analysis",
            description: response.insight,
            metric: response.metric,
            comparison: response.comparison,
            recommendation: response.recommendation
        )
    }

    private func generateSuggestionsViaCloud(
        goal: RunningGoal?,
        activities: [Activity]
    ) async throws -> String {
        // Call cloud API for training suggestions
        guard let apiURL = URL(string: "\(APIConfiguration.RunawayCoach.baseURL)/api/training-suggestions") else {
            throw AnalysisError.invalidURL
        }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "goal": goal?.type.rawValue ?? "general",
            "recent_activities_count": activities.count,
            "total_distance": activities.reduce(0.0) { $0 + ($1.distance ?? 0.0) }
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(TrainingSuggestionResponse.self, from: data)

        return response.suggestions
    }

    // MARK: - Prompt Building (for on-device use)

    private func buildActivityAnalysisPrompt(
        activity: Activity,
        previousActivities: [Activity]
    ) -> String {
        let activityType = activity.type ?? "activity"
        let distance = activity.distance.map { String(format: "%.2f km", $0 / 1000) } ?? "unknown distance"
        let duration = activity.moving_time.map { formatDuration(Double($0)) } ?? "unknown duration"
        let speed = activity.average_speed.map { formatPace($0) } ?? "unknown pace"

        var prompt = """
        Analyze this \(activityType):
        - Distance: \(distance)
        - Duration: \(duration)
        - Average pace: \(speed)
        """

        if !previousActivities.isEmpty {
            let recentCount = previousActivities.prefix(5).count
            prompt += "\n\nCompared to \(recentCount) recent activities of the same type."
        }

        prompt += "\n\nProvide a brief insight (2-3 sentences) about performance and one actionable recommendation."

        return prompt
    }

    private func buildTrainingSuggestionPrompt(
        goal: RunningGoal?,
        activities: [Activity],
        stats: AthleteStats?
    ) -> String {
        var prompt = "You are a running coach AI. "

        if let goal = goal {
            prompt += "The athlete's goal is: \(goal.type.displayName). "
            prompt += "Target: \(goal.formattedTarget()). "
        }

        prompt += "Recent training summary: \(activities.count) activities in the past 30 days. "

        if let distance = stats?.distance {
            prompt += "Total distance: \(distance/1000)km. "
        }

        prompt += "\n\nProvide 2-3 specific training recommendations for the next week."

        return prompt
    }

    // MARK: - Helper Methods

    private func formatDuration(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }

    private func formatPace(_ metersPerSecond: Double) -> String {
        let minutesPerKm = (1000 / metersPerSecond) / 60
        let minutes = Int(minutesPerKm)
        let seconds = Int((minutesPerKm - Double(minutes)) * 60)
        return String(format: "%d:%02d /km", minutes, seconds)
    }

    // MARK: - Error Types

    enum AnalysisError: LocalizedError {
        case onDeviceNotAvailable
        case invalidActivityData
        case invalidResponse
        case invalidURL

        var errorDescription: String? {
            switch self {
            case .onDeviceNotAvailable:
                return "On-device analysis not available"
            case .invalidActivityData:
                return "Invalid activity data"
            case .invalidResponse:
                return "Invalid response from analysis service"
            case .invalidURL:
                return "Invalid API URL"
            }
        }
    }
}

// MARK: - Response Models

struct IntelligentActivityInsight: Codable {
    let title: String
    let description: String
    let metric: String?
    let comparison: String?
    let recommendation: String?
}

struct TrainingSuggestionResponse: Codable {
    let suggestions: String
}

struct IntelligentActivityInsightResponse: Codable {
    let title: String?
    let insight: String
    let metric: String?
    let comparison: String?
    let recommendation: String?
}
