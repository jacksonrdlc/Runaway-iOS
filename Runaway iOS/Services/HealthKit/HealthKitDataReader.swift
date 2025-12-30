//
//  HealthKitDataReader.swift
//  Runaway iOS
//
//  Created on 12/29/25.
//

import Foundation
import HealthKit

class HealthKitDataReader {

    private let healthStore: HKHealthStore

    init(healthStore: HKHealthStore? = nil) {
        self.healthStore = healthStore ?? HKHealthStore()
    }

    @MainActor
    static func withSharedHealthStore() -> HealthKitDataReader {
        return HealthKitDataReader(healthStore: HealthKitManager.shared.healthStore)
    }

    // MARK: - Sleep Data

    struct SleepAnalysis {
        let totalSleepMinutesRaw: Double
        let deepSleepMinutes: Double
        let remSleepMinutes: Double
        let coreSleepMinutes: Double
        let awakeMinutes: Double
        let sleepStartTime: Date?
        let sleepEndTime: Date?

        /// Total sleep minutes as Int for display
        var totalSleepMinutes: Int { Int(totalSleepMinutesRaw) }

        var qualityScore: Int {
            // Score based on duration (7-9 hours optimal) and composition
            let durationScore = min(totalSleepMinutesRaw / 480.0, 1.0) * 50 // 8 hours = 50 points
            let deepScore = min(deepSleepMinutes / 90.0, 1.0) * 25 // 1.5 hours deep = 25 points
            let remScore = min(remSleepMinutes / 120.0, 1.0) * 25 // 2 hours REM = 25 points
            return Int(min(durationScore + deepScore + remScore, 100))
        }

        var sleepQualityScore: Double {
            Double(qualityScore)
        }
    }

    typealias SleepData = SleepAnalysis

    func fetchSleepAnalysis(for date: Date) async throws -> SleepAnalysis? {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return nil
        }

        // Get sleep samples for the night before the given date
        let calendar = Calendar.current
        let endOfDay = calendar.startOfDay(for: date).addingTimeInterval(12 * 60 * 60) // noon
        let startOfNight = calendar.date(byAdding: .hour, value: -18, to: endOfDay)! // 6pm previous day

        let predicate = HKQuery.predicateForSamples(
            withStart: startOfNight,
            end: endOfDay,
            options: .strictStartDate
        )

