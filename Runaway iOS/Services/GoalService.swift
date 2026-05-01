//
//  GoalService.swift
//  Runaway iOS
//

import Foundation
import Supabase
import WidgetKit

struct AthleteRace: Codable, Identifiable, Sendable {
    let id: Int?
    let athleteId: Int
    let runsignupRaceId: Int
    let eventId: Int?
    let raceName: String
    let raceDate: String?
    let city: String?
    let state: String?
    let countryCode: String?
    let logoUrl: String?
    let externalUrl: String?
    let distanceMiles: Double?
    let syncedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case athleteId       = "athlete_id"
        case runsignupRaceId = "runsignup_race_id"
        case eventId         = "event_id"
        case raceName        = "race_name"
        case raceDate        = "race_date"
        case city, state
        case countryCode     = "country_code"
        case logoUrl         = "logo_url"
        case externalUrl     = "external_url"
        case distanceMiles   = "distance_miles"
        case syncedAt        = "synced_at"
    }

    var parsedDate: Date? {
        guard let s = raceDate else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        f.timeZone = TimeZone(identifier: "UTC")
        return f.date(from: s)
    }

    var isUpcoming: Bool {
        guard let d = parsedDate else { return false }
        return d >= Calendar.current.startOfDay(for: Date())
    }

    var locationString: String? {
        let cityPart = city ?? ""
        let statePart = state ?? ""
        if cityPart.isEmpty && statePart.isEmpty { return nil }
        if cityPart.isEmpty { return statePart }
        if statePart.isEmpty { return cityPart }
        return "\(cityPart), \(statePart)"
    }

    /// Detected or stored distance in miles. Prefer stored API value; fall back to name parsing.
    var detectedDistance: Double {
        if let stored = distanceMiles, stored > 0 { return stored }
        return nameBasedDistance ?? 13.1
    }

    /// Returns distance only when confidently identified — used for display and A-race prioritization.
    var knownDistance: Double? {
        if let stored = distanceMiles, stored > 0 { return stored }
        return nameBasedDistance
    }

    private var nameBasedDistance: Double? {
        let lower = raceName.lowercased()
        if lower.contains("100 miler") || lower.contains("100mi") { return 100.0 }
        if lower.contains("100k") { return 62.14 }
        if lower.contains("50k") { return 31.07 }
        if lower.contains("marathon") && !lower.contains("half") { return 26.219 }
        if lower.contains("half marathon") || lower.contains("half-marathon") { return 13.11 }
        if lower.contains("half") { return 13.11 }
        if lower.contains("10k") || lower.contains("10 km") { return 6.21 }
        if lower.contains("5k") || lower.contains("5 km") { return 3.11 }
        return nil
    }

    /// Human-readable distance label for display.
    var distanceLabel: String? {
        guard let d = knownDistance else { return nil }
        switch d {
        case 3.0..<3.5:   return "5K"
        case 6.0..<6.5:   return "10K"
        case 13.0..<13.5: return "Half Marathon"
        case 26.0..<27.0: return "Marathon"
        case 31.0..<32.0: return "50K"
        case 62.0..<63.0: return "100K"
        case 99.0...101.0: return "100 Mi"
        default:           return String(format: "%.1f mi", d)
        }
    }

    func toRunningGoal() -> RunningGoal {
        let deadline = parsedDate ?? Date().addingTimeInterval(365 * 24 * 3600)
        return RunningGoal(
            id: id,
            athleteId: athleteId,
            type: .distance,
            targetValue: detectedDistance,
            deadline: deadline,
            createdDate: Date(),
            updatedDate: nil,
            title: raceName,
            isActive: isUpcoming,
            isCompleted: !isUpcoming,
            currentProgress: 0,
            completedDate: isUpcoming ? nil : deadline
        )
    }
}

