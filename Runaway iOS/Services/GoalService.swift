//
//  GoalService.swift
//  Runaway iOS
//
//  Reads goals from the shared `goals` table (web source of truth).
//  The old `running_goals` table was iOS-only and out of sync with the web platform.
//

import Foundation
import Supabase
import WidgetKit

// MARK: - GoalRecord  (matches the `goals` table schema)

struct GoalRecord: Codable {
    let id: Int?
    let athleteId: Int?
    let goalType: String           // "distance", "race_time", "pace", "weekly_mileage"
    let activityType: String?      // "run", "walk", etc.
    let targetValue: Double?
    let currentValue: Double?
    let startDate: String?         // ISO date string
    let endDate: String?           // ISO date string — this is the race/deadline date
    let timePeriod: String?
    let completed: Bool?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case athleteId     = "athlete_id"
        case goalType      = "goal_type"
        case activityType  = "activity_type"
        case targetValue   = "target_value"
        case currentValue  = "current_value"
        case startDate     = "start_date"
        case endDate       = "end_date"
        case timePeriod    = "time_period"
        case completed
        case createdAt     = "created_at"
    }

    // MARK: - Derived properties

    /// Human-readable title generated from goal_type + target_value
    var derivedTitle: String {
        switch goalType {
        case "distance":
            guard let val = targetValue else { return "Distance Goal" }
            let activity = activityType?.capitalized ?? "Run"
            // Recognise common race distances
            if abs(val - 26.2) < 0.2 { return "\(activity) a Marathon" }
            if abs(val - 13.1) < 0.2 { return "\(activity) a Half Marathon" }
            if abs(val - 6.2)  < 0.2 { return "\(activity) a 10K" }
            if abs(val - 3.1)  < 0.2 { return "\(activity) a 5K" }
            if abs(val - 50)   < 1   { return "\(activity) a 50K" }
            if abs(val - 31)   < 1   { return "\(activity) a 50K" }
            if abs(val - 62)   < 1   { return "\(activity) a 100K" }
            if abs(val - 100)  < 2   { return "\(activity) a 100-Miler" }
            return String(format: "\(activity) %.0f miles", val)
        case "race_time":
            return "Race Time Goal"
        case "pace":
            return "Pace Goal"
        case "weekly_mileage":
            return "Weekly Mileage Goal"
        default:
            return goalType.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    /// Convert to RunningGoal for use throughout the app
    func toRunningGoal() -> RunningGoal? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]

        let fullIso = ISO8601DateFormatter()

        func parseDate(_ s: String?) -> Date? {
            guard let s = s else { return nil }
            return iso.date(from: s) ?? fullIso.date(from: s)
        }

        let deadline = parseDate(endDate) ?? Date().addingTimeInterval(365 * 24 * 3600)
        let created  = parseDate(startDate) ?? parseDate(createdAt) ?? Date()

        let goalType: GoalType
        switch self.goalType {
        case "distance", "weekly_mileage": goalType = .distance
        case "race_time":                  goalType = .time
        case "pace":                       goalType = .pace
        default:                           goalType = .distance
        }

        return RunningGoal(
            id: id,
            athleteId: athleteId,
            type: goalType,
            targetValue: targetValue ?? 0,
            deadline: deadline,
            createdDate: created,
            updatedDate: nil,
            title: derivedTitle,
            isActive: !(completed ?? false),
            isCompleted: completed ?? false,
            currentProgress: {
                guard let cur = currentValue, let tgt = targetValue, tgt > 0 else { return 0 }
                return min(1.0, cur / tgt)
            }(),
            completedDate: nil
        )
    }
}

// MARK: - GoalService

class GoalService {

    private static func getCurrentUserId() async throws -> Int {
        let userId = await MainActor.run { UserSession.shared.userId }
        guard let userId else { throw GoalServiceError.userNotAuthenticated }
        return userId
    }

    // MARK: - Read

    static func getActiveGoals() async throws -> [RunningGoal] {
        let userId = try await getCurrentUserId()
        let records: [GoalRecord] = try await supabase
            .from("goals")
            .select("*")
            .eq("athlete_id", value: userId)
            .eq("completed", value: false)
            .order("end_date", ascending: true)
            .execute()
            .value
        let goals = records.compactMap { $0.toRunningGoal() }
        print("📊 Retrieved \(goals.count) active goals from `goals` table")
        return goals
    }

