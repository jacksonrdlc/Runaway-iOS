//
//  RunningAnalyzer.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 6/27/25.
//


import Foundation
import CoreML
import TabularData

#if os(macOS)
import CreateML
#endif

class RunningAnalyzer: ObservableObject {
    @Published var analysisResults: AnalysisResults?
    @Published var isAnalyzing = false
    
    private let apiService = RunawayCoachAPIService()
    
    // MARK: - Main Analysis Function
    func analyzePerformance(activities: [Activity]) async {
        await MainActor.run {
            self.isAnalyzing = true
        }

        // Perform all heavy processing on background queue
        let results = await Task.detached(priority: .userInitiated) { () -> AnalysisResults? in
            do {
                // Try to use the agentic API first for enhanced insights
                let insights = await self.generateEnhancedInsights(from: activities)
                let model = try await self.trainPaceModel(from: self.preprocessActivities(activities))

                return AnalysisResults(
                    insights: insights,
                    model: model,
                    lastUpdated: Date()
                )
            } catch {
                print("Analysis error: \(error)")
                return nil
            }
        }.value

        await MainActor.run {
            if let results = results {
                self.analysisResults = results
            }
            self.isAnalyzing = false
        }
    }
    
    // MARK: - Enhanced Insights Generation with API
    private func generateEnhancedInsights(from activities: [Activity]) async -> RunningInsights {
        // Try to get AI-powered insights first
        do {
            let quickInsights = try await apiService.getQuickInsights(activities: activities)
            return convertAPIInsightsToRunningInsights(apiInsights: quickInsights.insights, activities: activities)
        } catch {
            print("API insights failed, falling back to local analysis: \(error)")
            let processedData = preprocessActivities(activities)
            return generateLocalInsights(from: processedData)
        }
    }
    
    private func convertAPIInsightsToRunningInsights(
        apiInsights: QuickInsights,
        activities: [Activity]
    ) -> RunningInsights {
        let processedActivities = preprocessActivities(activities)
        let runningActivities = processedActivities.filter { $0.type.lowercased().contains("run") }
        
        // Basic statistics from local data
        let totalDistance = runningActivities.reduce(0) { $0 + $1.distance }
        let totalTime = runningActivities.reduce(0) { $0 + $1.elapsedTime }
        let averageSpeed = runningActivities.reduce(0) { $0 + $1.speed } / Double(runningActivities.count)
        
        // Convert API pace string to double (assumes MM:SS format)
        let averagePaceDouble = parsePaceString(apiInsights.performanceTrend) ?? 7.0
        
        // Map API trend to local enum
        let performanceTrend: PerformanceTrend
        switch apiInsights.performanceTrend.lowercased() {
        case "improving":
            performanceTrend = .improving
        case "declining":
            performanceTrend = .declining
        default:
            performanceTrend = .stable
        }
        
        // Use local calculations for some metrics
        let weeklyVolume = calculateWeeklyVolume(activities: processedActivities)
        let nextRunPrediction = predictNextRunPerformance(activities: processedActivities)
        let goalReadiness = calculateGoalReadiness(activities: processedActivities)
        
        return RunningInsights(
            totalDistance: totalDistance,
            totalTime: totalTime,
            averagePace: averagePaceDouble,
            averageSpeed: averageSpeed,
            performanceTrend: performanceTrend,
            weeklyVolume: weeklyVolume,
            consistency: apiInsights.consistency,
            nextRunPrediction: nextRunPrediction,
            recommendations: apiInsights.topRecommendations,
            goalReadiness: goalReadiness
        )
    }
    
    private func parsePaceString(_ paceString: String) -> Double? {
        // Parse MM:SS format to minutes per mile
        let components = paceString.components(separatedBy: ":")
        guard components.count == 2,
              let minutes = Double(components[0]),
              let seconds = Double(components[1]) else {
            return nil
        }
        return minutes + (seconds / 60.0)
    }
    
