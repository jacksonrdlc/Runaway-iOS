//
//  CommitmentManager.swift
//  Runaway iOS
//
//  Created by Claude on 12/23/25.
//

import Foundation
import Observation
import WidgetKit

// MARK: - Commitment Manager Protocol

@MainActor protocol CommitmentManagerProtocol: AnyObject {
    var todaysCommitment: DailyCommitment? { get }
    var isLoading: Bool { get }
    var suggestedMicroCommitment: MicroCommitmentType? { get }
    var shouldOfferMicroCommitment: Bool { get }
    var commitmentLevelCounts: (micro: Int, mini: Int, standard: Int) { get }

    func loadTodaysCommitment(for userId: Int) async
    func createCommitment(_ activityType: CommitmentActivityType) async throws
    func createMicroCommitment(_ type: MicroCommitmentType) async throws
    func updateCommitment(to activityType: CommitmentActivityType) async throws
    func deleteCommitment() async throws
    func completeMicroCommitment() async throws
    func checkActivityFulfillsCommitment(_ activity: Activity) async
    func refresh() async
}

// MARK: - Commitment Manager

@MainActor
@Observable
final class CommitmentManager: CommitmentManagerProtocol {

    // MARK: - Observable Properties

    private(set) var todaysCommitment: DailyCommitment?
    private(set) var isLoading = false
    private(set) var suggestedMicroCommitment: MicroCommitmentType?
    private(set) var shouldOfferMicroCommitment: Bool = false
    private(set) var commitmentLevelCounts: (micro: Int, mini: Int, standard: Int) = (0, 0, 0)
    private(set) var suggestedLevel: CommitmentLevel = .standard

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
            syncCommitmentToWidget()

