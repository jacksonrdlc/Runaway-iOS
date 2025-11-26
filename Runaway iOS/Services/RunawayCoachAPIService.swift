//
//  RunawayCoachAPIService.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 7/16/25.
//

import Foundation

class RunawayCoachAPIService: ObservableObject {
    private let session = URLSession.shared
    private let decoder = JSONDecoder()
    private let requestManager = APIRequestManager.shared

    init() {
        decoder.dateDecodingStrategy = .iso8601
    }
    
    // MARK: - Analysis Endpoints
    
    /// Comprehensive runner analysis using AI agents
    func analyzeRunner(
        userId: String,
        activities: [Activity],
        goals: [RunningGoal],
        profile: RunnerProfile
    ) async throws -> RunnerAnalysisResponse {
        let request = RunnerAnalysisRequest(
            userId: userId,
            activities: activities.map { $0.toAPIActivity() },
            goals: goals.map { $0.toAPIGoal() },
            profile: profile.toAPIProfile()
        )
        
        return try await performRequest(
            endpoint: APIConfiguration.RunawayCoach.analyzeRunner,
            method: "POST",
            body: request,
            responseType: RunnerAnalysisResponse.self
        )
    }
    
    /// Quick performance insights without full analysis
    func getQuickInsights(activities: [Activity]) async throws -> QuickInsightsResponse {
        let requestKey = APIRequestManager.generateKeyForActivities(activities, endpoint: APIConfiguration.RunawayCoach.quickInsights)

        return try await requestManager.performRequest(
            key: requestKey,
            timeout: APIConfiguration.RunawayCoach.requestTimeout,
            request: {
                // Send activities directly as array, not wrapped in object
                let activitiesArray = activities.map { $0.toAPIActivity() }

                return try await self.performRequest(
                    endpoint: APIConfiguration.RunawayCoach.quickInsights,
                    method: "POST",
                    body: activitiesArray,
                    responseType: QuickInsightsResponse.self
                )
            }
        )
    }
    
    // MARK: - Feedback Endpoints
    
    /// Generate post-workout insights and feedback
    func getWorkoutFeedback(
        activity: Activity,
        plannedWorkout: PlannedWorkout?,
        runnerProfile: RunnerProfile
    ) async throws -> WorkoutFeedbackResponse {
        let request = WorkoutFeedbackRequest(
            activity: activity.toAPIActivity(),
            plannedWorkout: plannedWorkout?.toAPIPlannedWorkout(),
            runnerProfile: runnerProfile.toAPIProfile()
        )
        
        return try await performRequest(
            endpoint: APIConfiguration.RunawayCoach.workoutFeedback,
            method: "POST",
            body: request,
            responseType: WorkoutFeedbackResponse.self
        )
    }
    
    /// Generate pace recommendations based on recent performance
    func getPaceRecommendations(activities: [Activity]) async throws -> PaceRecommendationResponse {
        let requestKey = APIRequestManager.generateKeyForActivities(activities, endpoint: APIConfiguration.RunawayCoach.paceRecommendation)

        return try await requestManager.performRequest(
            key: requestKey,
            timeout: APIConfiguration.RunawayCoach.requestTimeout,
            request: {
                // Send activities directly as array, not wrapped in object
                let activitiesArray = activities.map { $0.toAPIActivity() }

                return try await self.performRequest(
                    endpoint: APIConfiguration.RunawayCoach.paceRecommendation,
                    method: "POST",
                    body: activitiesArray,
                    responseType: PaceRecommendationResponse.self
                )
            }
        )
    }
    
    // MARK: - Goal Management Endpoints
    
    /// Assess goal feasibility and progress
    func assessGoals(
        goals: [RunningGoal],
        activities: [Activity]
    ) async throws -> GoalAssessmentResponse {
        let request = GoalAssessmentRequest(
            goalsData: goals.map { $0.toAPIGoal() },
            activitiesData: activities.map { $0.toAPIActivity() }
        )
        
        return try await performRequest(
            endpoint: APIConfiguration.RunawayCoach.assessGoals,
            method: "POST",
            body: request,
            responseType: GoalAssessmentResponse.self
        )
    }
    
