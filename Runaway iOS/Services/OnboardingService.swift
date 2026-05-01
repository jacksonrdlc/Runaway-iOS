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
        let states = try SupabaseDecoder.shared.decode([OnboardingState].self, from: data)

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
        let states = try SupabaseDecoder.shared.decode([OnboardingState].self, from: data)

        guard let createdState = states.first else {
            throw OnboardingError.creationFailed
        }

        #if DEBUG
        print("✅ OnboardingService: Created onboarding state for athlete \(athleteId)")
        #endif
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
        let states = try SupabaseDecoder.shared.decode([OnboardingState].self, from: data)

        guard let updatedState = states.first else {
            throw OnboardingError.updateFailed
        }

        #if DEBUG
        print("✅ OnboardingService: Updated onboarding state")
        #endif
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

        #if DEBUG
        print("✅ OnboardingService: Updated step to \(step)")
        #endif
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

        #if DEBUG
        print("✅ OnboardingService: Updated experience level to \(level.rawValue)")
        #endif
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

        #if DEBUG
        print("✅ OnboardingService: Updated movement test results - cadence: \(cadence), variance: \(variance)")
        #endif
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

        #if DEBUG
        print("✅ OnboardingService: Updated coach personality to \(personality.rawValue)")
        #endif
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

        #if DEBUG
        print("✅ OnboardingService: Updated location permission to \(granted)")
        #endif
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
        let states = try SupabaseDecoder.shared.decode([OnboardingState].self, from: data)

        guard let completedState = states.first else {
            throw OnboardingError.completionFailed
        }

        #if DEBUG
        print("✅ OnboardingService: Completed onboarding!")
        #endif
        return completedState
    }

    // MARK: - Check Onboarding Status

    /// Check if athlete has completed onboarding
    static func checkOnboardingStatus(athleteId: Int) async throws -> Bool {
        #if DEBUG
        print("🔍 OnboardingService: Checking onboarding status for athlete \(athleteId)")
        #endif

        // Query the onboarding table directly
        let response = try await supabase
            .from("athlete_onboarding")
            .select("is_completed")
            .eq("athlete_id", value: athleteId)
            .execute()

        struct OnboardingStatusResult: Decodable {
            let is_completed: Bool
        }

        let results = try SupabaseDecoder.shared.decode([OnboardingStatusResult].self, from: response.data)

        if let result = results.first {
            #if DEBUG
            print("✅ OnboardingService: Onboarding completed = \(result.is_completed)")
            #endif
            return result.is_completed
        }

        // No onboarding record found - default to not completed (new user)
        #if DEBUG
        print("⚠️ OnboardingService: No onboarding record found for athlete \(athleteId), defaulting to not completed")
        #endif
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
