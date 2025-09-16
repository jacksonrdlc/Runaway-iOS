//
//  APIModels.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 7/16/25.
//

import Foundation

// MARK: - Request Models

struct RunnerAnalysisRequest: Codable {
    let userId: String
    let activities: [APIActivity]
    let goals: [APIGoal]
    let profile: APIRunnerProfile
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case activities
        case goals
        case profile
    }
}

struct QuickInsightsRequest: Codable {
    let activitiesData: [APIActivity]
    
    enum CodingKeys: String, CodingKey {
        case activitiesData = "activities_data"
    }
}

struct WorkoutFeedbackRequest: Codable {
    let activity: APIActivity
    let plannedWorkout: APIPlannedWorkout?
    let runnerProfile: APIRunnerProfile
    
    enum CodingKeys: String, CodingKey {
        case activity
        case plannedWorkout = "planned_workout"
        case runnerProfile = "runner_profile"
    }
}

struct PaceRecommendationRequest: Codable {
    let activitiesData: [APIActivity]
    
    enum CodingKeys: String, CodingKey {
        case activitiesData = "activities_data"
    }
}

struct GoalAssessmentRequest: Codable {
    let goalsData: [APIGoal]
    let activitiesData: [APIActivity]
    
    enum CodingKeys: String, CodingKey {
        case goalsData = "goals_data"
        case activitiesData = "activities_data"
    }
}

struct TrainingPlanRequest: Codable {
    let goalData: APIGoal
    let activitiesData: [APIActivity]
    let planDurationWeeks: Int
    
    enum CodingKeys: String, CodingKey {
        case goalData = "goal_data"
        case activitiesData = "activities_data"
        case planDurationWeeks = "plan_duration_weeks"
    }
}

// MARK: - Response Models

struct RunnerAnalysisResponse: Codable {
    let success: Bool
    let analysis: RunnerAnalysis
    let processingTime: Double
    
    enum CodingKeys: String, CodingKey {
        case success
        case analysis
        case processingTime = "processing_time"
    }
}

struct QuickInsightsResponse: Codable {
    let success: Bool
    let insights: QuickInsights
}

struct WorkoutFeedbackResponse: Codable {
    let success: Bool
    let insights: WorkoutInsights
    let processingTime: Double
    
    enum CodingKeys: String, CodingKey {
        case success
        case insights
        case processingTime = "processing_time"
    }
}

struct PaceRecommendationResponse: Codable {
    let success: Bool
    let paceOptimization: PaceOptimization
    
    enum CodingKeys: String, CodingKey {
        case success
        case paceOptimization = "pace_optimization"
    }
}

struct GoalAssessmentResponse: Codable {
    let success: Bool
    let goalAssessments: [GoalAssessment]
    
    enum CodingKeys: String, CodingKey {
        case success
        case goalAssessments = "goal_assessments"
    }
}

struct TrainingPlanResponse: Codable {
    let success: Bool
    let trainingPlan: TrainingPlan
    
    enum CodingKeys: String, CodingKey {
        case success
        case trainingPlan = "training_plan"
    }
}

struct HealthCheckResponse: Codable {
    let status: String
    let agents: AgentStatus
    let timestamp: Date
}

// MARK: - Core Data Models

struct APIActivity: Codable {
    let id: String
    let type: String
    let distance: Double
    let duration: Int // seconds
    let avgPace: String // MM:SS format
    let date: Date
    let heartRateAvg: Int?
    let elevationGain: Double?
    
    enum CodingKeys: String, CodingKey {
        case id, type, distance, duration, date
        case avgPace = "avg_pace"
        case heartRateAvg = "heart_rate_avg"
        case elevationGain = "elevation_gain"
    }
}

struct APIGoal: Codable {
    let id: String
    let type: String
    let target: String
    let deadline: Date
    let currentBest: String?
    
    enum CodingKeys: String, CodingKey {
        case id, type, target, deadline
        case currentBest = "current_best"
    }
}

struct APIRunnerProfile: Codable {
    let userId: String
    let age: Int
    let gender: String
    let experienceLevel: String
    let weeklyMileage: Double
    let bestTimes: [String: String]
    let preferences: RunnerPreferences
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case age, gender
        case experienceLevel = "experience_level"
        case weeklyMileage = "weekly_mileage"
        case bestTimes = "best_times"
        case preferences
    }
}