    /// Generate a comprehensive training plan for a specific goal
    func generateTrainingPlan(
        goal: RunningGoal,
        activities: [Activity],
        planDurationWeeks: Int = 12
    ) async throws -> TrainingPlanResponse {
        let request = TrainingPlanRequest(
            goalData: goal.toAPIGoal(),
            activitiesData: activities.map { $0.toAPIActivity() },
            planDurationWeeks: planDurationWeeks
        )
        
        return try await performRequest(
            endpoint: APIConfiguration.RunawayCoach.trainingPlan,
            method: "POST",
            body: request,
            responseType: TrainingPlanResponse.self
        )
    }
    
    // MARK: - Health Check
    
    func healthCheck() async throws -> HealthCheckResponse {
        return try await performRequest(
            endpoint: APIConfiguration.RunawayCoach.health,
            method: "GET",
            body: Optional<String>.none,
            responseType: HealthCheckResponse.self
        )
    }
    
    // MARK: - Private Helper Methods
    
    private func performRequest<T: Codable, R: Codable>(
        endpoint: String,
        method: String,
        body: T?,
        responseType: R.Type
    ) async throws -> R {
        guard let url = URL(string: APIConfiguration.RunawayCoach.currentBaseURL + endpoint) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = APIConfiguration.RunawayCoach.requestTimeout
        
        // Add headers from configuration (with JWT support)
        let authHeaders = await APIConfiguration.RunawayCoach.getAuthHeaders()
        for (key, value) in authHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Debug: Print request details for auth troubleshooting
        #if DEBUG
        print("🌐 API Request Debug:")
        print("   URL: \(url)")
        print("   Method: \(method)")
        print("   Headers: \(authHeaders.keys.joined(separator: ", "))")
        print("   Auth: Configured")
        #endif
        
        
        if let body = body {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let jsonData = try encoder.encode(body)
                request.httpBody = jsonData
            } catch {
                throw APIError.encodingError(error)
            }
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                // Try to parse error response
                let errorMessage = String(data: data, encoding: .utf8)
                
                // Throw specific error types based on status code
                switch httpResponse.statusCode {
                case 401:
                    throw APIError.authenticationError(errorMessage ?? "Invalid API key or authentication failed")
                case 422:
                    throw APIError.validationError(errorMessage ?? "Invalid request data")
                case 500:
                    // Check for specific server errors
                    if let errorData = errorMessage, errorData.contains("langchain_anthropic") {
                        throw APIError.serverError("Server missing langchain_anthropic dependency. Please contact API administrator.")
                    } else if let errorData = errorMessage, errorData.contains("anthropic") {
                        throw APIError.serverError("Server missing Anthropic/Claude dependencies. Please contact API administrator.")
                    } else {
                        throw APIError.serverError(errorMessage ?? "Internal server error")
                    }
                default:
                    throw APIError.httpError(httpResponse.statusCode, errorMessage)
                }
            }
            
            // Validate response if enabled
            if APIConfiguration.RunawayCoach.enableResponseValidation {
                guard APIConfiguration.RunawayCoach.validateResponse(data, responseType: responseType) else {
                    throw APIError.invalidResponse
                }
            }
            
            return try decoder.decode(responseType, from: data)
        } catch {
            if error is DecodingError {
                throw APIError.decodingError(error)
            } else {
                throw APIError.networkError(error)
            }
        }
    }
    
}

// MARK: - API Error Types

enum APIError: Error, LocalizedError {
    case invalidURL
    case encodingError(Error)
    case decodingError(Error)
    case networkError(Error)
    case httpError(Int, String?) // Status code and error message
    case invalidResponse
    case authenticationError(String) // HTTP 401 errors
    case validationError(String) // HTTP 422 errors
    case serverError(String) // HTTP 500 errors
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .encodingError(let error):
            return "Encoding error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .httpError(let statusCode, let message):
            return "HTTP error \(statusCode): \(message ?? "Unknown error")"
        case .invalidResponse:
            return "Invalid response"
        case .authenticationError(let message):
            return "Authentication error: \(message)"
        case .validationError(let message):
            return "Validation error: \(message)"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}