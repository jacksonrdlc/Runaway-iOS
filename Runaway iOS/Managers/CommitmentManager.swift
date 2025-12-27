//
//  CommitmentManager.swift
//  Runaway iOS
//
//  Created by Claude on 12/23/25.
//

import Foundation

// MARK: - Commitment Manager Protocol

protocol CommitmentManagerProtocol: ObservableObject {
    var todaysCommitment: DailyCommitment? { get }
    var isLoading: Bool { get }

    func loadTodaysCommitment(for userId: Int) async
    func createCommitment(_ activityType: CommitmentActivityType) async throws
    func checkActivityFulfillsCommitment(_ activity: Activity) async
    func refresh() async
}

// MARK: - Commitment Manager

@MainActor
final class CommitmentManager: ObservableObject, CommitmentManagerProtocol {

    // MARK: - Published Properties

    @Published private(set) var todaysCommitment: DailyCommitment?
    @Published private(set) var isLoading = false

    // MARK: - Private Properties

    private let repository: CommitmentRepositoryProtocol

    // MARK: - Singleton

    static let shared = CommitmentManager()

    // MARK: - Initialization

    init(repository: CommitmentRepositoryProtocol = SupabaseCommitmentRepository.shared) {
        self.repository = repository
    }

    // MARK: - Data Loading

    func loadTodaysCommitment(for userId: Int) async {
        isLoading = true
        defer { isLoading = false }

        do {
            self.todaysCommitment = try await repository.getTodaysCommitment(userId: userId)
        } catch {
            print("❌ CommitmentManager: Failed to load commitment: \(error)")
        }
    }

    // MARK: - Commitment Creation

    func createCommitment(_ activityType: CommitmentActivityType) async throws {
        guard let userId = UserSession.shared.userId else {
            throw CommitmentError.noUserId
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let commitment = DailyCommitment(athleteId: userId, activityType: activityType)
            let createdCommitment = try await repository.createCommitment(commitment)
            self.todaysCommitment = createdCommitment
        } catch {
            print("❌ CommitmentManager: Failed to create commitment: \(error)")
            throw error
        }
    }

    // MARK: - Commitment Fulfillment

    func checkActivityFulfillsCommitment(_ activity: Activity) async {
        guard let userId = UserSession.shared.userId else {
            print("❌ CommitmentManager: No user ID for commitment check")
            return
        }

        print("🔍 CommitmentManager: Checking if '\(activity.type ?? "unknown")' fulfills commitment")

        do {
            let fulfilled = try await repository.checkAndFulfillCommitment(
                userId: userId,
                activityType: activity.type
            )

            if fulfilled {
                print("🎉 CommitmentManager: Commitment fulfilled!")
                await loadTodaysCommitment(for: userId)
            } else {
                print("💡 CommitmentManager: Activity did not fulfill commitment")
            }
        } catch {
            print("❌ CommitmentManager: Fulfillment check failed: \(error)")
        }
    }

    // MARK: - Refresh

    func refresh() async {
        guard let userId = UserSession.shared.userId else {
            print("❌ CommitmentManager: No user ID for refresh")
            return
        }

        await loadTodaysCommitment(for: userId)
    }
}

// MARK: - Commitment Errors

enum CommitmentError: Error, LocalizedError {
    case noUserId
    case creationFailed

    var errorDescription: String? {
        switch self {
        case .noUserId:
            return "No user ID available"
        case .creationFailed:
            return "Failed to create commitment"
        }
    }
}