            // Load micro-commitment suggestions
            await loadMicroCommitmentSuggestions(for: userId)
        } catch {
            #if DEBUG
            print("❌ CommitmentManager: Failed to load commitment: \(error)")
            #endif
        }
    }

    /// Load micro-commitment related data
    private func loadMicroCommitmentSuggestions(for userId: Int) async {
        do {
            // Check if we should offer micro-commitments
            self.shouldOfferMicroCommitment = try await CommitmentService.shouldOfferMicroCommitment(for: userId)

            // Get suggested micro-commitment
            self.suggestedMicroCommitment = try await CommitmentService.getSuggestedMicroCommitment(for: userId)

            // Get level counts for ladder
            self.commitmentLevelCounts = try await CommitmentService.getCommitmentLevelCounts(for: userId)

            // Get suggested level
            self.suggestedLevel = try await CommitmentService.getSuggestedCommitmentLevel(for: userId)
        } catch {
            #if DEBUG
            print("❌ CommitmentManager: Failed to load micro-commitment data: \(error)")
            #endif
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
            syncCommitmentToWidget()
        } catch {
            #if DEBUG
            print("❌ CommitmentManager: Failed to create commitment: \(error)")
            #endif
            throw error
        }
    }

    // MARK: - Micro-Commitment Creation

    func createMicroCommitment(_ type: MicroCommitmentType) async throws {
        guard let userId = UserSession.shared.userId else {
            throw CommitmentError.noUserId
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let commitment = DailyCommitment(athleteId: userId, microCommitmentType: type)
            let createdCommitment = try await repository.createCommitment(commitment)
            self.todaysCommitment = createdCommitment
            syncCommitmentToWidget()
            #if DEBUG
            print("✅ CommitmentManager: Created micro-commitment: \(type.displayName)")
            #endif
        } catch {
            #if DEBUG
            print("❌ CommitmentManager: Failed to create micro-commitment: \(error)")
            #endif
            throw error
        }
    }

    // MARK: - Micro-Commitment Completion

    func completeMicroCommitment() async throws {
        guard let currentCommitment = todaysCommitment,
              let commitmentId = currentCommitment.id,
              currentCommitment.isMicroCommitment else {
            throw CommitmentError.noCommitmentToUpdate
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let fulfilledCommitment = try await CommitmentService.completeMicroCommitment(commitmentId: commitmentId)
            self.todaysCommitment = fulfilledCommitment
            syncCommitmentToWidget()

            // Trigger celebration
            CelebrationService.shared.celebrate(for: fulfilledCommitment)

            // Reload suggestions
            if let userId = UserSession.shared.userId {
                await loadMicroCommitmentSuggestions(for: userId)
            }

            #if DEBUG
            print("✅ CommitmentManager: Completed micro-commitment!")
            #endif
        } catch {
            #if DEBUG
            print("❌ CommitmentManager: Failed to complete micro-commitment: \(error)")
            #endif
            throw error
        }
    }

    // MARK: - Commitment Update

    func updateCommitment(to activityType: CommitmentActivityType) async throws {
        guard let userId = UserSession.shared.userId else {
            throw CommitmentError.noUserId
        }

        guard let currentCommitment = todaysCommitment, let commitmentId = currentCommitment.id else {
            throw CommitmentError.noCommitmentToUpdate
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let updatedCommitment = DailyCommitment(
                id: commitmentId,
                athleteId: userId,
                commitmentDate: currentCommitment.commitmentDate,
                activityType: activityType,
                isFulfilled: currentCommitment.isFulfilled,
                fulfilledAt: currentCommitment.fulfilledAt,
                createdAt: currentCommitment.createdAt,
                updatedAt: nil
            )
            let result = try await repository.updateCommitment(updatedCommitment)
            self.todaysCommitment = result
            syncCommitmentToWidget()
            #if DEBUG
            print("✅ CommitmentManager: Updated commitment to \(activityType.displayName)")
            #endif
        } catch {
            #if DEBUG
            print("❌ CommitmentManager: Failed to update commitment: \(error)")
            #endif
            throw error
        }
    }

    // MARK: - Commitment Deletion

    func deleteCommitment() async throws {
        guard let currentCommitment = todaysCommitment, let commitmentId = currentCommitment.id else {
            throw CommitmentError.noCommitmentToDelete
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await repository.deleteCommitment(id: commitmentId)
            self.todaysCommitment = nil
            syncCommitmentToWidget()
            #if DEBUG
            print("✅ CommitmentManager: Deleted commitment")
            #endif
        } catch {
            #if DEBUG
            print("❌ CommitmentManager: Failed to delete commitment: \(error)")
            #endif
            throw error
        }
    }

    // MARK: - Commitment Fulfillment

    func checkActivityFulfillsCommitment(_ activity: Activity) async {
        guard let userId = UserSession.shared.userId else {
            #if DEBUG
            print("❌ CommitmentManager: No user ID for commitment check")
            #endif
            return
        }

        #if DEBUG
        print("🔍 CommitmentManager: Checking if '\(activity.type ?? "unknown")' fulfills commitment")
        #endif

        do {
            let fulfilled = try await repository.checkAndFulfillCommitment(
                userId: userId,
                activityType: activity.type
            )

            if fulfilled {
                #if DEBUG
                print("🎉 CommitmentManager: Commitment fulfilled!")
                #endif
                await loadTodaysCommitment(for: userId)
            } else {
                #if DEBUG
                print("💡 CommitmentManager: Activity did not fulfill commitment")
                #endif
            }
        } catch {
            #if DEBUG
            print("❌ CommitmentManager: Fulfillment check failed: \(error)")
            #endif
        }
    }

    // MARK: - Refresh

    func refresh() async {
        var userId = UserSession.shared.userId
        if userId == nil {
            // Auth state may not be fully restored yet; wait briefly and retry once
            try? await Task.sleep(nanoseconds: 500_000_000)
            userId = UserSession.shared.userId
        }
        guard let userId else {
            #if DEBUG
            print("❌ CommitmentManager: No user ID for refresh")
            #endif
            return
        }
        await loadTodaysCommitment(for: userId)
    }

    // MARK: - Widget Sync

    /// Sync today's commitment to the App Group so the widget reflects current state.
    private func syncCommitmentToWidget() {
        guard let defaults = UserDefaults(suiteName: AppConstants.AppGroup.identifier) else { return }
        if let commitment = todaysCommitment {
            defaults.set(commitment.activityType.rawValue, forKey: AppConstants.WidgetKeys.todaysCommitmentType)
            defaults.set(commitment.isFulfilled, forKey: AppConstants.WidgetKeys.todaysCommitmentFulfilled)
        } else {
            defaults.removeObject(forKey: AppConstants.WidgetKeys.todaysCommitmentType)
            defaults.removeObject(forKey: AppConstants.WidgetKeys.todaysCommitmentFulfilled)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - Commitment Errors

enum CommitmentError: Error, LocalizedError {
    case noUserId
    case creationFailed
    case noCommitmentToUpdate
    case noCommitmentToDelete

    var errorDescription: String? {
        switch self {
        case .noUserId:
            return "No user ID available"
        case .creationFailed:
            return "Failed to create commitment"
        case .noCommitmentToUpdate:
            return "No commitment exists to update"
        case .noCommitmentToDelete:
            return "No commitment exists to delete"
        }
    }
}
