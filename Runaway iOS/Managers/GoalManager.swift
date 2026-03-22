//
//  GoalManager.swift
//  Runaway iOS
//
//  Created by Claude on 12/23/25.
//

import Foundation
import Observation

// MARK: - Goal Manager Protocol

@MainActor protocol GoalManagerProtocol: AnyObject {
    var currentGoal: RunningGoal? { get }
    var isLoading: Bool { get }

    func loadCurrentGoal(for userId: Int) async
    func refresh() async
}

// MARK: - Goal Manager

@MainActor
@Observable
final class GoalManager: GoalManagerProtocol {

    // MARK: - Observable Properties

    private(set) var currentGoal: RunningGoal?
    private(set) var isLoading = false

    // MARK: - Singleton

    static let shared = GoalManager()

    private init() {}

    // MARK: - Data Loading

    func loadCurrentGoal(for userId: Int) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let goals = try await GoalService.getActiveGoals()
            self.currentGoal = Self.selectPriorityGoal(from: goals)
        } catch {
            print("❌ GoalManager: Failed to load goals: \(error)")
        }
    }

    /// Selects the A-race (highest-distance upcoming race within 90 days).
    /// Falls back to the nearest upcoming race if no distance data is available.
    private static func selectPriorityGoal(from goals: [RunningGoal]) -> RunningGoal? {
        let now = Date()
        let horizon = now.addingTimeInterval(90 * 24 * 3600)
        let upcoming = goals.filter { !$0.isCompleted && $0.deadline > now }
        let within90 = upcoming.filter { $0.deadline <= horizon }

        // Among races within 90 days, prefer the longest (A-race)
        if let aRace = within90.max(by: { $0.targetValue < $1.targetValue }) {
            return aRace
        }
        // Fall back to the nearest upcoming race
        return upcoming.first
    }

    // MARK: - Refresh

    func refresh() async {
        guard let userId = UserSession.shared.userId else {
            print("❌ GoalManager: No user ID for refresh")
            return
        }

        await loadCurrentGoal(for: userId)
    }

    // MARK: - Goal Management

    func setCurrentGoal(_ goal: RunningGoal) {
        self.currentGoal = goal
    }

    func clearCurrentGoal() {
        self.currentGoal = nil
    }
}
