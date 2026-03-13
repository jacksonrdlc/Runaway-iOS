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
            self.currentGoal = goals.first { !$0.isCompleted }
        } catch {
            print("❌ GoalManager: Failed to load goals: \(error)")
        }
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