    private func generateLocalInsights(from activities: [ProcessedActivity]) -> RunningInsights {
        let runningActivities = activities.filter { $0.type.lowercased().contains("run") }
        
        // Basic statistics
        let totalDistance = runningActivities.reduce(0) { $0 + $1.distance }
        let totalTime = runningActivities.reduce(0) { $0 + $1.elapsedTime }
        let averagePace = runningActivities.reduce(0) { $0 + $1.pace } / Double(runningActivities.count)
        let averageSpeed = runningActivities.reduce(0) { $0 + $1.speed } / Double(runningActivities.count)
        
        // Performance trends
        let performanceTrend = calculatePerformanceTrend(activities: runningActivities)
        let weeklyVolume = calculateWeeklyVolume(activities: runningActivities)
        
        // Training consistency
        let consistency = calculateConsistency(activities: runningActivities)
        
        // Predictions
        let nextRunPrediction = predictNextRunPerformance(activities: runningActivities)
        
        // Goal readiness analysis
        let goalReadiness = calculateGoalReadiness(activities: runningActivities)
        
        return RunningInsights(
            totalDistance: totalDistance,
            totalTime: totalTime,
            averagePace: averagePace,
            averageSpeed: averageSpeed,
            performanceTrend: performanceTrend,
            weeklyVolume: weeklyVolume,
            consistency: consistency,
            nextRunPrediction: nextRunPrediction,
            recommendations: generateRecommendations(from: runningActivities),
            goalReadiness: goalReadiness
        )
    }
    
    // MARK: - Data Preprocessing
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
    
    // MARK: - Insights Generation (Kept for backward compatibility)
    private func generateInsights(from activities: [ProcessedActivity]) async -> RunningInsights {
        return generateLocalInsights(from: activities)
    }
    
    // MARK: - ML Model Training
    private func trainPaceModel(from activities: [ProcessedActivity]) async throws -> MLModel? {
        #if os(macOS)
        guard activities.count >= 10 else { return nil } // Need minimum data

        // Create training data
        var trainingData: [[String: MLDataValueConvertible]] = []

        for (index, activity) in activities.enumerated() {
            guard index > 0 else { continue } // Need previous activity for features

            let previousActivity = activities[index - 1]
            let daysSinceLast = activity.date.timeIntervalSince(previousActivity.date) / (24 * 3600)

            trainingData.append([
                "distance": activity.distance,
                "dayOfWeek": Double(activity.dayOfWeek),
                "month": Double(activity.month),
                "daysSinceLast": daysSinceLast,
                "previousPace": previousActivity.pace,
                "targetPace": activity.pace
            ])
        }

        do {
            // Extract individual columns
            let distances = trainingData.map { $0["distance"] as! Double }
            let daysSinceLast = trainingData.map { $0["daysSinceLast"] as! Double }
            let previousPaces = trainingData.map { $0["previousPace"] as! Double }
            let targetPaces = trainingData.map { $0["targetPace"] as! Double }

            // Create DataFrame with explicit columns
            var dataTable = DataFrame()
            dataTable.append(column: Column(name: "distance", contents: distances))
            dataTable.append(column: Column(name: "daysSinceLast", contents: daysSinceLast))
            dataTable.append(column: Column(name: "previousPace", contents: previousPaces))
            dataTable.append(column: Column(name: "targetPace", contents: targetPaces))

            let regressor = try MLLinearRegressor(trainingData: dataTable, targetColumn: "targetPace")
            return regressor.model
        } catch {
            print("Model training error: \(error)")
            return nil
        }
        #else
        // ML model training only available on macOS
        // On iOS, the app will use local analysis without ML predictions
        print("ML model training not available on iOS - using local analysis only")
        return nil
        #endif
    }
    
    // MARK: - Analysis Functions
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
    
    private func calculateWeeklyVolume(activities: [ProcessedActivity]) -> [WeeklyVolume] {
        // Convert ProcessedActivity back to Activity for cache key generation
        let activitiesForCache = activities.map { processed in
            Activity(
                id: processed.id,
                name: "Cached Activity",
                type: processed.type,
                summary_polyline: nil,
                distance: processed.distance * 1609.34, // Convert back to meters
                start_date: processed.date.timeIntervalSince1970,
                elapsed_time: processed.elapsedTime * 60 // Convert back to seconds
            )
        }

        // Try cache first
        let cache = ActivityMetricsCache()
        if let cached = cache.getWeeklyVolume(for: activitiesForCache) {
            return cached
        }

        // Calculate if not cached
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: activities) { activity in
            calendar.dateInterval(of: .weekOfYear, for: activity.date)?.start ?? activity.date
        }

        let result = grouped.map { (weekStart, weekActivities) in
            let totalDistance = weekActivities.reduce(0) { $0 + $1.distance }
            let totalTime = weekActivities.reduce(0) { $0 + $1.elapsedTime }

            return WeeklyVolume(
                weekStart: weekStart,
                totalDistance: totalDistance,
                totalTime: totalTime,
                activityCount: weekActivities.count
            )
        }.sorted { $0.weekStart < $1.weekStart }

        // Cache the result
        cache.cacheWeeklyVolume(result, for: activitiesForCache)

