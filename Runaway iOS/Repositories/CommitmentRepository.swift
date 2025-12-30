//
//  CommitmentRepository.swift
//  Runaway iOS
//
//  Created by Claude on 12/23/25.
//

import Foundation

// MARK: - Commitment Repository Protocol

/// Protocol defining commitment data access operations
protocol CommitmentRepositoryProtocol {
    func getTodaysCommitment(userId: Int) async throws -> DailyCommitment?
    func createCommitment(_ commitment: DailyCommitment) async throws -> DailyCommitment
    func updateCommitment(_ commitment: DailyCommitment) async throws -> DailyCommitment
    func deleteCommitment(id: Int) async throws
    func fulfillCommitment(commitmentId: Int) async throws -> DailyCommitment
    func checkAndFulfillCommitment(userId: Int, activityType: String?) async throws -> Bool
}

// MARK: - Supabase Commitment Repository

final class SupabaseCommitmentRepository: CommitmentRepositoryProtocol {

    static let shared = SupabaseCommitmentRepository()

    private init() {}

    func getTodaysCommitment(userId: Int) async throws -> DailyCommitment? {
        return try await CommitmentService.getTodaysCommitment(for: userId)
    }

    func createCommitment(_ commitment: DailyCommitment) async throws -> DailyCommitment {
        return try await CommitmentService.createCommitment(commitment)
    }

    func updateCommitment(_ commitment: DailyCommitment) async throws -> DailyCommitment {
        return try await CommitmentService.updateCommitment(commitment)
    }

    func deleteCommitment(id: Int) async throws {
        try await CommitmentService.deleteCommitment(id: id)
    }

    func fulfillCommitment(commitmentId: Int) async throws -> DailyCommitment {
        return try await CommitmentService.fulfillCommitment(commitmentId: commitmentId)
    }

    func checkAndFulfillCommitment(userId: Int, activityType: String?) async throws -> Bool {
        return try await CommitmentService.checkAndFulfillCommitment(for: userId, activityType: activityType)
    }
}

// MARK: - Mock Commitment Repository (for testing)

#if DEBUG
final class MockCommitmentRepository: CommitmentRepositoryProtocol {

    var mockCommitment: DailyCommitment?
    var shouldThrowError = false

    func getTodaysCommitment(userId: Int) async throws -> DailyCommitment? {
        if shouldThrowError { throw RepositoryError.networkError }
        return mockCommitment
    }

    func createCommitment(_ commitment: DailyCommitment) async throws -> DailyCommitment {
        if shouldThrowError { throw RepositoryError.networkError }
        mockCommitment = commitment
        return commitment
    }

    func updateCommitment(_ commitment: DailyCommitment) async throws -> DailyCommitment {
        if shouldThrowError { throw RepositoryError.networkError }
        mockCommitment = commitment
        return commitment
    }

    func deleteCommitment(id: Int) async throws {
        if shouldThrowError { throw RepositoryError.networkError }
        mockCommitment = nil
    }

    func fulfillCommitment(commitmentId: Int) async throws -> DailyCommitment {
        if shouldThrowError { throw RepositoryError.networkError }
        guard let commitment = mockCommitment else {
            throw RepositoryError.notFound
        }
        // Create new commitment with fulfilled status (immutable struct)
        let fulfilledCommitment = DailyCommitment(
            id: commitment.id,
            athleteId: commitment.athleteId,
            commitmentDate: commitment.commitmentDate,
            activityType: commitment.activityType,
            isFulfilled: true,
            fulfilledAt: ISO8601DateFormatter().string(from: Date()),
            createdAt: commitment.createdAt,
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
        mockCommitment = fulfilledCommitment
        return fulfilledCommitment
    }

    func checkAndFulfillCommitment(userId: Int, activityType: String?) async throws -> Bool {
        if shouldThrowError { throw RepositoryError.networkError }
        return mockCommitment != nil && !mockCommitment!.isFulfilled
    }
}
#endif
