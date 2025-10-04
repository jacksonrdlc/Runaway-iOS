//
//  QuickWinsModels.swift
//  Runaway iOS
//
//  Data models for Quick Wins AI-powered insights
//

import Foundation

// MARK: - Main Response Model

struct QuickWinsResponse: Codable {
    let success: Bool
    let userId: String
    let analysisDate: String
    let analyses: QuickWinsAnalyses
    let priorityRecommendations: [String]

    enum CodingKeys: String, CodingKey {
        case success
        case userId = "athlete_id"
        case analysisDate = "analysis_date"
        case analyses
        case priorityRecommendations = "priority_recommendations"
    }
}

struct QuickWinsAnalyses: Codable {
    let weatherContext: WeatherAnalysis?
    let vo2maxEstimate: VO2MaxEstimate?
    let trainingLoad: TrainingLoadAnalysis?

    enum CodingKeys: String, CodingKey {
        case weatherContext = "weather_context"
        case vo2maxEstimate = "vo2max_estimate"
        case trainingLoad = "training_load"
    }

    // Helper to check if we have any data
    var hasData: Bool {
        weatherContext != nil || vo2maxEstimate != nil || trainingLoad != nil
    }
}

// MARK: - Weather Models

struct WeatherAnalysis: Codable {
    let averageTemperatureCelsius: Double
    let averageHumidityPercent: Double
    let heatStressRuns: Int
    let idealConditionRuns: Int
    let weatherImpactScore: String // "minimal", "moderate", "significant", "severe"
    let paceDegradationSecondsPerMile: Double
    let heatAcclimationLevel: String // "none", "developing", "well-acclimated"
    let optimalTrainingTimes: [String]
    let recommendations: [String]

    enum CodingKeys: String, CodingKey {
        case averageTemperatureCelsius = "average_temperature_celsius"
        case averageHumidityPercent = "average_humidity_percent"
        case heatStressRuns = "heat_stress_runs"
        case idealConditionRuns = "ideal_condition_runs"
        case weatherImpactScore = "weather_impact_score"
        case paceDegradationSecondsPerMile = "pace_degradation_seconds_per_mile"
        case heatAcclimationLevel = "heat_acclimation_level"
        case optimalTrainingTimes = "optimal_training_times"
        case recommendations
    }

    // Helper computed properties
    var temperatureFahrenheit: Double {
        (averageTemperatureCelsius * 9/5) + 32
    }

    var impactColor: String {
        switch weatherImpactScore {
        case "minimal": return "green"
        case "moderate": return "orange"
        case "significant": return "red"
        case "severe": return "purple"
        default: return "gray"
        }
    }

    var acclimationDots: Int {
        switch heatAcclimationLevel {
        case "none": return 1
        case "developing": return 2
        case "well-acclimated": return 3
        default: return 0
        }
    }
}

// MARK: - VO2 Max Models

struct VO2MaxEstimate: Codable {
    let vo2Max: Double
    let fitnessLevel: String // "elite", "excellent", "good", "average", "below_average"
    let estimationMethod: String
    let vvo2MaxPace: String?
    let racePredictions: [RacePrediction]
    let recommendations: [String]
    let dataQualityScore: Double

    enum CodingKeys: String, CodingKey {
        case vo2Max = "vo2_max"
        case fitnessLevel = "fitness_level"
        case estimationMethod = "estimation_method"
        case vvo2MaxPace = "vvo2_max_pace"
        case racePredictions = "race_predictions"
        case recommendations
        case dataQualityScore = "data_quality_score"
    }

    var fitnessLevelDisplay: String {
        fitnessLevel.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var fitnessColor: String {
        switch fitnessLevel {
        case "elite": return "purple"
        case "excellent": return "blue"
        case "good": return "green"
        case "average": return "orange"
        default: return "gray"
        }
    }
}

struct RacePrediction: Codable, Identifiable {
    var id: String { distance }

    let distance: String
    let distanceKm: Double
    let predictedTime: String
    let predictedTimeSeconds: Int
    let pacePerKm: String
    let pacePerMile: String
    let confidence: String // "high", "medium", "low"

