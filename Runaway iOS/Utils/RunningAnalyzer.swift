//
//  RunningAnalyzer.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 6/27/25.
//


import Foundation
import CreateML
import CoreML
import TabularData

class RunningAnalyzer: ObservableObject {
    @Published var analysisResults: AnalysisResults?
    @Published var isAnalyzing = false
    
    // MARK: - Main Analysis Function
    func analyzePerformance(activities: [Activity]) async {
        DispatchQueue.main.async {
            self.isAnalyzing = true
        }
        
        do {
            let processedData = preprocessActivities(activities)
            let insights = await generateInsights(from: processedData)
            let model = try await trainPaceModel(from: processedData)
            
            let results = AnalysisResults(
                insights: insights,
                model: model,
                lastUpdated: Date()
            )
            
            DispatchQueue.main.async {
                self.analysisResults = results
                self.isAnalyzing = false
            }
        } catch {
            print("Analysis error: \(error)")
            DispatchQueue.main.async {
                self.isAnalyzing = false
            }
        }
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
    
    // MARK: - Insights Generation
    private func generateInsights(from activities: [ProcessedActivity]) async -> RunningInsights {
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
        
        return RunningInsights(
            totalDistance: totalDistance,
            totalTime: totalTime,
            averagePace: averagePace,
            averageSpeed: averageSpeed,
            performanceTrend: performanceTrend,
            weeklyVolume: weeklyVolume,
            consistency: consistency,
            nextRunPrediction: nextRunPrediction,
            recommendations: generateRecommendations(from: runningActivities)
        )
    }
    
    // MARK: - ML Model Training
    private func trainPaceModel(from activities: [ProcessedActivity]) async throws -> MLModel? {
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
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: activities) { activity in
            calendar.dateInterval(of: .weekOfYear, for: activity.date)?.start ?? activity.date
        }
        
        return grouped.map { (weekStart, weekActivities) in
            let totalDistance = weekActivities.reduce(0) { $0 + $1.distance }
            let totalTime = weekActivities.reduce(0) { $0 + $1.elapsedTime }
            
            return WeeklyVolume(
                weekStart: weekStart,
                totalDistance: totalDistance,
                totalTime: totalTime,
                activityCount: weekActivities.count
            )
        }.sorted { $0.weekStart < $1.weekStart }
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