//
//  GoalRecommendationAgent.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 6/28/25.
//

import Foundation

class GoalRecommendationAgent: ObservableObject {
    @Published var isAnalyzing = false
    
    private let apiService = RunawayCoachAPIService()
    
    // MARK: - Main Analysis Function
    func analyzeGoalAndGenerateRecommendations(
        goal: RunningGoal,
        activities: [Activity]
    ) async -> GoalAnalysis {
        await MainActor.run {
            self.isAnalyzing = true
        }
        
        defer {
            Task { @MainActor in
                self.isAnalyzing = false
            }
        }
        
        // Try to use the agentic API first, fallback to local analysis
        do {
            let apiResponse = try await apiService.assessGoals(
                goals: [goal],
                activities: activities
            )
            
            if let assessment = apiResponse.goalAssessments.first {
                return convertAPIAssessmentToGoalAnalysis(assessment: assessment, goal: goal)
            }
        } catch {
            print("API analysis failed, falling back to local analysis: \(error)")
        }
        
        // Fallback to local analysis
        return await performLocalAnalysis(goal: goal, activities: activities)
    }
    
    // MARK: - API-Enhanced Analysis
    private func convertAPIAssessmentToGoalAnalysis(
        assessment: GoalAssessment,
        goal: RunningGoal
    ) -> GoalAnalysis {
        let progress = assessment.progressPercentage / 100.0
        let projectedCompletion = assessment.feasibilityScore * 100.0
        
        let recommendations = assessment.recommendations.map { recommendation in
            TrainingRecommendation(
                runNumber: 1,
                distance: 5.0, // Default values, could be enhanced
                targetPace: 7.0,
                description: recommendation,
                reasoning: "AI-powered recommendation based on comprehensive analysis"
            )
        }
        
        // Generate progress points based on current status
        let progressPoints = generateProgressTrajectoryFromAPI(
            goal: goal,
            currentProgress: progress,
            assessment: assessment
        )
        
        return GoalAnalysis(
            goal: goal,
            currentProgress: progress,
            projectedCompletion: projectedCompletion,
            isOnTrack: assessment.currentStatus == "on_track",
            recommendations: recommendations,
            progressPoints: progressPoints
        )
    }
    
    private func generateProgressTrajectoryFromAPI(
        goal: RunningGoal,
        currentProgress: Double,
        assessment: GoalAssessment
    ) -> [GoalProgressPoint] {
        let weeksRemaining = Int(ceil(goal.weeksRemaining))
        var progressPoints: [GoalProgressPoint] = []
        
        let currentDate = Date()
        
        // Generate weekly progress points based on API assessment
        for week in 0...weeksRemaining {
            let weekDate = Calendar.current.date(byAdding: .weekOfYear, value: week, to: currentDate) ?? currentDate
            
            // Use feasibility score to project realistic progress
            let targetProgress = currentProgress + ((assessment.feasibilityScore / 100.0) - currentProgress) * (Double(week) / Double(weeksRemaining))
            let actualProgress = week == 0 ? currentProgress : targetProgress * 0.95 // Slightly conservative
            
            progressPoints.append(GoalProgressPoint(
                date: weekDate,
                actualProgress: actualProgress,
                targetProgress: targetProgress,
                weekNumber: week
            ))
        }
        
        return progressPoints
    }
    
    // MARK: - Local Analysis Fallback
    private func performLocalAnalysis(goal: RunningGoal, activities: [Activity]) async -> GoalAnalysis {
        // Process activities for analysis
        let processedActivities = preprocessActivities(activities)
        
        // Calculate current performance metrics
        let currentMetrics = calculateCurrentPerformance(activities: processedActivities)
        
        // Assess progress toward goal
        let progress = calculateGoalProgress(goal: goal, currentMetrics: currentMetrics, activities: processedActivities)
        
        // Generate training recommendations
        let recommendations = generateTrainingRecommendations(
            goal: goal,
            currentMetrics: currentMetrics,
            progress: progress
        )
        
        // Generate progress trajectory
        let progressPoints = generateProgressTrajectory(
            goal: goal,
            currentMetrics: currentMetrics,
            activities: processedActivities
        )
        
        // Calculate projected completion
        let projectedCompletion = calculateProjectedCompletion(
            goal: goal,
            currentMetrics: currentMetrics,
            progressPoints: progressPoints
        )
        
        return GoalAnalysis(
            goal: goal,
            currentProgress: progress,
            projectedCompletion: projectedCompletion,
            isOnTrack: projectedCompletion >= 90.0,
            recommendations: recommendations,
            progressPoints: progressPoints
        )
    }
    