        return result
    }
    
    private func calculateConsistency(activities: [ProcessedActivity]) -> Double {
        guard activities.count >= 4 else { return 0.0 }
        
        let calendar = Calendar.current
        let weeklyRuns = Dictionary(grouping: activities) { activity in
            calendar.dateInterval(of: .weekOfYear, for: activity.date)?.start ?? activity.date
        }
        
        let weeksWithRuns = weeklyRuns.filter { $0.value.count > 0 }.count
        let totalWeeks = weeklyRuns.count
        
        return Double(weeksWithRuns) / Double(totalWeeks) * 100
    }
    
    private func predictNextRunPerformance(activities: [ProcessedActivity]) -> PaceRange? {
        guard let lastActivity = activities.last else { return nil }
        
        let recentPaces = Array(activities.suffix(5)).map { $0.pace }
        let avgRecentPace = recentPaces.reduce(0, +) / Double(recentPaces.count)
        let paceVariability = recentPaces.map { abs($0 - avgRecentPace) }.reduce(0, +) / Double(recentPaces.count)
        
        return PaceRange(
            fastest: avgRecentPace - paceVariability,
            expected: avgRecentPace,
            slowest: avgRecentPace + paceVariability
        )
    }
    
    private func generateRecommendations(from activities: [ProcessedActivity]) -> [String] {
        var recommendations: [String] = []
        
        // Check weekly volume
        let weeklyVolumes = calculateWeeklyVolume(activities: activities)
        if let lastWeek = weeklyVolumes.last, lastWeek.totalDistance < 10 {
            recommendations.append("Consider increasing your weekly mileage gradually")
        }
        
        // Check consistency
        let consistency = calculateConsistency(activities: activities)
        if consistency < 70 {
            recommendations.append("Try to run more consistently - aim for 3-4 runs per week")
        }
        
        // Check pace variety
        let paces = activities.map { $0.pace }
        guard let maxPace = paces.max(), let minPace = paces.min() else {
            return recommendations // Return current recommendations if we can't calculate pace variety
        }
        let paceRange = maxPace - minPace
        if paceRange < 1.0 {
            recommendations.append("Add variety to your pace - try some faster and slower runs")
        }
        
        return recommendations
    }
    
    // MARK: - Goal Readiness Analysis
    private func calculateGoalReadiness(activities: [ProcessedActivity]) -> GoalReadiness? {
        // For now, we'll assume a marathon goal (26.2 miles) as an example
        // In a real implementation, this would come from user's actual goal
        let goalDistance = 26.2 // miles
        let goalDate = Calendar.current.date(byAdding: .month, value: 4, to: Date()) ?? Date() // 4 months from now
        
        guard !activities.isEmpty else { return nil }
        
        // Calculate fitness level based on recent performance
        let recentActivities = activities.suffix(10) // Last 10 runs
        let avgDistance = recentActivities.reduce(0) { $0 + $1.distance } / Double(recentActivities.count)
        let avgPace = recentActivities.reduce(0) { $0 + $1.pace } / Double(recentActivities.count)
        let longestRun = activities.map { $0.distance }.max() ?? 0
        
        // Fitness Level Assessment
        let fitnessLevel: ReadinessLevel
        let fitnessScore = (longestRun / goalDistance) * 100
        switch fitnessScore {
        case 80...: fitnessLevel = .excellent
        case 60..<80: fitnessLevel = .good
        case 40..<60: fitnessLevel = .fair
        default: fitnessLevel = .poor
        }
        
        // Experience Level Assessment (based on activity count and consistency)
        let experienceLevel: ReadinessLevel
        let totalRuns = activities.count
        switch totalRuns {
        case 50...: experienceLevel = .excellent
        case 30..<50: experienceLevel = .good
        case 15..<30: experienceLevel = .fair
        default: experienceLevel = .poor
        }
        
        // Volume Preparation (weekly mileage vs goal requirement)
        let weeklyVolume = calculateWeeklyVolume(activities: activities)
        let recentWeeklyAvg = weeklyVolume.suffix(4).reduce(0) { $0 + $1.totalDistance } / 4.0
        let recommendedWeeklyVolume = goalDistance * 0.7 // Rough estimate
        
        let volumePreparation: ReadinessLevel
        let volumeRatio = recentWeeklyAvg / recommendedWeeklyVolume
        switch volumeRatio {
        case 1.0...: volumePreparation = .excellent
        case 0.8..<1.0: volumePreparation = .good
        case 0.6..<0.8: volumePreparation = .fair
        default: volumePreparation = .poor
        }
        
        // Time to Goal Assessment
        let timeToGoal: ReadinessLevel
        let weeksRemaining = Calendar.current.dateComponents([.weekOfYear], from: Date(), to: goalDate).weekOfYear ?? 0
        switch weeksRemaining {
        case 16...: timeToGoal = .excellent
        case 12..<16: timeToGoal = .good
        case 8..<12: timeToGoal = .fair
        default: timeToGoal = .poor
        }
        
        // Overall Score Calculation
        let overallScore = (fitnessLevel.score + experienceLevel.score + volumePreparation.score + timeToGoal.score) / 4.0
        
        // Generate recommendations and risk factors
        var recommendations: [String] = []
        var riskFactors: [String] = []
        
        if fitnessLevel == .poor || fitnessLevel == .fair {
            recommendations.append("Gradually increase your long run distance")
            riskFactors.append("Low endurance base for goal distance")
        }
        
        if volumePreparation == .poor {
            recommendations.append("Build up weekly mileage consistently")
            riskFactors.append("Insufficient weekly training volume")
        }
        
        if experienceLevel == .poor {
            recommendations.append("Focus on building a consistent running habit")
            riskFactors.append("Limited running experience")
        }
        
        if timeToGoal == .poor {
            riskFactors.append("Limited time remaining for proper preparation")
            recommendations.append("Consider adjusting goal timeline or distance")
        }
        
        if overallScore >= 80 {
            recommendations.append("You're well-prepared! Focus on maintaining fitness")
        } else if overallScore >= 60 {
            recommendations.append("Good foundation - increase training consistency")
        }
        
        return GoalReadiness(
            overallScore: overallScore,
            fitnessLevel: fitnessLevel,
            experienceLevel: experienceLevel,
            volumePreparation: volumePreparation,
            timeToGoal: timeToGoal,
            recommendations: recommendations,
            riskFactors: riskFactors
        )
    }
    
    // MARK: - Prediction Functions
    func predictPaceForDistance(_ distance: Double, using model: MLModel?) -> Double? {
        guard let model = model else { return nil }
        
        do {
            let input = PacePredictionInput(distance: distance)
            let output = try model.prediction(from: input)
            return output.featureValue(for: "targetPace")?.doubleValue
        } catch {
            print("Prediction error: \(error)")
            return nil
        }
    }
}

