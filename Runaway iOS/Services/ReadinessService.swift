//
//  ReadinessService.swift
//  Runaway iOS
//
//  Calculates daily readiness/recovery scores based on HealthKit data
//  Formula: Sleep (30%) + HRV (25%) + Resting HR (20%) + Training Load (25%)
//

import Foundation
import Combine

@MainActor
class ReadinessService: ObservableObject {
    static let shared = ReadinessService()

    // MARK: - Published Properties

    @Published private(set) var todaysReadiness: DailyReadiness?
    @Published private(set) var isCalculating = false
    @Published private(set) var lastError: Error?

    // MARK: - Private Properties

    private let healthKitDataReader = HealthKitDataReader()
    private let cacheKey = "cached_daily_readiness"
    private let cacheDuration: TimeInterval = 4 * 60 * 60 // 4 hours

    // MARK: - Initialization

    private init() {
        // Load cached readiness on init
        loadCachedReadiness()
    }

    // MARK: - Public Methods

    /// Calculate today's readiness score
    func calculateTodaysReadiness() async throws -> DailyReadiness {
        guard HealthKitManager.isHealthKitAvailable else {
            throw ReadinessError.healthKitNotAvailable
        }

        guard await HealthKitManager.shared.isAuthorized else {
            throw ReadinessError.notAuthorized
        }

        isCalculating = true
        lastError = nil

        defer {
            Task { @MainActor in
                isCalculating = false
            }
        }

        let today = Date()

        // Fetch all health data in parallel
        async let sleepData = healthKitDataReader.fetchSleepAnalysis(for: today)
        async let hrvData = healthKitDataReader.fetchHRVData(for: today)
        async let restingHRData = healthKitDataReader.fetchRestingHeartRate(for: today)

        let sleep = try? await sleepData
        let hrv = try? await hrvData
        let restingHR = try? await restingHRData

        // Calculate training load from recent activities
        let trainingLoad = await calculateTrainingLoadScore()

        // Build factors
        var factors: [ReadinessFactor] = []
        var totalWeightedScore = 0.0
        var totalWeight = 0.0

        // Sleep factor (30%)
        if let sleep = sleep {
            let factor = ReadinessFactor(
                id: ReadinessFactor.sleepId,
                name: "Sleep",
                score: sleep.qualityScore,
                weight: 0.30,
                value: formatDuration(minutes: sleep.totalSleepMinutes),
                change: nil,
                trend: sleep.totalSleepMinutes >= 420 ? .improving : (sleep.totalSleepMinutes >= 360 ? .stable : .declining)
            )
            factors.append(factor)
            totalWeightedScore += Double(factor.score) * factor.weight
            totalWeight += factor.weight
        }

        // HRV factor (25%)
        if let hrv = hrv {
            let changeText = hrv.percentFromBaseline.map { String(format: "%+.0f%%", $0) }
            let trend: ReadinessFactor.FactorTrend = {
                guard let percent = hrv.percentFromBaseline else { return .stable }
                if percent >= 5 { return .improving }
                if percent <= -10 { return .declining }
                return .stable
            }()

            let factor = ReadinessFactor(
                id: ReadinessFactor.hrvId,
                name: "HRV",
                score: hrv.score,
                weight: 0.25,
                value: String(format: "%.0f ms", hrv.value),
                change: changeText,
                trend: trend
            )
            factors.append(factor)
            totalWeightedScore += Double(factor.score) * factor.weight
            totalWeight += factor.weight
        }

        // Resting HR factor (20%)
        if let restingHR = restingHR {
            let changeText = restingHR.deviationFromBaseline.map { String(format: "%+d bpm", $0) }
            let trend: ReadinessFactor.FactorTrend = {
                guard let deviation = restingHR.deviationFromBaseline else { return .stable }
                if deviation <= -3 { return .improving }
                if deviation >= 5 { return .declining }
                return .stable
            }()

            let factor = ReadinessFactor(
                id: ReadinessFactor.restingHRId,
                name: "Resting HR",
                score: restingHR.score,
                weight: 0.20,
                value: "\(restingHR.value) bpm",
                change: changeText,
                trend: trend
            )
            factors.append(factor)
            totalWeightedScore += Double(factor.score) * factor.weight
            totalWeight += factor.weight
        }

        // Training load factor (25%)
        let trainingLoadFactor = ReadinessFactor(
            id: ReadinessFactor.trainingLoadId,
            name: "Training Load",
            score: trainingLoad.score,
            weight: 0.25,
            value: trainingLoad.description,
            change: nil,
            trend: trainingLoad.trend
        )
        factors.append(trainingLoadFactor)
        totalWeightedScore += Double(trainingLoadFactor.score) * trainingLoadFactor.weight
        totalWeight += trainingLoadFactor.weight

        // Calculate overall score
        let overallScore: Int
        if totalWeight > 0 {
            overallScore = Int((totalWeightedScore / totalWeight) * (totalWeight / 1.0))
        } else {
            overallScore = 50 // Default if no data
        }

        // Get athlete ID
        let athleteId = UserSession.shared.userId ?? 0

        // Generate personalized recommendation
        let recommendation = generateRecommendation(
            score: overallScore,
            sleep: sleep,
            hrv: hrv,
            restingHR: restingHR,
            trainingLoad: trainingLoad
        )

        let readiness = DailyReadiness(
            athleteId: athleteId,
            date: today,
            score: overallScore,
            factors: factors,
            recommendation: recommendation
        )

        // Cache and save
        todaysReadiness = readiness
        cacheReadiness(readiness)

        // Save to database
        Task {
            try? await saveReadinessToDatabase(readiness)
        }

        return readiness
    }