struct RunnerPreferences: Codable {
    let preferredWorkoutTypes: [String]
    let daysPerWeek: Int
    
    enum CodingKeys: String, CodingKey {
        case preferredWorkoutTypes = "preferred_workout_types"
        case daysPerWeek = "days_per_week"
    }
}

struct APIPlannedWorkout: Codable {
    let type: String
    let targetPace: String
    let targetDistance: Double
    
    enum CodingKeys: String, CodingKey {
        case type
        case targetPace = "target_pace"
        case targetDistance = "target_distance"
    }
}

// MARK: - Analysis Result Models

struct RunnerAnalysis: Codable {
    let performanceMetrics: PerformanceMetrics
    let recommendations: [String]
    let aiInsights: String
    let agentMetadata: AgentMetadata
    
    enum CodingKeys: String, CodingKey {
        case performanceMetrics = "performance_metrics"
        case recommendations
        case aiInsights = "ai_insights"
        case agentMetadata = "agent_metadata"
    }
}

struct PerformanceMetrics: Codable {
    let weeklyMileage: Double
    let avgPace: String
    let consistencyScore: Double
    
    enum CodingKeys: String, CodingKey {
        case weeklyMileage = "weekly_mileage"
        case avgPace = "avg_pace"
        case consistencyScore = "consistency_score"
    }
}

struct AgentMetadata: Codable {
    let agentsUsed: [String]
    let processingTime: Double
    let llmAvailable: Bool
    let modelUsed: String
    
    enum CodingKeys: String, CodingKey {
        case agentsUsed = "agents_used"
        case processingTime = "processing_time"
        case llmAvailable = "llm_available"
        case modelUsed = "model_used"
    }
}

struct QuickInsights: Codable {
    let performanceTrend: String
    let weeklyMileage: Double
    let consistency: Double
    let keyStrengths: [String]
    let topRecommendations: [String]
    
    enum CodingKeys: String, CodingKey {
        case performanceTrend = "performance_trend"
        case weeklyMileage = "weekly_mileage"
        case consistency
        case keyStrengths = "key_strengths"
        case topRecommendations = "top_recommendations"
    }
}

struct WorkoutInsights: Codable {
    let performanceRating: Double
    let effortLevel: String
    let recommendations: [String]
    let nextWorkoutSuggestions: [String]
    
    enum CodingKeys: String, CodingKey {
        case performanceRating = "performance_rating"
        case effortLevel = "effort_level"
        case recommendations
        case nextWorkoutSuggestions = "next_workout_suggestions"
    }
}

struct PaceOptimization: Codable {
    let currentFitnessLevel: String
    let recommendedPaces: [RecommendedPace]
    let weeklyPaceDistribution: WeeklyPaceDistribution
    
    enum CodingKeys: String, CodingKey {
        case currentFitnessLevel = "current_fitness_level"
        case recommendedPaces = "recommended_paces"
        case weeklyPaceDistribution = "weekly_pace_distribution"
    }
}

struct RecommendedPace: Codable {
    let paceType: String
    let targetPace: String
    let paceRange: String
    let description: String
    let heartRateZone: String
    
    enum CodingKeys: String, CodingKey {
        case paceType = "pace_type"
        case targetPace = "target_pace"
        case paceRange = "pace_range"
        case description
        case heartRateZone = "heart_rate_zone"
    }
}

struct WeeklyPaceDistribution: Codable {
    let easy: Double
    let tempo: Double
    let interval: Double
}

struct GoalAssessment: Codable {
    let goalId: String
    let goalType: String
    let currentStatus: String
    let progressPercentage: Double
    let feasibilityScore: Double
    let recommendations: [String]
    let timelineAdjustments: [String]
    let keyMetrics: KeyMetrics
    
    enum CodingKeys: String, CodingKey {
        case goalId = "goal_id"
        case goalType = "goal_type"
        case currentStatus = "current_status"
        case progressPercentage = "progress_percentage"
        case feasibilityScore = "feasibility_score"
        case recommendations
        case timelineAdjustments = "timeline_adjustments"
        case keyMetrics = "key_metrics"
    }
}

