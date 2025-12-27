//
//  AthleteRepository.swift
//  Runaway iOS
//
//  Created by Claude on 12/23/25.
//

import Foundation

// MARK: - Athlete Repository Protocol

/// Protocol defining athlete data access operations
protocol AthleteRepositoryProtocol {
    func getAthlete(userId: Int) async throws -> Athlete
    func getAthleteStats(userId: Int) async throws -> AthleteStats?
    func updateAthlete(_ athlete: Athlete) async throws -> Athlete
}

// MARK: - Supabase Athlete Repository

final class SupabaseAthleteRepository: AthleteRepositoryProtocol {

    static let shared = SupabaseAthleteRepository()

    private init() {}

    func getAthlete(userId: Int) async throws -> Athlete {
        return try await AthleteService.getAthleteByUserId(userId: userId)
    }

    func getAthleteStats(userId: Int) async throws -> AthleteStats? {
        return try await AthleteService.getAthleteStats(userId: userId)
    }

    func updateAthlete(_ athlete: Athlete) async throws -> Athlete {
        // AthleteService doesn't have an update method currently
        // Return the athlete as-is for now
        return athlete
    }
}

// MARK: - Mock Athlete Repository (for testing)

#if DEBUG
final class MockAthleteRepository: AthleteRepositoryProtocol {

    var mockAthlete: Athlete?
    var mockStats: AthleteStats?
    var shouldThrowError = false

    func getAthlete(userId: Int) async throws -> Athlete {
        if shouldThrowError { throw RepositoryError.networkError }
        guard let athlete = mockAthlete else {
            throw RepositoryError.notFound
        }
        return athlete
    }

    func getAthleteStats(userId: Int) async throws -> AthleteStats? {
        if shouldThrowError { throw RepositoryError.networkError }
        return mockStats
    }

    func updateAthlete(_ athlete: Athlete) async throws -> Athlete {
        if shouldThrowError { throw RepositoryError.networkError }
        mockAthlete = athlete
        return athlete
    }
}
#endif
