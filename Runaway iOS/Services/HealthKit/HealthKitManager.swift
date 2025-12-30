//
//  HealthKitManager.swift
//  Runaway iOS
//
//  Created on 12/29/25.
//

import Foundation
import HealthKit

@MainActor
class HealthKitManager: ObservableObject {

    static let shared = HealthKitManager()

    let healthStore = HKHealthStore()

    @Published var isAuthorized = false
    @Published var authorizationStatus: HKAuthorizationStatus = .notDetermined

    // MARK: - HealthKit Availability

    var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    static var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Data Types to Read

    private var typesToRead: Set<HKObjectType> {
        var types: Set<HKObjectType> = []

        // Activity data
        if let stepCount = HKObjectType.quantityType(forIdentifier: .stepCount) {
            types.insert(stepCount)
        }
        if let distance = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) {
            types.insert(distance)
        }
        if let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergy)
        }

        // Heart rate data
        if let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate) {
            types.insert(heartRate)
        }
        if let restingHR = HKObjectType.quantityType(forIdentifier: .restingHeartRate) {
            types.insert(restingHR)
        }
        if let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            types.insert(hrv)
        }

        // Sleep data
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }

        // VO2 Max
        if let vo2Max = HKObjectType.quantityType(forIdentifier: .vo2Max) {
            types.insert(vo2Max)
        }

        // Workouts
        types.insert(HKObjectType.workoutType())

        // Workout routes
        if let routeType = HKSeriesType.workoutRoute() as? HKObjectType {
            types.insert(routeType)
        }

        return types
    }

    // MARK: - Data Types to Write

    private var typesToWrite: Set<HKSampleType> {
        var types: Set<HKSampleType> = []

        // Workout
        types.insert(HKObjectType.workoutType())

        // Distance
        if let distance = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) {
            types.insert(distance)
        }

        // Active energy
        if let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergy)
        }

        // Heart rate
        if let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate) {
            types.insert(heartRate)
        }

        return types
    }

    // MARK: - Authorization

    /// Request authorization and return Bool indicating success
    func requestAuthorization() async -> Bool {
        guard isHealthKitAvailable else {
            print("HealthKit is not available on this device")
            return false
        }

        do {
            try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
            await updateAuthorizationStatus()
            print("HealthKit authorization completed")
            return isAuthorized
        } catch {
            print("HealthKit authorization failed: \(error)")
            return false
        }
    }

    /// Request authorization and throw on failure
    func requestAuthorizationThrowing() async throws {
        guard isHealthKitAvailable else {
            print("HealthKit is not available on this device")
            throw HealthKitError.notAvailable
        }

        do {
            try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
            await updateAuthorizationStatus()
            print("HealthKit authorization completed")
        } catch {
            print("HealthKit authorization failed: \(error)")
            throw HealthKitError.authorizationFailed(error)
        }
    }

    func updateAuthorizationStatus() async {
        // Check authorization for a key type (workouts)
        let workoutType = HKObjectType.workoutType()
        let status = healthStore.authorizationStatus(for: workoutType)

        await MainActor.run {
            self.authorizationStatus = status
            self.isAuthorized = status == .sharingAuthorized
        }
    }

    func checkAuthorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        healthStore.authorizationStatus(for: type)
    }

    // MARK: - Convenience Methods

    func canWriteWorkouts() -> Bool {
        let status = healthStore.authorizationStatus(for: HKObjectType.workoutType())
        return status == .sharingAuthorized
    }

    func canReadHeartRate() -> Bool {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            return false
        }
        // Note: We can only check write authorization status, not read
        // Read authorization is determined at query time
        return true
    }

    // MARK: - Activity Type Mapping

    func workoutActivityType(for activityType: String) -> HKWorkoutActivityType {
        switch activityType.lowercased() {
        case "run", "running":
            return .running
        case "walk", "walking":
            return .walking
        case "hike", "hiking":
            return .hiking
        case "cycle", "cycling", "ride", "bike":
            return .cycling
        case "swim", "swimming":
            return .swimming
        case "yoga":
            return .yoga
        case "strength", "weight training", "weighttraining", "workout":
            return .traditionalStrengthTraining
        case "hiit", "high intensity interval training":
            return .highIntensityIntervalTraining
        default:
            return .running
        }
    }
}

// MARK: - Errors

enum HealthKitError: Error, LocalizedError {
    case notAvailable
    case authorizationFailed(Error)
    case dataNotAvailable
    case queryFailed(Error)
    case workoutSaveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .authorizationFailed(let error):
            return "HealthKit authorization failed: \(error.localizedDescription)"
        case .dataNotAvailable:
            return "Requested health data is not available"
        case .queryFailed(let error):
            return "HealthKit query failed: \(error.localizedDescription)"
        case .workoutSaveFailed(let error):
            return "Failed to save workout: \(error.localizedDescription)"
        }
    }
}