// MARK: - Data Models
struct ProcessedActivity {
    let id: Int
    let date: Date
    let distance: Double // miles
    let elapsedTime: Double // minutes
    let pace: Double // min/mile
    let speed: Double // mph
    let dayOfWeek: Int
    let month: Int
    let type: String
}

struct AnalysisResults {
    let insights: RunningInsights
    let model: MLModel?
    let lastUpdated: Date
}

struct RunningInsights {
    let totalDistance: Double
    let totalTime: Double
    let averagePace: Double
    let averageSpeed: Double
    let performanceTrend: PerformanceTrend
    let weeklyVolume: [WeeklyVolume]
    let consistency: Double
    let nextRunPrediction: PaceRange?
    let recommendations: [String]
    let goalReadiness: GoalReadiness?
}

struct WeeklyVolume {
    let weekStart: Date
    let totalDistance: Double
    let totalTime: Double
    let activityCount: Int
}

struct PaceRange {
    let fastest: Double
    let expected: Double
    let slowest: Double
}

enum PerformanceTrend {
    case improving
    case stable
    case declining
    
    var description: String {
        switch self {
        case .improving: return "Improving"
        case .stable: return "Stable"
        case .declining: return "Declining"
        }
    }
    
    var color: String {
        switch self {
        case .improving: return "green"
        case .stable: return "blue"
        case .declining: return "red"
        }
    }
}

struct GoalReadiness {
    let overallScore: Double // 0-100
    let fitnessLevel: ReadinessLevel
    let experienceLevel: ReadinessLevel
    let volumePreparation: ReadinessLevel
    let timeToGoal: ReadinessLevel
    let recommendations: [String]
    let riskFactors: [String]
}

enum ReadinessLevel: String, CaseIterable {
    case excellent = "excellent"
    case good = "good"
    case fair = "fair"
    case poor = "poor"
    
    var displayName: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        }
    }
    
    var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "blue"
        case .fair: return "orange"
        case .poor: return "red"
        }
    }
    
    var score: Double {
        switch self {
        case .excellent: return 90
        case .good: return 75
        case .fair: return 60
        case .poor: return 40
        }
    }
}

// MARK: - CoreML Input
@objc(PacePredictionInput)
class PacePredictionInput: NSObject, MLFeatureProvider {
    let distance: Double
    
    init(distance: Double) {
        self.distance = distance
    }
    
    var featureNames: Set<String> {
        return ["distance"]
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        if featureName == "distance" {
            return MLFeatureValue(double: distance)
        }
        return nil
    }
}