//
//  OnboardingService.swift
//  Runaway iOS
//
//  Created by Claude on 1/12/26.
//

import Foundation
import Supabase

// MARK: - Onboarding Service

class OnboardingService {

    // MARK: - Get Onboarding State

    /// Fetch onboarding state for an athlete
    static func getOnboardingState(athleteId: Int) async throws -> OnboardingState? {
        let response = try await supabase
            .from("athlete_onboarding")
            .select()
            .eq("athlete_id", value: athleteId)
            .execute()

        let data = response.data
        let states = try JSONDecoder().decode([OnboardingState].self, from: data)

        return states.first
    }

    // MARK: - Create Onboarding State

    /// Create initial onboarding state for a new athlete
    static func createOnboardingState(athleteId: Int) async throws -> OnboardingState {
        let newState = OnboardingState(athleteId: athleteId)

        let response = try await supabase
            .from("athlete_onboarding")
            .insert(newState)
            .select()
            .execute()

        let data = response.data
        let states = try JSONDecoder().decode([OnboardingState].self, from: data)

        guard let createdState = states.first else {
            throw OnboardingError.creationFailed
        }

        print("✅ OnboardingService: Created onboarding state for athlete \(athleteId)")
        return createdState
    }

    // MARK: - Update Onboarding State

    /// Update onboarding state
    static func updateOnboardingState(_ state: OnboardingState) async throws -> OnboardingState {
        guard let stateId = state.id else {
            throw OnboardingError.invalidState
        }

        let response = try await supabase
            .from("athlete_onboarding")
            .update(state)
            .eq("id", value: stateId)
            .select()
            .execute()

        let data = response.data
        let states = try JSONDecoder().decode([OnboardingState].self, from: data)

        guard let updatedState = states.first else {
            throw OnboardingError.updateFailed
        }

        print("✅ OnboardingService: Updated onboarding state")
        return updatedState
    }

    // MARK: - Update Current Step

    /// Update just the current step
    static func updateCurrentStep(stateId: Int, step: Int) async throws {
        let updateData = OnboardingStepUpdate(currentStep: step)

        _ = try await supabase
            .from("athlete_onboarding")
            .update(updateData)
            .eq("id", value: stateId)
            .execute()

        print("✅ OnboardingService: Updated step to \(step)")
    }

    // MARK: - Update Experience Level

    /// Update experience level
    static func updateExperienceLevel(stateId: Int, level: ExperienceLevel) async throws {
        let updateData = OnboardingExperienceUpdate(experienceLevel: level.rawValue)

        _ = try await supabase
            .from("athlete_onboarding")
            .update(updateData)
            .eq("id", value: stateId)
            .execute()

        print("✅ OnboardingService: Updated experience level to \(level.rawValue)")
    }

    // MARK: - Update Movement Test Results

    /// Save movement test results
    static func updateMovementTestResults(stateId: Int, cadence: Double, variance: Double) async throws {
        let updateData = OnboardingMovementUpdate(
            movementTestCadence: cadence,
            movementTestVariance: variance
        )

        _ = try await supabase
            .from("athlete_onboarding")
            .update(updateData)
            .eq("id", value: stateId)
            .execute()

        print("✅ OnboardingService: Updated movement test results - cadence: \(cadence), variance: \(variance)")
    }

    // MARK: - Update Coach Personality

    /// Update coach personality preference
    static func updateCoachPersonality(stateId: Int, personality: CoachPersonality) async throws {
        let updateData = OnboardingCoachUpdate(coachPersonality: personality.rawValue)

        _ = try await supabase
            .from("athlete_onboarding")
            .update(updateData)
            .eq("id", value: stateId)
            .execute()

        print("✅ OnboardingService: Updated coach personality to \(personality.rawValue)")
    }

    // MARK: - Update Location Permission

    /// Update location permission status
    static func updateLocationPermission(stateId: Int, granted: Bool) async throws {
        let updateData = OnboardingLocationUpdate(locationPermissionGranted: granted)

        _ = try await supabase
            .from("athlete_onboarding")
            .update(updateData)
            .eq("id", value: stateId)
            .execute()

        print("✅ OnboardingService: Updated location permission to \(granted)")
    }

    // MARK: - Complete Onboarding

    /// Mark onboarding as complete
    static func completeOnboarding(stateId: Int) async throws -> OnboardingState {
        let now = ISO8601DateFormatter().string(from: Date())
        let updateData = OnboardingCompletionUpdate(
            isCompleted: true,
            completedAt: now
        )

        let response = try await supabase
            .from("athlete_onboarding")
            .update(updateData)
            .eq("id", value: stateId)
            .select()
            .execute()

        let data = response.data
        let states = try JSONDecoder().decode([OnboardingState].self, from: data)

        guard let completedState = states.first else {
            throw OnboardingError.completionFailed
        }

        print("✅ OnboardingService: Completed onboarding!")
        return completedState
    }

    // MARK: - Check Onboarding Status

    /// Check if athlete has completed onboarding (uses database function)
    static func checkOnboardingStatus(athleteId: Int) async throws -> Bool {
        let response = try await supabase
            .rpc("check_onboarding_status", params: [
                "p_athlete_id": athleteId
            ])
            .execute()

        let data = response.data
        if let result = try? JSONDecoder().decode(Bool.self, from: data) {
            return result
        }

        return false
    }

    // MARK: - Get or Create Onboarding State

    /// Get existing state or create new one
    static func getOrCreateOnboardingState(athleteId: Int) async throws -> OnboardingState {
        if let existingState = try await getOnboardingState(athleteId: athleteId) {
            return existingState
        }

        return try await createOnboardingState(athleteId: athleteId)
    }
}

// MARK: - Update Models

private struct OnboardingStepUpdate: Codable {
    let currentStep: Int

    enum CodingKeys: String, CodingKey {
        case currentStep = "current_step"
    }
}

private struct OnboardingExperienceUpdate: Codable {
    let experienceLevel: String

    enum CodingKeys: String, CodingKey {
        case experienceLevel = "experience_level"
    }
}

private struct OnboardingMovementUpdate: Codable {
    let movementTestCadence: Double
    let movementTestVariance: Double

    enum CodingKeys: String, CodingKey {
        case movementTestCadence = "movement_test_cadence"
        case movementTestVariance = "movement_test_variance"
    }
}

private struct OnboardingCoachUpdate: Codable {
    let coachPersonality: String

    enum CodingKeys: String, CodingKey {
        case coachPersonality = "coach_personality"
    }
}

private struct OnboardingLocationUpdate: Codable {
    let locationPermissionGranted: Bool

    enum CodingKeys: String, CodingKey {
        case locationPermissionGranted = "location_permission_granted"
    }
}

private struct OnboardingCompletionUpdate: Codable {
    let isCompleted: Bool
    let completedAt: String

    enum CodingKeys: String, CodingKey {
        case isCompleted = "is_completed"
        case completedAt = "completed_at"
    }
}

// MARK: - Onboarding Errors

enum OnboardingError: Error, LocalizedError {
    case creationFailed
    case updateFailed
    case invalidState
    case completionFailed
    case notFound

    var errorDescription: String? {
        switch self {
        case .creationFailed:
            return "Failed to create onboarding state"
        case .updateFailed:
            return "Failed to update onboarding state"
        case .invalidState:
            return "Invalid onboarding state"
        case .completionFailed:
            return "Failed to complete onboarding"
        case .notFound:
            return "Onboarding state not found"
        }
    }
}