struct KeyMetrics: Codable {
    let currentPace: String
    let targetPace: String
    let weeklyMileage: Double
    let targetMileage: Double
    
    enum CodingKeys: String, CodingKey {
        case currentPace = "current_pace"
        case targetPace = "target_pace"
        case weeklyMileage = "weekly_mileage"
        case targetMileage = "target_mileage"
    }
}

struct TrainingPlan: Codable {
    let goal: TrainingGoal
    let durationWeeks: Int
    let weeklySchedule: [WeeklySchedule]
    
    enum CodingKeys: String, CodingKey {
        case goal
        case durationWeeks = "duration_weeks"
        case weeklySchedule = "weekly_schedule"
    }
}

struct TrainingGoal: Codable {
    let type: String
    let target: String
}

struct WeeklySchedule: Codable {
    let week: Int
    let workouts: [Workout]
}

struct Workout: Codable {
    let workoutType: String
    let durationMinutes: Int
    let distanceKm: Double
    let targetPace: String
    let description: String
    let scheduledDate: Date
    
    enum CodingKeys: String, CodingKey {
        case workoutType = "workout_type"
        case durationMinutes = "duration_minutes"
        case distanceKm = "distance_km"
        case targetPace = "target_pace"
        case description
        case scheduledDate = "scheduled_date"
    }
}

struct AgentStatus: Codable {
    let supervisor: String
    let performance: String
    let goal: String
    let workout: String
    let pace: String
}

// MARK: - Extension to Convert Local Models to API Models

extension Activity {
    func toAPIActivity() -> APIActivity {
        // Calculate pace from distance and time
        let pace = calculatePace()
        let avgPaceString = formatPace(pace: pace)
        
        return APIActivity(
            id: String(self.id),
            type: self.type ?? "run",
            distance: self.distance ?? 0.0,
            duration: Int(self.elapsed_time ?? 0),
            avgPace: avgPaceString,
            date: Date(timeIntervalSince1970: self.start_date ?? 0),
            heartRateAvg: nil, // Not available in base Activity model
            elevationGain: nil // Not available in base Activity model
        )
    }
    
    private func calculatePace() -> Double? {
        guard let distance = self.distance,
              let time = self.elapsed_time,
              distance > 0 else { return nil }
        
        let miles = distance * 0.000621371 // Convert meters to miles
        let minutes = time / 60.0 // Convert seconds to minutes
        return minutes / miles // minutes per mile
    }
    
    private func formatPace(pace: Double?) -> String {
        guard let pace = pace else { return "0:00" }
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
}

extension RunningGoal {
    func toAPIGoal() -> APIGoal {
        return APIGoal(
            id: self.id?.description ?? UUID().uuidString,
            type: self.type.rawValue,
            target: self.formattedTarget(),
            deadline: self.deadline,
            currentBest: self.currentProgress > 0 ? String(self.currentProgress) : nil
        )
    }
}

extension RunnerProfile {
    func toAPIProfile() -> APIRunnerProfile {
        return APIRunnerProfile(
            userId: self.userId,
            age: self.age,
            gender: self.gender,
            experienceLevel: self.experienceLevel,
            weeklyMileage: self.weeklyMileage,
            bestTimes: self.bestTimes,
            preferences: RunnerPreferences(
                preferredWorkoutTypes: self.preferredWorkoutTypes,
                daysPerWeek: self.daysPerWeek
            )
        )
    }
}

extension PlannedWorkout {
    func toAPIPlannedWorkout() -> APIPlannedWorkout {
        return APIPlannedWorkout(
            type: self.type,
            targetPace: self.targetPace,
            targetDistance: self.targetDistance
        )
    }
}

// MARK: - Supporting Models (if not already defined)

struct RunnerProfile {
    let userId: String
    let age: Int
    let gender: String
    let experienceLevel: String
    let weeklyMileage: Double
    let bestTimes: [String: String]
    let preferredWorkoutTypes: [String]
    let daysPerWeek: Int
}

struct PlannedWorkout {
    let type: String
    let targetPace: String
    let targetDistance: Double
}