    /// Refresh readiness if stale (older than cache duration)
    func refreshIfNeeded() async {
        if let cached = todaysReadiness,
           cached.isToday,
           Date().timeIntervalSince(cached.calculatedAt) < cacheDuration {
            // Cache is still valid
            return
        }

        do {
            _ = try await calculateTodaysReadiness()
        } catch {
            lastError = error
            #if DEBUG
            print("Failed to calculate readiness: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Private Methods

    private func calculateTrainingLoadScore() async -> (score: Int, description: String, trend: ReadinessFactor.FactorTrend) {
        // Get recent activities to calculate ACWR (Acute:Chronic Workload Ratio)
        guard let athleteId = UserSession.shared.userId else {
            return (70, "No data", .stable)
        }

        do {
            // Fetch activities from last 28 days
            let activities = try await ActivityService.getAllActivitiesByUser(
                userId: athleteId,
                limit: 60
            )

            let calendar = Calendar.current
            let today = Date()

            // Calculate acute load (last 7 days)
            let sevenDaysAgo = today.timeIntervalSince1970 - (7 * 24 * 60 * 60)
            let acuteActivities = activities.filter {
                guard let date = $0.activity_date else { return false }
                return date >= sevenDaysAgo
            }
            let acuteLoad = acuteActivities.reduce(0.0) { sum, activity in
                sum + calculateActivityLoad(activity)
            }

            // Calculate chronic load (8-28 days ago)
            let twentyEightDaysAgo = today.timeIntervalSince1970 - (28 * 24 * 60 * 60)
            let chronicActivities = activities.filter {
                guard let date = $0.activity_date else { return false }
                return date >= twentyEightDaysAgo && date < sevenDaysAgo
            }
            let chronicLoad = chronicActivities.reduce(0.0) { sum, activity in
                sum + calculateActivityLoad(activity)
            }

            // Calculate ACWR
            let averageChronicLoad = chronicLoad / 3.0 // Average per week
            let acwr: Double = averageChronicLoad > 0 ? acuteLoad / averageChronicLoad : 1.0

            // Score based on ACWR
            // Optimal ACWR is 0.8-1.3
            // Higher = overtraining risk, Lower = detraining
            let score: Int
            let description: String
            let trend: ReadinessFactor.FactorTrend

            if acwr >= 0.8 && acwr <= 1.3 {
                score = 85
                description = "Optimal"
                trend = .stable
            } else if acwr < 0.8 {
                score = 75
                description = "Light week"
                trend = .improving // Recovery
            } else if acwr <= 1.5 {
                score = 65
                description = "High load"
                trend = .declining
            } else {
                score = 45
                description = "Overreaching"
                trend = .declining
            }

            return (score, description, trend)

        } catch {
            return (70, "No data", .stable)
        }
    }

    private func calculateActivityLoad(_ activity: Activity) -> Double {
        // Simple TSS-like calculation: duration (hours) * intensity factor
        let elapsedTime = activity.elapsed_time ?? 0
        let durationHours = elapsedTime / 3600.0

        // Intensity based on pace if running
        let intensityFactor: Double
        let avgSpeed = activity.average_speed ?? 0
        if avgSpeed > 0 {
            // Faster pace = higher intensity
            let paceMinPerMile = (1609.34 / avgSpeed) / 60.0
            if paceMinPerMile < 7 {
                intensityFactor = 1.5 // Hard effort
            } else if paceMinPerMile < 9 {
                intensityFactor = 1.0 // Moderate
            } else {
                intensityFactor = 0.7 // Easy
            }
        } else {
            intensityFactor = 1.0
        }

        return durationHours * intensityFactor * 100 // Arbitrary scale
    }

    private func generateRecommendation(
        score: Int,
        sleep: HealthKitDataReader.SleepAnalysis?,
        hrv: HealthKitDataReader.HRVData?,
        restingHR: HealthKitDataReader.RestingHRData?,
        trainingLoad: (score: Int, description: String, trend: ReadinessFactor.FactorTrend)
    ) -> String {
        let level = DailyReadinessLevel.from(score: score)

        // Check for specific concerns
        var concerns: [String] = []

        if let sleep = sleep, sleep.totalSleepMinutes < 360 {
            concerns.append("low sleep")
        }

        if let hrv = hrv, let percent = hrv.percentFromBaseline, percent < -15 {
            concerns.append("HRV below baseline")
        }

        if let restingHR = restingHR, let deviation = restingHR.deviationFromBaseline, deviation > 5 {
            concerns.append("elevated resting HR")
        }

        if trainingLoad.score < 60 {
            concerns.append("high training load")
        }

        // Generate specific recommendation
        if !concerns.isEmpty && score < 70 {
            let concernsText = concerns.joined(separator: ", ")
            return "Recovery compromised by \(concernsText). Consider an easy day or rest."
        }

        return level.recommendation
    }

    private func formatDuration(minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }

    // MARK: - Caching

    private func cacheReadiness(_ readiness: DailyReadiness) {
        if let encoded = try? JSONEncoder().encode(readiness) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
        }
    }

    private func loadCachedReadiness() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cached = try? JSONDecoder().decode(DailyReadiness.self, from: data),
              cached.isToday else {
            return
        }
        todaysReadiness = cached
    }

    // MARK: - Database Sync

    private func saveReadinessToDatabase(_ readiness: DailyReadiness) async throws {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]

        let data: [String: AnyEncodable] = [
            "athlete_id": AnyEncodable(readiness.athleteId),
            "date": AnyEncodable(dateFormatter.string(from: readiness.date)),
            "score": AnyEncodable(readiness.score),
            "sleep_score": AnyEncodable(readiness.factor(id: ReadinessFactor.sleepId)?.score),
            "hrv_score": AnyEncodable(readiness.factor(id: ReadinessFactor.hrvId)?.score),
            "resting_hr_score": AnyEncodable(readiness.factor(id: ReadinessFactor.restingHRId)?.score),
            "training_load_score": AnyEncodable(readiness.factor(id: ReadinessFactor.trainingLoadId)?.score),
            "recommendation": AnyEncodable(readiness.recommendation)
        ]

        // Upsert to database
        _ = try await supabase
            .from("daily_readiness")
            .upsert(data, onConflict: "athlete_id,date")
            .execute()
    }
}

// MARK: - Readiness Error

enum ReadinessError: LocalizedError {
    case healthKitNotAvailable
    case notAuthorized
    case noData
    case calculationFailed(Error)

    var errorDescription: String? {
        switch self {
        case .healthKitNotAvailable:
            return "HealthKit is not available on this device"
        case .notAuthorized:
            return "HealthKit authorization required for readiness calculation"
        case .noData:
            return "Not enough health data to calculate readiness"
        case .calculationFailed(let error):
            return "Failed to calculate readiness: \(error.localizedDescription)"
        }
    }
}