    enum CodingKeys: String, CodingKey {
        case distance
        case distanceKm = "distance_km"
        case predictedTime = "predicted_time"
        case predictedTimeSeconds = "predicted_time_seconds"
        case pacePerKm = "pace_per_km"
        case pacePerMile = "pace_per_mile"
        case confidence
    }

    var confidenceValue: Double {
        switch confidence {
        case "high": return 0.9
        case "medium": return 0.6
        case "low": return 0.3
        default: return 0.0
        }
    }

    var confidenceColor: String {
        switch confidence {
        case "high": return "green"
        case "medium": return "orange"
        case "low": return "red"
        default: return "gray"
        }
    }
}

// MARK: - Training Load Models

struct TrainingLoadAnalysis: Codable {
    let acuteLoad7Days: Double
    let chronicLoad28Days: Double
    let acwr: Double
    let weeklyTss: Double
    let totalVolumeKm: Double
    let recoveryStatus: String // "well_recovered", "adequate", "fatigued", "overreaching", "overtrained"
    let injuryRiskLevel: String // "low", "moderate", "high", "very_high"
    let trainingTrend: String // "ramping_up", "steady", "tapering", "detraining"
    let fitnessTrend: String // "improving", "maintaining", "declining"
    let recommendations: [String]
    let dailyRecommendations: [String: String]

    enum CodingKeys: String, CodingKey {
        case acuteLoad7Days = "acute_load_7_days"
        case chronicLoad28Days = "chronic_load_28_days"
        case acwr
        case weeklyTss = "weekly_tss"
        case totalVolumeKm = "total_volume_km"
        case recoveryStatus = "recovery_status"
        case injuryRiskLevel = "injury_risk_level"
        case trainingTrend = "training_trend"
        case fitnessTrend = "fitness_trend"
        case recommendations
        case dailyRecommendations = "daily_recommendations"
    }

    var acwrColor: String {
        if acwr < 0.8 {
            return "blue" // Detraining
        } else if acwr <= 1.3 {
            return "green" // Optimal
        } else if acwr <= 1.5 {
            return "orange" // Moderate risk
        } else {
            return "red" // High risk
        }
    }

    var acwrZone: String {
        if acwr < 0.8 {
            return "Detraining"
        } else if acwr <= 1.3 {
            return "Optimal"
        } else if acwr <= 1.5 {
            return "Moderate Risk"
        } else {
            return "High Risk"
        }
    }

    var injuryRiskColor: String {
        switch injuryRiskLevel {
        case "low": return "green"
        case "moderate": return "orange"
        case "high": return "red"
        case "very_high": return "purple"
        default: return "gray"
        }
    }

    var injuryRiskDisplay: String {
        injuryRiskLevel.replacingOccurrences(of: "_", with: " ").uppercased() + " RISK"
    }

    var recoveryColor: String {
        switch recoveryStatus {
        case "well_recovered": return "green"
        case "adequate": return "blue"
        case "fatigued": return "orange"
        case "overreaching": return "red"
        case "overtrained": return "purple"
        default: return "gray"
        }
    }

