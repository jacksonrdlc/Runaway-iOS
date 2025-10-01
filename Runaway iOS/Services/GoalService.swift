//
//  GoalService.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 6/28/25.
//

import Foundation
import Supabase
import WidgetKit

class GoalService {
    
    // MARK: - Helper Methods
    
    /// Get the current user ID safely from MainActor context
    private static func getCurrentUserId() async throws -> Int {
        let userId = await MainActor.run {
            UserManager.shared.userId
        }
        guard let userId = userId else {
            throw GoalServiceError.userNotAuthenticated
        }
        return userId
    }
    
    // MARK: - Create Operations
    
    /// Create a new running goal for the authenticated user
    static func createGoal(_ goal: RunningGoal) async throws -> RunningGoal {
        let userId = try await getCurrentUserId()
        
        // Create a new goal with the user ID set
        let goalWithUserId = RunningGoal(
            id: nil,
            athleteId: userId,
            type: goal.type,
            targetValue: goal.targetValue,
            deadline: goal.deadline,
            createdDate: Date(),
            updatedDate: nil,
            title: goal.title,
            isActive: true,
            isCompleted: false,
            currentProgress: 0.0,
            completedDate: nil
        )
        
        let response: RunningGoal = try await supabase
            .from("running_goals")
            .insert(goalWithUserId)
            .select()
            .single()
            .execute()
            .value
        
        print("✅ Goal created successfully: \(response.title)")
        
        // Refresh widgets after creating goal
        WidgetRefreshService.refreshForGoalUpdate()
        
        return response
    }
    
    // MARK: - Read Operations
    
    /// Get all active goals for the authenticated user
    static func getActiveGoals() async throws -> [RunningGoal] {
        let userId = try await getCurrentUserId()
        
        let goals: [RunningGoal] = try await supabase
            .from("running_goals")
            .select("*")
            .eq("athlete_id", value: userId)
            .eq("is_active", value: true)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        print("📊 Retrieved \(goals.count) active goals")
        return goals
    }
    
    /// Get a specific goal by ID
    static func getGoalById(_ goalId: Int) async throws -> RunningGoal? {
        let userId = try await getCurrentUserId()
        
        let goals: [RunningGoal] = try await supabase
            .from("running_goals")
            .select("*")
            .eq("id", value: goalId)
            .eq("athlete_id", value: userId)
            .limit(1)
            .execute()
            .value
        
        return goals.first
    }
    
