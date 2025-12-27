//
//  AthleteStore.swift
//  Runaway iOS
//
//  Created by Claude on 12/23/25.
//

import Foundation

// MARK: - Athlete Store Protocol

protocol AthleteStoreProtocol: ObservableObject {
    var athlete: Athlete? { get }
    var stats: AthleteStats? { get }
    var isLoading: Bool { get }

    func loadAthlete(for userId: Int) async
    func loadStats(for userId: Int) async
}

// MARK: - Athlete Store

@MainActor
final class AthleteStore: ObservableObject, AthleteStoreProtocol {

    // MARK: - Published Properties

    @Published private(set) var athlete: Athlete?
    @Published private(set) var stats: AthleteStats?
    @Published private(set) var isLoading = false

    // MARK: - Private Properties

    private let repository: AthleteRepositoryProtocol

    // MARK: - Singleton

    static let shared = AthleteStore()

    // MARK: - Initialization

    init(repository: AthleteRepositoryProtocol = SupabaseAthleteRepository.shared) {
        self.repository = repository
    }

    // MARK: - Data Loading

    func loadAthlete(for userId: Int) async {
        isLoading = true
        defer { isLoading = false }

        do {
            print("🔍 AthleteStore: Loading athlete for user ID: \(userId)")
            let fetchedAthlete = try await repository.getAthlete(userId: userId)
            print("✅ AthleteStore: Loaded athlete: \(fetchedAthlete.firstname ?? "Unknown") \(fetchedAthlete.lastname ?? "Athlete")")
            self.athlete = fetchedAthlete
        } catch {
            print("❌ AthleteStore: Failed to load athlete: \(error)")
        }
    }

    func loadStats(for userId: Int) async {
        do {
            let fetchedStats = try await repository.getAthleteStats(userId: userId)
            self.stats = fetchedStats
            if fetchedStats == nil {
                print("⚠️ AthleteStore: No stats available")
            }
        } catch {
            print("❌ AthleteStore: Failed to load stats: \(error)")
        }
    }

    // MARK: - Convenience Methods

    func loadAll(for userId: Int) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadAthlete(for: userId) }
            group.addTask { await self.loadStats(for: userId) }
        }
    }

    func refresh() async {
        guard let userId = UserSession.shared.userId else {
            print("❌ AthleteStore: No user ID available for refresh")
            return
        }

        await loadAll(for: userId)
    }
}
