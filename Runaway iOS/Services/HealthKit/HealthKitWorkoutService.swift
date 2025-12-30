//
//  HealthKitWorkoutService.swift
//  Runaway iOS
//
//  Created on 12/29/25.
//

import Foundation
import HealthKit
import CoreLocation

@MainActor
class HealthKitWorkoutService: NSObject, ObservableObject {

    static let shared = HealthKitWorkoutService()

    private let healthStore: HKHealthStore
    private var workoutBuilder: HKWorkoutBuilder?
    private var routeBuilder: HKWorkoutRouteBuilder?

    @Published var isRecording = false
    @Published var currentHeartRate: Double?
    @Published var heartRateSamples: [HKQuantitySample] = []

    private var heartRateQuery: HKAnchoredObjectQuery?
    private var pendingLocations: [CLLocation] = []

    override init() {
        self.healthStore = HealthKitManager.shared.healthStore
        super.init()
    }

    // MARK: - Start Workout Session

    func startWorkout(activityType: HKWorkoutActivityType = .running) async throws {
        guard HealthKitManager.shared.canWriteWorkouts() else {
            throw HealthKitError.authorizationFailed(NSError(domain: "HealthKit", code: 0, userInfo: [NSLocalizedDescriptionKey: "Not authorized to write workouts"]))
        }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType
        configuration.locationType = .outdoor

        workoutBuilder = HKWorkoutBuilder(
            healthStore: healthStore,
            configuration: configuration,
            device: .local()
        )

        routeBuilder = HKWorkoutRouteBuilder(healthStore: healthStore, device: .local())
        pendingLocations = []

        try await workoutBuilder?.beginCollection(at: Date())

        isRecording = true
        startHeartRateQuery()

        print("HealthKit workout session started")
    }

    // MARK: - Add Location Data

    func addLocationSample(_ location: CLLocation) {
        guard routeBuilder != nil, isRecording else { return }
        pendingLocations.append(location)

        // Batch insert every 10 locations for efficiency
        if pendingLocations.count >= 10 {
            let locationsToInsert = pendingLocations
            pendingLocations = []

            Task {
                await insertRouteDataAsync(locationsToInsert)
            }
        }
    }