    /// Get all goals (active and inactive) for the authenticated user
    static func getAllGoals() async throws -> [RunningGoal] {
        let userId = try await getCurrentUserId()
        
        let goals: [RunningGoal] = try await supabase
            .from("running_goals")
            .select("*")
            .eq("athlete_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        print("📊 Retrieved \(goals.count) total goals")
        return goals
    }
    
    /// Get the most recent active goal of a specific type
    static func getCurrentGoal(ofType type: GoalType) async throws -> RunningGoal? {
        let userId = try await getCurrentUserId()
        
        let goals: [RunningGoal] = try await supabase
            .from("running_goals")
            .select("*")
            .eq("athlete_id", value: userId)
            .eq("goal_type", value: type.rawValue)
            .eq("is_active", value: true)
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value
        
        return goals.first
    }
    
    // MARK: - Update Operations
    
    /// Update an existing goal
    static func updateGoal(_ goal: RunningGoal) async throws -> RunningGoal {
        guard let goalId = goal.id else {
            throw GoalServiceError.invalidGoalId
        }
        
        let userId = try await getCurrentUserId()
        
        let updatedGoal: RunningGoal = try await supabase
            .from("running_goals")
            .update(goal)
            .eq("id", value: goalId)
            .eq("athlete_id", value: userId)
            .select()
            .single()
            .execute()
            .value
        
        print("✅ Goal updated successfully: \(updatedGoal.title)")
        
        // Refresh widgets after updating goal
        WidgetRefreshService.refreshForGoalUpdate()
        
        return updatedGoal
    }
    
    /// Update goal progress
    static func updateGoalProgress(goalId: Int, progress: Double) async throws -> RunningGoal {
        // First get the existing goal
        guard let existingGoal = try await getGoalById(goalId) else {
            throw GoalServiceError.goalNotFound
        }
        
        let clampedProgress = max(0.0, min(1.0, progress))
        let isCompleted = clampedProgress >= 1.0
        
        // Create updated goal with new progress
        let updatedGoal = RunningGoal(
            id: existingGoal.id,
            athleteId: existingGoal.athleteId,
            type: existingGoal.type,
            targetValue: existingGoal.targetValue,
            deadline: existingGoal.deadline,
            createdDate: existingGoal.createdDate,
            updatedDate: Date(),
            title: existingGoal.title,
            isActive: existingGoal.isActive,
            isCompleted: isCompleted,
            currentProgress: clampedProgress,
            completedDate: isCompleted ? Date() : nil
        )
        
        let result = try await updateGoal(updatedGoal)
        print("📈 Goal progress updated: \(Int(clampedProgress * 100))%")
        return result
    }
    
    /// Mark a goal as completed
    static func completeGoal(goalId: Int) async throws -> RunningGoal {
        return try await updateGoalProgress(goalId: goalId, progress: 1.0)
    }
    
    /// Deactivate a goal (soft delete)
    static func deactivateGoal(goalId: Int) async throws -> RunningGoal {
        // First get the existing goal
        guard let existingGoal = try await getGoalById(goalId) else {
            throw GoalServiceError.goalNotFound
        }
        
        // Create updated goal with deactivated status
        let deactivatedGoal = RunningGoal(
            id: existingGoal.id,
            athleteId: existingGoal.athleteId,
            type: existingGoal.type,
            targetValue: existingGoal.targetValue,
            deadline: existingGoal.deadline,
            createdDate: existingGoal.createdDate,
            updatedDate: Date(),
            title: existingGoal.title,
            isActive: false,
            isCompleted: existingGoal.isCompleted,
            currentProgress: existingGoal.currentProgress,
            completedDate: existingGoal.completedDate
        )
        
        let result = try await updateGoal(deactivatedGoal)
        print("🗂️ Goal deactivated: \(result.title)")
        return result
    }
    
    // MARK: - Delete Operations
    
    /// Permanently delete a goal
    static func deleteGoal(goalId: Int) async throws {
        let userId = try await getCurrentUserId()
        
        try await supabase
            .from("running_goals")
            .delete()
            .eq("id", value: goalId)
            .eq("athlete_id", value: userId)
            .execute()
        
        print("🗑️ Goal deleted permanently")
        
        // Refresh widgets after deleting goal
        WidgetRefreshService.refreshForGoalUpdate()
    }
    
    // MARK: - Batch Operations
    
    /// Deactivate all goals of a specific type (useful when creating a new goal)
    static func deactivateGoalsOfType(_ type: GoalType) async throws {
        // Get all active goals of this type
        let activeGoals = try await getActiveGoals()
        let goalsOfType = activeGoals.filter { $0.type == type }
        
        // Deactivate each goal individually
        for goal in goalsOfType {
            if let goalId = goal.id {
                _ = try await deactivateGoal(goalId: goalId)
            }
        }
        
        print("🔄 Deactivated \(goalsOfType.count) existing \(type.displayName.lowercased()) goals")
    }
    
    // MARK: - Analytics Operations
    
    /// Get goal completion statistics
    static func getGoalStats() async throws -> GoalStats {
        let userId = try await getCurrentUserId()
        
        let allGoals: [RunningGoal] = try await getAllGoals()
        
        let totalGoals = allGoals.count
        let completedGoals = allGoals.filter { $0.isCompleted }.count
        let activeGoals = allGoals.filter { $0.isActive && !$0.isCompleted }.count
        let averageProgress = allGoals.isEmpty ? 0.0 : allGoals.reduce(0) { $0 + $1.currentProgress } / Double(allGoals.count)
        
        return GoalStats(
            totalGoals: totalGoals,
            completedGoals: completedGoals,
            activeGoals: activeGoals,
            averageProgress: averageProgress
        )
    }
}

// MARK: - Error Types
enum GoalServiceError: LocalizedError {
    case userNotAuthenticated
    case invalidGoalId
    case goalNotFound
    case duplicateActiveGoal
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User is not authenticated"
        case .invalidGoalId:
            return "Invalid goal ID"
        case .goalNotFound:
            return "Goal not found"
        case .duplicateActiveGoal:
            return "An active goal of this type already exists"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

// MARK: - Supporting Data Models
struct GoalStats {
    let totalGoals: Int
    let completedGoals: Int
    let activeGoals: Int
    let averageProgress: Double
    
    var completionRate: Double {
        return totalGoals > 0 ? Double(completedGoals) / Double(totalGoals) : 0.0
    }
}