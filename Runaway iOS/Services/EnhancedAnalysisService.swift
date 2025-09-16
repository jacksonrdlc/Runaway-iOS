//
//  EnhancedAnalysisService.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 7/16/25.
//

import Foundation

class EnhancedAnalysisService: ObservableObject {
    @Published var isAnalyzing = false
    @Published var analysisResults: EnhancedAnalysisResults?
    
    private let apiService = RunawayCoachAPIService()
    private let localAnalyzer = RunningAnalyzer()
    private let goalAgent = GoalRecommendationAgent()
    
    // MARK: - Comprehensive Analysis
    
    /// Performs comprehensive analysis using both API and local capabilities
    func performComprehensiveAnalysis(
        userId: String,
        activities: [Activity],
        goals: [RunningGoal],
        profile: RunnerProfile
    ) async {
        await MainActor.run {
            self.isAnalyzing = true
        }
        
        defer {
            Task { @MainActor in
                self.isAnalyzing = false
            }
        }
        
        do {
            // Try to get comprehensive API analysis first
            let apiResponse = try await apiService.analyzeRunner(
                userId: userId,
                activities: activities,
                goals: goals,
                profile: profile
            )
            
            // Combine with local analysis for enhanced results
            await localAnalyzer.analyzePerformance(activities: activities)
            let localResults = localAnalyzer.analysisResults
            
            let enhancedResults = EnhancedAnalysisResults(
                apiAnalysis: apiResponse.analysis,
                localAnalysis: localResults,
                processingTime: apiResponse.processingTime,
                lastUpdated: Date()
            )
            
            await MainActor.run {
                self.analysisResults = enhancedResults
            }
            
        } catch {
            print("API analysis failed, using local analysis: \(error)")
            
            // Fallback to local analysis
            await localAnalyzer.analyzePerformance(activities: activities)
            
            if let localResults = localAnalyzer.analysisResults {
                let enhancedResults = EnhancedAnalysisResults(
                    apiAnalysis: nil,
                    localAnalysis: localResults,
                    processingTime: 0,
                    lastUpdated: Date()
                )
                
                await MainActor.run {
                    self.analysisResults = enhancedResults
                }
            }
        }
    }
    
    // MARK: - Workout Feedback
    
    /// Get post-workout analysis and recommendations
    func getWorkoutFeedback(
        activity: Activity,
        plannedWorkout: PlannedWorkout? = nil,
        runnerProfile: RunnerProfile
    ) async throws -> WorkoutFeedbackResponse {
        return try await apiService.getWorkoutFeedback(
            activity: activity,
            plannedWorkout: plannedWorkout,
            runnerProfile: runnerProfile
        )
    }
    
    // MARK: - Pace Optimization
    
    /// Get AI-powered pace recommendations
    func getPaceOptimization(activities: [Activity]) async throws -> PaceRecommendationResponse {
        return try await apiService.getPaceRecommendations(activities: activities)
    }
    
    // MARK: - Training Plan Generation
    
    /// Generate a comprehensive training plan for a goal
    func generateTrainingPlan(
        for goal: RunningGoal,
        basedOn activities: [Activity],
        duration: Int = 12
    ) async throws -> TrainingPlanResponse {
        return try await apiService.generateTrainingPlan(
            goal: goal,
            activities: activities,
            planDurationWeeks: duration
        )
    }
    
    // MARK: - Goal Assessment
    
    /// Assess multiple goals simultaneously
    func assessGoals(
        goals: [RunningGoal],
        activities: [Activity]
    ) async throws -> GoalAssessmentResponse {
        return try await apiService.assessGoals(goals: goals, activities: activities)
    }
    
    // MARK: - Quick Insights
    
    /// Get quick performance insights
    func getQuickInsights(activities: [Activity]) async throws -> QuickInsightsResponse {
        return try await apiService.getQuickInsights(activities: activities)
    }
    
    // MARK: - Health Check
    
    /// Check API service health and availability
    func checkAPIHealth() async -> Bool {
        do {
            let health = try await apiService.healthCheck()
            return health.status == "healthy"
        } catch {
            return false
        }
    }
    