    // MARK: - Current Performance Analysis
    private func calculateCurrentPerformance(activities: [ProcessedActivity]) -> CurrentPerformanceMetrics {
        let runningActivities = activities.filter { $0.type.lowercased().contains("run") }
        
        guard !runningActivities.isEmpty else {
            return CurrentPerformanceMetrics(
                averagePace: 10.0,
                weeklyMileage: 0.0,
                longestRun: 0.0,
                consistency: 0.0,
                recentTrend: .stable
            )
        }
        
        // Calculate average pace (last 5 runs for recency)
        let recentRuns = Array(runningActivities.suffix(5))
        let averagePace = recentRuns.reduce(0) { $0 + $1.pace } / Double(recentRuns.count)
        
        // Calculate weekly mileage (last 4 weeks)
        let fourWeeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -4, to: Date()) ?? Date()
        let recentActivities = runningActivities.filter { $0.date >= fourWeeksAgo }
        let weeklyMileage = recentActivities.reduce(0) { $0 + $1.distance } / 4.0
        
        // Find longest run in last 8 weeks
        let eightWeeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -8, to: Date()) ?? Date()
        let longestRun = runningActivities
            .filter { $0.date >= eightWeeksAgo }
            .map { $0.distance }
            .max() ?? 0.0
        
        // Calculate consistency (percentage of weeks with at least one run)
        let consistency = calculateRunningConsistency(activities: runningActivities)
        
        // Determine recent trend
        let recentTrend = calculatePerformanceTrend(activities: runningActivities)
        
        return CurrentPerformanceMetrics(
            averagePace: averagePace,
            weeklyMileage: weeklyMileage,
            longestRun: longestRun,
            consistency: consistency,
            recentTrend: recentTrend
        )
    }
    
    // MARK: - Goal Progress Calculation
    private func calculateGoalProgress(
        goal: RunningGoal,
        currentMetrics: CurrentPerformanceMetrics,
        activities: [ProcessedActivity]
    ) -> Double {
        switch goal.type {
        case .distance:
            // For distance goals, compare longest recent run to target
            return min(currentMetrics.longestRun / goal.targetValue, 1.0)
            
        case .time:
            // For time goals, estimate based on current longest run and pace
            let estimatedTimeCapability = currentMetrics.longestRun * currentMetrics.averagePace
            return min(estimatedTimeCapability / goal.targetValue, 1.0)
            
        case .pace:
            // For pace goals, compare current average pace to target
            // Note: Lower pace is better, so we invert the calculation
            if currentMetrics.averagePace <= goal.targetValue {
                return 1.0 // Already achieved or better
            } else {
                let improvement = (currentMetrics.averagePace - goal.targetValue) / currentMetrics.averagePace
                return max(1.0 - improvement, 0.0)
            }
        }
    }
    
    // MARK: - Training Recommendations Generation
    private func generateTrainingRecommendations(
        goal: RunningGoal,
        currentMetrics: CurrentPerformanceMetrics,
        progress: Double
    ) -> [TrainingRecommendation] {
        switch goal.type {
        case .distance:
            return generateDistanceGoalRecommendations(goal: goal, currentMetrics: currentMetrics)
        case .time:
            return generateTimeGoalRecommendations(goal: goal, currentMetrics: currentMetrics)
        case .pace:
            return generatePaceGoalRecommendations(goal: goal, currentMetrics: currentMetrics)
        }
    }
    
    private func generateDistanceGoalRecommendations(
        goal: RunningGoal,
        currentMetrics: CurrentPerformanceMetrics
    ) -> [TrainingRecommendation] {
        let targetDistance = goal.targetValue
        let currentLongest = currentMetrics.longestRun
        let weeksRemaining = max(goal.weeksRemaining, 1.0)
        
        // Calculate progressive build-up
        let distanceGap = max(targetDistance - currentLongest, 0)
        let weeklyIncrease = min(distanceGap / weeksRemaining, currentLongest * 0.1) // Max 10% increase per week
        
        var recommendations: [TrainingRecommendation] = []
        
        // Recommendation 1: Base building run
        let baseDistance = currentLongest + weeklyIncrease * 0.5
        recommendations.append(TrainingRecommendation(
            runNumber: 1,
            distance: baseDistance,
            targetPace: currentMetrics.averagePace + 0.5, // Slightly easier pace
            description: "Base Building Run",
            reasoning: "Build aerobic capacity with a comfortable, sustainable pace"
        ))
        
        // Recommendation 2: Tempo run
        let tempoDistance = max(baseDistance * 0.6, 3.0)
        recommendations.append(TrainingRecommendation(
            runNumber: 2,
            distance: tempoDistance,
            targetPace: currentMetrics.averagePace - 0.3, // Slightly faster pace
            description: "Tempo Run",
            reasoning: "Improve lactate threshold and goal race pace"
        ))
        
        // Recommendation 3: Long run progression
        let longDistance = min(currentLongest + weeklyIncrease, targetDistance)
        recommendations.append(TrainingRecommendation(
            runNumber: 3,
            distance: longDistance,
            targetPace: currentMetrics.averagePace + 0.3, // Conversational pace
            description: "Progressive Long Run",
            reasoning: "Build endurance gradually toward your distance goal"
        ))
        
        return recommendations
    }
    
    private func generateTimeGoalRecommendations(
        goal: RunningGoal,
        currentMetrics: CurrentPerformanceMetrics
    ) -> [TrainingRecommendation] {
        let targetTimeMinutes = goal.targetValue
        let estimatedDistance = targetTimeMinutes / currentMetrics.averagePace
        
        var recommendations: [TrainingRecommendation] = []
        
        // Recommendation 1: Time-based tempo run
        recommendations.append(TrainingRecommendation(
            runNumber: 1,
            distance: estimatedDistance * 0.5,
            targetPace: currentMetrics.averagePace - 0.2,
            description: "Time Trial Tempo",
            reasoning: "Practice sustaining your goal pace for extended periods"
        ))
        
        // Recommendation 2: Interval training
        recommendations.append(TrainingRecommendation(
            runNumber: 2,
            distance: estimatedDistance * 0.3,
            targetPace: currentMetrics.averagePace - 0.5,
            description: "Speed Intervals",
            reasoning: "Improve VO2 max and speed to make goal pace feel easier"
        ))
        
        // Recommendation 3: Goal pace run
        recommendations.append(TrainingRecommendation(
            runNumber: 3,
            distance: estimatedDistance * 0.8,
            targetPace: targetTimeMinutes / estimatedDistance,
            description: "Goal Pace Practice",
            reasoning: "Practice running at your target pace to build confidence"
        ))
        
        return recommendations
    }
    
    private func generatePaceGoalRecommendations(
        goal: RunningGoal,
        currentMetrics: CurrentPerformanceMetrics
    ) -> [TrainingRecommendation] {
        let targetPace = goal.targetValue
        let paceImprovement = currentMetrics.averagePace - targetPace
        
        var recommendations: [TrainingRecommendation] = []
        
        // Recommendation 1: Progressive pace run
        let progressivePace = currentMetrics.averagePace - (paceImprovement * 0.3)
        recommendations.append(TrainingRecommendation(
            runNumber: 1,
            distance: max(currentMetrics.longestRun * 0.6, 3.0),
            targetPace: progressivePace,
            description: "Progressive Pace Run",
            reasoning: "Gradually work toward your goal pace with controlled effort"
        ))
        
        // Recommendation 2: Speed work
        recommendations.append(TrainingRecommendation(
            runNumber: 2,
            distance: 4.0,
            targetPace: targetPace - 0.3,
            description: "Speed Development",
            reasoning: "Train faster than goal pace to make target feel easier"
        ))
        
        // Recommendation 3: Goal pace practice
        recommendations.append(TrainingRecommendation(
            runNumber: 3,
            distance: max(currentMetrics.longestRun * 0.7, 4.0),
            targetPace: targetPace,
            description: "Goal Pace Practice",
            reasoning: "Practice running at your exact goal pace to build muscle memory"
        ))
        
        return recommendations
    }
    
    // MARK: - Progress Trajectory Generation
    private func generateProgressTrajectory(
        goal: RunningGoal,
        currentMetrics: CurrentPerformanceMetrics,
        activities: [ProcessedActivity]
    ) -> [GoalProgressPoint] {
        let weeksRemaining = Int(ceil(goal.weeksRemaining))
        var progressPoints: [GoalProgressPoint] = []
        
        let currentDate = Date()
        let currentProgress = calculateGoalProgress(goal: goal, currentMetrics: currentMetrics, activities: activities)
        
        // Generate weekly progress points
        for week in 0...weeksRemaining {
            let weekDate = Calendar.current.date(byAdding: .weekOfYear, value: week, to: currentDate) ?? currentDate
            
            // Linear progression toward goal (simplified model)
            let targetProgress = currentProgress + (1.0 - currentProgress) * (Double(week) / Double(weeksRemaining))
            
            // Actual progress starts at current and will be updated with real data
            let actualProgress = week == 0 ? currentProgress : targetProgress * 0.9 // Slightly conservative estimate
            
            progressPoints.append(GoalProgressPoint(
                date: weekDate,
                actualProgress: actualProgress,
                targetProgress: targetProgress,
                weekNumber: week
            ))
        }
        
        return progressPoints
    }
    
    // MARK: - Helper Functions
    private func preprocessActivities(_ activities: [Activity]) -> [ProcessedActivity] {
        return activities.compactMap { activity in
            guard let distance = activity.distance,
                  let elapsedTime = activity.elapsed_time,
                  let startDate = activity.start_date,
                  distance > 0, elapsedTime > 0 else {
                return nil
            }
            
            let pace = (elapsedTime / 60.0) / (distance * 0.000621371) // minutes per mile
            let speed = (distance * 0.000621371) / (elapsedTime / 3600.0) // mph
            let date = Date(timeIntervalSince1970: startDate)
            
            return ProcessedActivity(
                id: activity.id,
                date: date,
                distance: distance * 0.000621371, // Convert to miles
                elapsedTime: elapsedTime / 60.0, // Convert to minutes
                pace: pace,
                speed: speed,
                dayOfWeek: Calendar.current.component(.weekday, from: date),
                month: Calendar.current.component(.month, from: date),
                type: activity.type ?? "Run"
            )
        }.sorted { $0.date < $1.date }
    }
    
    private func calculateRunningConsistency(activities: [ProcessedActivity]) -> Double {
        guard activities.count >= 4 else { return 0.0 }
        
        let calendar = Calendar.current
        let weeklyRuns = Dictionary(grouping: activities) { activity in
            calendar.dateInterval(of: .weekOfYear, for: activity.date)?.start ?? activity.date
        }
        
        let weeksWithRuns = weeklyRuns.filter { $0.value.count > 0 }.count
        let totalWeeks = weeklyRuns.count
        
        return Double(weeksWithRuns) / Double(totalWeeks) * 100
    }
    
    private func calculatePerformanceTrend(activities: [ProcessedActivity]) -> PerformanceTrend {
        guard activities.count >= 2 else { return .stable }
        
        let recentActivities = Array(activities.suffix(5))
        let olderActivities = Array(activities.prefix(max(5, activities.count - 5)))
        
        let recentAvgPace = recentActivities.reduce(0) { $0 + $1.pace } / Double(recentActivities.count)
        let olderAvgPace = olderActivities.reduce(0) { $0 + $1.pace } / Double(olderActivities.count)
        
        let improvement = (olderAvgPace - recentAvgPace) / olderAvgPace * 100
        
        if improvement > 5 {
            return .improving
        } else if improvement < -5 {
            return .declining
        } else {
            return .stable
        }
    }
    
    private func calculateProjectedCompletion(
        goal: RunningGoal,
        currentMetrics: CurrentPerformanceMetrics,
        progressPoints: [GoalProgressPoint]
    ) -> Double {
        // Simple linear projection based on current progress and time remaining
        let currentProgress = progressPoints.first?.actualProgress ?? 0.0
        let weeksRemaining = goal.weeksRemaining
        
        if weeksRemaining <= 0 {
            return currentProgress * 100
        }
        
        // Factor in consistency and recent trend
        let consistencyFactor = currentMetrics.consistency / 100.0
        let trendFactor: Double = {
            switch currentMetrics.recentTrend {
            case .improving: return 1.2
            case .stable: return 1.0
            case .declining: return 0.8
            }
        }()
        
        // Project completion percentage
        let weeklyProgressRate = (1.0 - currentProgress) / weeksRemaining
        let adjustedRate = weeklyProgressRate * consistencyFactor * trendFactor
        let projectedProgress = currentProgress + (adjustedRate * weeksRemaining)
        
        return min(projectedProgress * 100, 100.0)
    }
}

// MARK: - Supporting Data Models
struct CurrentPerformanceMetrics {
    let averagePace: Double // minutes per mile
    let weeklyMileage: Double // miles per week
    let longestRun: Double // miles
    let consistency: Double // percentage
    let recentTrend: PerformanceTrend
}