        let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKCategorySample], Error>) in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples as? [HKCategorySample] ?? [])
                }
            }
            healthStore.execute(query)
        }

        guard !samples.isEmpty else { return nil }

        var totalSleep: Double = 0
        var deepSleep: Double = 0
        var remSleep: Double = 0
        var coreSleep: Double = 0
        var awake: Double = 0
        var earliestStart: Date?
        var latestEnd: Date?

        for sample in samples {
            let duration = sample.endDate.timeIntervalSince(sample.startDate) / 60.0

            if earliestStart == nil || sample.startDate < earliestStart! {
                earliestStart = sample.startDate
            }
            if latestEnd == nil || sample.endDate > latestEnd! {
                latestEnd = sample.endDate
            }

            switch sample.value {
            case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                 HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                coreSleep += duration
                totalSleep += duration
            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                deepSleep += duration
                totalSleep += duration
            case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                remSleep += duration
                totalSleep += duration
            case HKCategoryValueSleepAnalysis.awake.rawValue:
                awake += duration
            default:
                break
            }
        }

        return SleepAnalysis(
            totalSleepMinutesRaw: totalSleep,
            deepSleepMinutes: deepSleep,
            remSleepMinutes: remSleep,
            coreSleepMinutes: coreSleep,
            awakeMinutes: awake,
            sleepStartTime: earliestStart,
            sleepEndTime: latestEnd
        )
    }

    // MARK: - Heart Rate Variability

    struct HRVData {
        let latestHRV: Double // in milliseconds
        let averageHRV: Double
        let samples: [(date: Date, value: Double)]

        /// Current HRV value
        var value: Double { latestHRV }

        /// Percent change from baseline (7-day average)
        var percentFromBaseline: Double? {
            guard averageHRV > 0 else { return nil }
            return ((latestHRV - averageHRV) / averageHRV) * 100
        }

        /// Score 0-100 based on HRV relative to baseline
        var score: Int {
            // Higher HRV is better
            // Score based on how current compares to average
            guard averageHRV > 0 else { return 50 }
            let ratio = latestHRV / averageHRV
            // 1.1x average = 100, 0.9x average = 50, 0.7x average = 0
            let rawScore = (ratio - 0.7) / 0.4 * 100
            return Int(min(max(rawScore, 0), 100))
        }
    }

    func fetchHRVData(for date: Date, days: Int = 7) async throws -> HRVData? {
        guard let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            return nil
        }

        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: date).addingTimeInterval(24 * 60 * 60)
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate)!

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKQuantitySample], Error>) in
            let query = HKSampleQuery(
                sampleType: hrvType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples as? [HKQuantitySample] ?? [])
                }
            }
            healthStore.execute(query)
        }

        guard !samples.isEmpty else { return nil }

        let unit = HKUnit.secondUnit(with: .milli)
        let values = samples.map { (date: $0.startDate, value: $0.quantity.doubleValue(for: unit)) }
        let average = values.map { $0.value }.reduce(0, +) / Double(values.count)

        return HRVData(
            latestHRV: values.first?.value ?? 0,
            averageHRV: average,
            samples: values
        )
    }

    // MARK: - Resting Heart Rate

    struct RestingHRData {
        let latestRestingHR: Double // bpm
        let averageRestingHR: Double
        let samples: [(date: Date, value: Double)]

        /// Current resting HR value
        var value: Int { Int(latestRestingHR) }

        /// Deviation from baseline (positive = higher than baseline = worse)
        var deviationFromBaseline: Int? {
            guard averageRestingHR > 0 else { return nil }
            return Int(latestRestingHR - averageRestingHR)
        }

        /// Score 0-100 based on resting HR relative to baseline
        var score: Int {
            // Lower resting HR is better
            // Negative deviation (lower than baseline) = good
            guard averageRestingHR > 0 else { return 50 }
            let deviation = latestRestingHR - averageRestingHR
            // -5 bpm from baseline = 100, at baseline = 70, +5 bpm = 40
            let rawScore = 70 - (deviation * 6)
            return Int(min(max(rawScore, 0), 100))
        }
    }

    func fetchRestingHeartRate(for date: Date, days: Int = 7) async throws -> RestingHRData? {
        guard let restingHRType = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else {
            return nil
        }

        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: date).addingTimeInterval(24 * 60 * 60)
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate)!

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKQuantitySample], Error>) in
            let query = HKSampleQuery(
                sampleType: restingHRType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples as? [HKQuantitySample] ?? [])
                }
            }
            healthStore.execute(query)
        }

        guard !samples.isEmpty else { return nil }

        let unit = HKUnit.count().unitDivided(by: .minute())
        let values = samples.map { (date: $0.startDate, value: $0.quantity.doubleValue(for: unit)) }
        let average = values.map { $0.value }.reduce(0, +) / Double(values.count)

        return RestingHRData(
            latestRestingHR: values.first?.value ?? 0,
            averageRestingHR: average,
            samples: values
        )
    }

    // MARK: - VO2 Max

    func fetchVO2Max() async throws -> Double? {
        guard let vo2MaxType = HKObjectType.quantityType(forIdentifier: .vo2Max) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: Date.distantPast,
            end: Date(),
            options: .strictEndDate
        )

        let sample = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKQuantitySample?, Error>) in
            let query = HKSampleQuery(
                sampleType: vo2MaxType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples?.first as? HKQuantitySample)
                }
            }
            healthStore.execute(query)
        }

        guard let sample = sample else { return nil }

        let unit = HKUnit(from: "ml/kg*min")
        return sample.quantity.doubleValue(for: unit)
    }

    // MARK: - Heart Rate During Workout

    func fetchHeartRateSamples(from startDate: Date, to endDate: Date) async throws -> [(date: Date, bpm: Double)] {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            return []
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKQuantitySample], Error>) in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples as? [HKQuantitySample] ?? [])
                }
            }
            healthStore.execute(query)
        }

        let unit = HKUnit.count().unitDivided(by: .minute())
        return samples.map { (date: $0.startDate, bpm: $0.quantity.doubleValue(for: unit)) }
    }
}