    static func getAllGoals() async throws -> [RunningGoal] {
        let userId = try await getCurrentUserId()
        let records: [GoalRecord] = try await supabase
            .from("goals")
            .select("*")
            .eq("athlete_id", value: userId)
            .order("end_date", ascending: false)
            .execute()
            .value
        let goals = records.compactMap { $0.toRunningGoal() }
        print("📊 Retrieved \(goals.count) total goals from `goals` table")
        return goals
    }

    static func getGoalById(_ goalId: Int) async throws -> RunningGoal? {
        let userId = try await getCurrentUserId()
        let records: [GoalRecord] = try await supabase
            .from("goals")
            .select("*")
            .eq("id", value: goalId)
            .eq("athlete_id", value: userId)
            .limit(1)
            .execute()
            .value
        return records.first?.toRunningGoal()
    }

    // MARK: - Create (writes to `goals` table)

    static func createGoal(_ goal: RunningGoal) async throws -> RunningGoal {
        let userId = try await getCurrentUserId()
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]

        struct GoalInsert: Encodable {
            let athlete_id: Int
            let goal_type: String
            let activity_type: String
            let target_value: Double
            let end_date: String
            let start_date: String
            let completed: Bool
        }

        let insert = GoalInsert(
            athlete_id: userId,
            goal_type: goal.type == .time ? "race_time" : goal.type.rawValue,
            activity_type: "run",
            target_value: goal.targetValue,
            end_date: iso.string(from: goal.deadline),
            start_date: iso.string(from: goal.createdDate),
            completed: false
        )

        let record: GoalRecord = try await supabase
            .from("goals")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value

        guard let created = record.toRunningGoal() else {
            throw GoalServiceError.goalNotFound
        }

        print("✅ Goal created: \(created.title)")
        WidgetRefreshService.refreshForGoalUpdate()
        return created
    }

    // MARK: - Update

    static func completeGoal(goalId: Int) async throws {
        let userId = try await getCurrentUserId()
        try await supabase
            .from("goals")
            .update(["completed": true])
            .eq("id", value: goalId)
            .eq("athlete_id", value: userId)
            .execute()
        WidgetRefreshService.refreshForGoalUpdate()
        print("✅ Goal \(goalId) marked complete")
    }

    static func deleteGoal(goalId: Int) async throws {
        let userId = try await getCurrentUserId()
        try await supabase
            .from("goals")
            .delete()
            .eq("id", value: goalId)
            .eq("athlete_id", value: userId)
            .execute()
        WidgetRefreshService.refreshForGoalUpdate()
        print("🗑️ Goal \(goalId) deleted")
    }

    // MARK: - Stats

    static func getGoalStats() async throws -> GoalStats {
        let all = try await getAllGoals()
        return GoalStats(
            totalGoals: all.count,
            completedGoals: all.filter { $0.isCompleted }.count,
            activeGoals: all.filter { $0.isActive && !$0.isCompleted }.count,
            averageProgress: all.isEmpty ? 0 : all.reduce(0) { $0 + $1.currentProgress } / Double(all.count)
        )
    }

    // MARK: - Legacy stubs (kept for call-site compatibility)

    static func updateGoal(_ goal: RunningGoal) async throws -> RunningGoal { return goal }
    static func updateGoalProgress(goalId: Int, progress: Double) async throws -> RunningGoal {
        guard let g = try await getGoalById(goalId) else { throw GoalServiceError.goalNotFound }
        return g
    }
    static func deactivateGoal(goalId: Int) async throws -> RunningGoal {
        guard let g = try await getGoalById(goalId) else { throw GoalServiceError.goalNotFound }
        return g
    }
    static func deactivateGoalsOfType(_ type: GoalType) async throws {}
    static func getCurrentGoal(ofType type: GoalType) async throws -> RunningGoal? {
        return try await getActiveGoals().first { $0.type == type }
    }
}

// MARK: - Errors

enum GoalServiceError: LocalizedError {
    case userNotAuthenticated
    case invalidGoalId
    case goalNotFound
    case duplicateActiveGoal
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:   return "User is not authenticated"
        case .invalidGoalId:          return "Invalid goal ID"
        case .goalNotFound:           return "Goal not found"
        case .duplicateActiveGoal:    return "An active goal of this type already exists"
        case .networkError(let m):    return "Network error: \(m)"
        }
    }
}

// MARK: - Stats

struct GoalStats {
    let totalGoals: Int
    let completedGoals: Int
    let activeGoals: Int
    let averageProgress: Double
    var completionRate: Double { totalGoals > 0 ? Double(completedGoals) / Double(totalGoals) : 0 }
}