    // MARK: - Combined Analysis Methods
    
    /// Get combined local and API insights
    func getCombinedInsights(activities: [Activity]) async -> CombinedInsights {
        // Start local analysis
        let localTask = Task { () -> RunningInsights? in
            await localAnalyzer.analyzePerformance(activities: activities)
            return localAnalyzer.analysisResults?.insights
        }
        
        // Try API insights
        let apiTask = Task { () -> QuickInsights? in
            do {
                let response = try await apiService.getQuickInsights(activities: activities)
                return response.insights
            } catch {
                return nil
            }
        }
        
        // Wait for both to complete
        let localInsights = await localTask.value
        let apiInsights = await apiTask.value
        
        return CombinedInsights(
            localInsights: localInsights,
            apiInsights: apiInsights,
            timestamp: Date()
        )
    }
    
    /// Get enhanced goal analysis combining API and local capabilities
    func getEnhancedGoalAnalysis(
        goal: RunningGoal,
        activities: [Activity]
    ) async -> EnhancedGoalAnalysis {
        // Start local analysis
        let localTask = Task { () -> GoalAnalysis in
            await goalAgent.analyzeGoalAndGenerateRecommendations(
                goal: goal,
                activities: activities
            )
        }
        
        // Try API assessment
        let apiTask = Task { () -> GoalAssessment? in
            do {
                let response = try await apiService.assessGoals(
                    goals: [goal],
                    activities: activities
                )
                return response.goalAssessments.first
            } catch {
                return nil
            }
        }
        
        // Wait for both to complete
        let localAnalysis = await localTask.value
        let apiAssessment = await apiTask.value
        
        return EnhancedGoalAnalysis(
            localAnalysis: localAnalysis,
            apiAssessment: apiAssessment,
            timestamp: Date()
        )
    }
}

// MARK: - Enhanced Data Models

struct EnhancedAnalysisResults {
    let apiAnalysis: RunnerAnalysis?
    let localAnalysis: AnalysisResults?
    let processingTime: Double
    let lastUpdated: Date
    
    var hasAPIData: Bool {
        return apiAnalysis != nil
    }
    
    var hasLocalData: Bool {
        return localAnalysis != nil
    }
    
    var combinedRecommendations: [String] {
        var recommendations: [String] = []
        
        if let apiRecs = apiAnalysis?.recommendations {
            recommendations.append(contentsOf: apiRecs)
        }
        
        if let localRecs = localAnalysis?.insights.recommendations {
            recommendations.append(contentsOf: localRecs)
        }
        
        // Remove duplicates
        return Array(Set(recommendations))
    }
}

struct CombinedInsights {
    let localInsights: RunningInsights?
    let apiInsights: QuickInsights?
    let timestamp: Date
    
    var hasAPIData: Bool {
        return apiInsights != nil
    }
    
    var hasLocalData: Bool {
        return localInsights != nil
    }
    
    var bestRecommendations: [String] {
        if let apiRecs = apiInsights?.topRecommendations {
            return apiRecs
        } else if let localRecs = localInsights?.recommendations {
            return localRecs
        }
        return []
    }
    
    var consistencyScore: Double {
        return apiInsights?.consistency ?? localInsights?.consistency ?? 0.0
    }
}

struct EnhancedGoalAnalysis {
    let localAnalysis: GoalAnalysis
    let apiAssessment: GoalAssessment?
    let timestamp: Date
    
    var hasAPIData: Bool {
        return apiAssessment != nil
    }
    
    var bestProgressEstimate: Double {
        return apiAssessment?.progressPercentage ?? (localAnalysis.currentProgress * 100)
    }
    
    var combinedRecommendations: [String] {
        var recommendations: [String] = []
        
        if let apiRecs = apiAssessment?.recommendations {
            recommendations.append(contentsOf: apiRecs)
        }
        
        let localRecs = localAnalysis.recommendations.map { $0.description }
        recommendations.append(contentsOf: localRecs)
        
        return Array(Set(recommendations))
    }
    
    var feasibilityScore: Double {
        return apiAssessment?.feasibilityScore ?? (localAnalysis.projectedCompletion / 100.0)
    }
}