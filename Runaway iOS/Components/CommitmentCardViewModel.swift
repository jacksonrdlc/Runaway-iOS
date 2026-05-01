//
//  CommitmentCardViewModel.swift
//  Runaway iOS
//
//  Shared view-model for commitment card components.
//  Centralises loading state, error state, and mutation methods
//  that were previously duplicated across ActivityCommitmentCard,
//  CompactCommitmentCard, and their child views.
//

import Foundation
import Observation

@MainActor
@Observable
final class CommitmentCardViewModel {

    // MARK: - State

    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var showingSuccess = false

    // MARK: - Mutations

    func createCommitment(_ activityType: CommitmentActivityType) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await DataManager.shared.createCommitment(activityType)
            showingSuccess = true
            Task {
                try? await Task.sleep(for: .seconds(2))
                showingSuccess = false
            }
        } catch {
            errorMessage = "Failed to create commitment: \(error.localizedDescription)"
        }
    }

    func updateCommitment(to activityType: CommitmentActivityType) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await DataManager.shared.updateCommitment(to: activityType)
        } catch {
            errorMessage = "Failed to update: \(error.localizedDescription)"
        }
    }

    func deleteCommitment() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await DataManager.shared.deleteCommitment()
        } catch {
            errorMessage = "Failed to remove: \(error.localizedDescription)"
        }
    }

    func completeMicroCommitment() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await CommitmentManager.shared.completeMicroCommitment()
            await DataManager.shared.refreshTodaysCommitment()
        } catch {
            errorMessage = "Failed to complete: \(error.localizedDescription)"
        }
    }

    // MARK: - Helpers

    /// Maps a raw activity type name string to the CommitmentActivityType enum.
    static func commitmentActivityType(for name: String) -> CommitmentActivityType {
        switch name.lowercased() {
        case "run": return .run
        case "walk": return .walk
        case "yoga": return .yoga
        case "weight training", "weighttraining", "workout": return .workout
        default: return .run
        }
    }

    func clearError() {
        errorMessage = nil
    }
}