    private func insertRouteDataAsync(_ locations: [CLLocation]) async {
        guard let routeBuilder = routeBuilder, !locations.isEmpty else { return }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            routeBuilder.insertRouteData(locations) { success, error in
                if let error = error {
                    print("Failed to add route data: \(error)")
                }
                continuation.resume()
            }
        }
    }

    // MARK: - Pause/Resume Workout

    func pauseWorkout() {
        print("HealthKit workout paused (collection continues)")
    }

    func resumeWorkout() {
        print("HealthKit workout resumed")
    }

    // MARK: - End Workout

    func endWorkout(
        totalDistance: Double,
        totalDuration: TimeInterval,
        routeLocations: [CLLocation]
    ) async throws -> HKWorkout? {
        guard let workoutBuilder = workoutBuilder else {
            throw HealthKitError.dataNotAvailable
        }

        let startDate = workoutBuilder.startDate ?? Date().addingTimeInterval(-totalDuration)
        let endDate = Date()

        // Insert any remaining pending locations
        let allLocations = pendingLocations + routeLocations
        pendingLocations = []

        if !allLocations.isEmpty, let routeBuilder = routeBuilder {
            await insertRouteDataAsync(allLocations)
        }

        // Add distance sample
        if let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning), totalDistance > 0 {
            let distanceQuantity = HKQuantity(unit: .meter(), doubleValue: totalDistance)
            let distanceSample = HKQuantitySample(
                type: distanceType,
                quantity: distanceQuantity,
                start: startDate,
                end: endDate
            )
            try await addSamplesAsync([distanceSample])
        }

        // End collection
        try await workoutBuilder.endCollection(at: endDate)

        // Finish workout
        let workout = try await workoutBuilder.finishWorkout()

        // Finish route if available
        if let routeBuilder = routeBuilder, let workout = workout {
            await finishRouteAsync(routeBuilder: routeBuilder, workout: workout)
        }

        cleanup()
        print("HealthKit workout finished: \(workout?.uuid.uuidString ?? "nil")")

        return workout
    }

    private func addSamplesAsync(_ samples: [HKSample]) async throws {
        guard let workoutBuilder = workoutBuilder else { return }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            workoutBuilder.add(samples) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func finishRouteAsync(routeBuilder: HKWorkoutRouteBuilder, workout: HKWorkout) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            routeBuilder.finishRoute(with: workout, metadata: nil) { route, error in
                if let error = error {
                    print("Failed to add route to workout: \(error)")
                } else {
                    print("Route added to workout")
                }
                continuation.resume()
            }
        }
    }

    // MARK: - Cancel Workout

    func cancelWorkout() {
        cleanup()
        print("HealthKit workout cancelled")
    }

    private func cleanup() {
        stopHeartRateQuery()

        if let workoutBuilder = workoutBuilder {
            workoutBuilder.discardWorkout()
        }

        self.workoutBuilder = nil
        self.routeBuilder = nil
        self.heartRateSamples = []
        self.currentHeartRate = nil
        self.pendingLocations = []
        isRecording = false
    }

    // MARK: - Save Existing Activity to HealthKit

    func saveActivityToHealthKit(
        activityType: HKWorkoutActivityType = .running,
        startDate: Date,
        endDate: Date,
        distance: Double,
        calories: Double,
        averageHeartRate: Double? = nil,
        locations: [CLLocation]? = nil
    ) async throws -> HKWorkout {
        guard HealthKitManager.shared.canWriteWorkouts() else {
            throw HealthKitError.authorizationFailed(NSError(domain: "HealthKit", code: 0, userInfo: [NSLocalizedDescriptionKey: "Not authorized to write workouts"]))
        }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType
        configuration.locationType = locations != nil ? .outdoor : .unknown

        let builder = HKWorkoutBuilder(
            healthStore: healthStore,
            configuration: configuration,
            device: nil
        )

        try await builder.beginCollection(at: startDate)

        // Add distance
        if let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning), distance > 0 {
            let distanceQuantity = HKQuantity(unit: .meter(), doubleValue: distance)
            let distanceSample = HKQuantitySample(
                type: distanceType,
                quantity: distanceQuantity,
                start: startDate,
                end: endDate
            )
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                builder.add([distanceSample]) { success, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        }

        // Add calories
        if let caloriesType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned), calories > 0 {
            let caloriesQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: calories)
            let caloriesSample = HKQuantitySample(
                type: caloriesType,
                quantity: caloriesQuantity,
                start: startDate,
                end: endDate
            )
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                builder.add([caloriesSample]) { success, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        }

        try await builder.endCollection(at: endDate)

        guard let workout = try await builder.finishWorkout() else {
            throw HealthKitError.workoutSaveFailed(NSError(domain: "HealthKit", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to create workout"]))
        }

        // Add route if locations provided
        if let locations = locations, !locations.isEmpty {
            let routeBuilder = HKWorkoutRouteBuilder(healthStore: healthStore, device: nil)

            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                routeBuilder.insertRouteData(locations) { success, error in
                    continuation.resume()
                }
            }

            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                routeBuilder.finishRoute(with: workout, metadata: nil) { route, error in
                    continuation.resume()
                }
            }
        }

        print("Activity saved to HealthKit: \(workout.uuid.uuidString)")
        return workout
    }

    // MARK: - Heart Rate Monitoring

    private func startHeartRateQuery() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }

        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            guard let self = self else { return }
            let hrSamples = samples as? [HKQuantitySample]
            Task { @MainActor in
                self.handleHeartRateSamples(hrSamples)
            }
        }

        query.updateHandler = { [weak self] _, samples, _, _, _ in
            guard let self = self else { return }
            let hrSamples = samples as? [HKQuantitySample]
            Task { @MainActor in
                self.handleHeartRateSamples(hrSamples)
            }
        }

        healthStore.execute(query)
        heartRateQuery = query
    }

    private func stopHeartRateQuery() {
        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
        }
    }

    private func handleHeartRateSamples(_ samples: [HKQuantitySample]?) {
        guard let samples = samples, let latestSample = samples.last else { return }

        let unit = HKUnit.count().unitDivided(by: .minute())
        let bpm = latestSample.quantity.doubleValue(for: unit)

        self.currentHeartRate = bpm
    }
}

// MARK: - Activity Type Mapping

extension HKWorkoutActivityType {
    static func from(activityType: String) -> HKWorkoutActivityType {
        switch activityType.lowercased() {
        case "run", "running":
            return .running
        case "walk", "walking":
            return .walking
        case "hike", "hiking":
            return .hiking
        case "cycle", "cycling", "ride":
            return .cycling
        case "swim", "swimming":
            return .swimming
        case "yoga":
            return .yoga
        case "strength", "weight training", "weighttraining":
            return .traditionalStrengthTraining
        case "hiit", "high intensity interval training":
            return .highIntensityIntervalTraining
        default:
            return .running
        }
    }
}