class GoalService {
    private static func getCurrentUserId() async throws -> Int {
        let userId = await MainActor.run { UserSession.shared.userId }
        guard let u = userId else { throw GoalServiceError.userNotAuthenticated }
        return u
    }

    static func getAllRaces() async throws -> [AthleteRace] {
        let userId = try await getCurrentUserId()
        #if DEBUG
        print("🔍 GoalService: Fetching races for athlete: \(userId)")
        #endif
        let races: [AthleteRace] = try await supabase
            .from("athlete_races")
            .select("*")
            .eq("athlete_id", value: userId)
            .order("race_date", ascending: true)
            .execute()
            .value
        #if DEBUG
        print("📊 GoalService: Found \(races.count) races in DB")
        #endif
        return races
    }

    static func getUpcomingRaces() async throws -> [AthleteRace] {
        let all = try await getAllRaces()
        return all.filter { $0.isUpcoming }
    }

    static func getPastRaces() async throws -> [AthleteRace] {
        let all = try await getAllRaces()
        return all.filter { !$0.isUpcoming }.reversed()
    }

    static func getNextRace() async throws -> AthleteRace? {
        let upcoming = try await getUpcomingRaces()
        return upcoming.first
    }

    static func getActiveGoals() async throws -> [RunningGoal] {
        let races = try await getUpcomingRaces()
        return races.map { $0.toRunningGoal() }
    }

    static func getAllGoals() async throws -> [RunningGoal] {
        let races = try await getAllRaces()
        return races.map { $0.toRunningGoal() }
    }

    static func getGoalById(_ goalId: Int) async throws -> RunningGoal? {
        let userId = try await getCurrentUserId()
        let races: [AthleteRace] = try await supabase
            .from("athlete_races")
            .select("*")
            .eq("id", value: goalId)
            .eq("athlete_id", value: userId)
            .limit(1)
            .execute()
            .value
        return races.first?.toRunningGoal()
    }

    static func createGoal(_ goal: RunningGoal) async throws -> RunningGoal { return goal }
    static func updateGoal(_ goal: RunningGoal) async throws -> RunningGoal { return goal }
    static func updateGoalProgress(goalId: Int, progress: Double) async throws -> RunningGoal {
        guard let g = try await getGoalById(goalId) else { throw GoalServiceError.goalNotFound }
        return g
    }
    static func completeGoal(goalId: Int) async throws {}
    static func deactivateGoal(goalId: Int) async throws -> RunningGoal {
        guard let g = try await getGoalById(goalId) else { throw GoalServiceError.goalNotFound }
        return g
    }
    static func deactivateGoalsOfType(_ type: GoalType) async throws {}
    static func getCurrentGoal(ofType type: GoalType) async throws -> RunningGoal? {
        let active = try await getActiveGoals()
        return active.first { $0.type == type }
    }
    static func deleteGoal(goalId: Int) async throws {
        WidgetSyncService.refreshForGoalUpdate()
    }
    static func getGoalStats() async throws -> GoalStats {
        let all = try await getAllGoals()
        return GoalStats(
            totalGoals: all.count,
            completedGoals: all.filter { $0.isCompleted }.count,
            activeGoals: all.filter { $0.isActive }.count,
            averageProgress: 0
        )
    }
}

enum GoalServiceError: LocalizedError {
    case userNotAuthenticated
    case invalidGoalId
    case goalNotFound
    case duplicateActiveGoal
    case networkError(String)
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated: return "User not authenticated"
        case .invalidGoalId: return "Invalid goal ID"
        case .goalNotFound: return "Goal not found"
        case .duplicateActiveGoal: return "Goal type duplicate"
        case .networkError(let m): return "Network error: \(m)"
        }
    }
}

struct GoalStats {
    let totalGoals: Int
    let completedGoals: Int
    let activeGoals: Int
    let averageProgress: Double
    var completionRate: Double { totalGoals > 0 ? Double(completedGoals) / Double(totalGoals) : 0 }
}