    var recoveryStatusDisplay: String {
        recoveryStatus.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var trainingTrendDisplay: String {
        trainingTrend.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var fitnessTrendDisplay: String {
        fitnessTrend.capitalized
    }

    var totalVolumeMiles: Double {
        totalVolumeKm * 0.621371
    }

    // Helper to get sorted daily recommendations
    var sortedDailyRecommendations: [(String, String)] {
        dailyRecommendations.sorted { $0.key < $1.key }
    }
}

// MARK: - Error Types

enum QuickWinsError: Error, LocalizedError {
    case invalidResponse
    case decodingError(Error)
    case networkError(Error)
    case unauthorized
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unauthorized:
            return "Unauthorized. Please sign in again."
        case .serverError(let code):
            return "Server error (code: \(code))"
        }
    }
}

// MARK: - Mock Data Extension

extension QuickWinsResponse {
    static var mock: QuickWinsResponse {
        QuickWinsResponse(
            success: true,
            userId: "123",
            analysisDate: "2025-10-01T17:30:00Z",
            analyses: QuickWinsAnalyses(
                weatherContext: WeatherAnalysis(
                    averageTemperatureCelsius: 24.5,
                    averageHumidityPercent: 68.2,
                    heatStressRuns: 12,
                    idealConditionRuns: 8,
                    weatherImpactScore: "moderate",
                    paceDegradationSecondsPerMile: 15.2,
                    heatAcclimationLevel: "developing",
                    optimalTrainingTimes: ["5:00-7:00 AM", "8:00-10:00 PM"],
                    recommendations: [
                        "Average training temperature (24.5°C) is above ideal. Expect 15s/mile slower pace in heat.",
                        "High humidity (68.2%) impairs cooling. Reduce pace by 10-20s/mile on humid days.",
                        "Train early morning (5-7am) or evening (7-9pm) to avoid peak heat."
                    ]
                ),
                vo2maxEstimate: VO2MaxEstimate(
                    vo2Max: 52.3,
                    fitnessLevel: "good",
                    estimationMethod: "race_performance",
                    vvo2MaxPace: "4:15",
                    racePredictions: [
                        RacePrediction(distance: "5K", distanceKm: 5.0, predictedTime: "0:21:45", predictedTimeSeconds: 1305, pacePerKm: "4:21", pacePerMile: "6:59", confidence: "high"),
                        RacePrediction(distance: "10K", distanceKm: 10.0, predictedTime: "0:45:30", predictedTimeSeconds: 2730, pacePerKm: "4:33", pacePerMile: "7:20", confidence: "high"),
                        RacePrediction(distance: "Half Marathon", distanceKm: 21.0975, predictedTime: "1:42:15", predictedTimeSeconds: 6135, pacePerKm: "4:51", pacePerMile: "7:48", confidence: "medium"),
                        RacePrediction(distance: "Marathon", distanceKm: 42.195, predictedTime: "3:35:45", predictedTimeSeconds: 12945, pacePerKm: "5:06", pacePerMile: "8:13", confidence: "medium")
                    ],
                    recommendations: [
                        "Your estimated VO2 max of 52.3 ml/kg/min places you in the 'good' category for runners.",
                        "Improve VO2 max with interval sessions: 5x1000m at 5K pace with 3min rest."
                    ],
                    dataQualityScore: 0.85
                ),
                trainingLoad: TrainingLoadAnalysis(
                    acuteLoad7Days: 285.3,
                    chronicLoad28Days: 312.8,
                    acwr: 0.91,
                    weeklyTss: 285.3,
                    totalVolumeKm: 45.2,
                    recoveryStatus: "adequate",
                    injuryRiskLevel: "low",
                    trainingTrend: "steady",
                    fitnessTrend: "improving",
                    recommendations: [
                        "✓ ACWR is 0.91 (optimal zone). Training load is well-managed.",
                        "Recovery essentials: 7-9 hours sleep, protein within 30min post-run."
                    ],
                    dailyRecommendations: [
                        "Day 1": "40min easy run",
                        "Day 2": "45min moderate run with 5x2min pickups",
                        "Day 3": "30min recovery run",
                        "Day 4": "50min tempo run (15min at threshold)",
                        "Day 5": "Rest",
                        "Day 6": "40min easy run",
                        "Day 7": "75min long run (easy pace)"
                    ]
                )
            ),
            priorityRecommendations: [
                "✓ ACWR is 0.91 (optimal zone). Training load is well-managed. Continue current progression.",
                "Your estimated VO2 max of 52.3 ml/kg/min places you in the 'good' category for runners.",
                "Average training temperature (24.5°C) is above ideal. Expect 15s/mile slower pace in heat.",
                "Recovery essentials: 7-9 hours sleep, protein within 30min post-run, foam rolling.",
                "Improve VO2 max with interval sessions: 5x1000m at 5K pace with 3min rest."
            ]
        )
    }
}
