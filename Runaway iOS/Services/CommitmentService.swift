//
//  CommitmentService.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 9/16/25.
//

import Foundation
import Supabase

class CommitmentService {

    // MARK: - Create Commitment

    static func createCommitment(_ commitment: DailyCommitment) async throws -> DailyCommitment {
        let response = try await supabase
            .from("daily_commitments")
            .insert(commitment)
            .select()
            .execute()

        let data = response.data
        let createdCommitment = try JSONDecoder().decode([DailyCommitment].self, from: data).first

        guard let result = createdCommitment else {
            throw SupabaseError.decodingError("Failed to decode created commitment")
        }

        print("✅ CommitmentService: Created commitment: \(result)")
        return result
    }

    // MARK: - Get Today's Commitment

    static func getTodaysCommitment(for userId: Int) async throws -> DailyCommitment? {
        let today = DateFormatter.dateOnly.string(from: Date())
        print("🔍 CommitmentService: Getting today's commitment for user \(userId) on \(today)")

        let response = try await supabase
            .from("daily_commitments")
            .select()
            .eq("athlete_id", value: userId)  // Changed to athlete_id
            .eq("commitment_date", value: today)
            .execute()

        let data = response.data
        let commitments = try JSONDecoder().decode([DailyCommitment].self, from: data)

        print("🔍 CommitmentService: Found \(commitments.count) commitment(s) for today")
        if let commitment = commitments.first {
            print("🔍 CommitmentService: Today's commitment - Type: \(commitment.activityType.rawValue), Fulfilled: \(commitment.isFulfilled)")
        }

        return commitments.first
    }

    // MARK: - Update Commitment

    static func updateCommitment(_ commitment: DailyCommitment) async throws -> DailyCommitment {
        guard let commitmentId = commitment.id else {
            throw SupabaseError.invalidData("Commitment ID is required for update")
        }

        let response = try await supabase
            .from("daily_commitments")
            .update(commitment)
            .eq("id", value: commitmentId)
            .select()
            .execute()

        let data = response.data
        let updatedCommitment = try JSONDecoder().decode([DailyCommitment].self, from: data).first

        guard let result = updatedCommitment else {
            throw SupabaseError.decodingError("Failed to decode updated commitment")
        }

        print("✅ CommitmentService: Updated commitment: \(result)")
        return result
    }

    // MARK: - Mark Commitment as Fulfilled

    static func fulfillCommitment(commitmentId: Int) async throws -> DailyCommitment {
        let now = DateFormatter.iso8601.string(from: Date())

        let updateData = CommitmentFulfillmentUpdate(
            isFulfilled: true,
            fulfilledAt: now,
            updatedAt: now
        )

        let response = try await supabase
            .from("daily_commitments")
            .update(updateData)
            .eq("id", value: commitmentId)
            .select()
            .execute()

        let data = response.data
        let updatedCommitment = try JSONDecoder().decode([DailyCommitment].self, from: data).first

        guard let result = updatedCommitment else {
            throw SupabaseError.decodingError("Failed to decode fulfilled commitment")
        }

        print("✅ CommitmentService: Fulfilled commitment: \(result)")
        return result
    }

    // MARK: - Check if Activity Type Fulfills Commitment

    static func checkAndFulfillCommitment(for userId: Int, activityType: String?) async throws -> Bool {
        guard let todaysCommitment = try await getTodaysCommitment(for: userId),
              !todaysCommitment.isFulfilled else {
            return false // No commitment or already fulfilled
        }

        // Check if the activity type matches the commitment
        let normalizedActivityType = activityType?.lowercased() ?? ""
        let commitmentType = todaysCommitment.activityType.rawValue.lowercased()

        // Handle activity type matching with more comprehensive logic
        let isMatch: Bool

        // Direct match first
        if normalizedActivityType == commitmentType {
            isMatch = true
        } else {
            // Handle specific activity type variations
            switch todaysCommitment.activityType {
            case .run:
                isMatch = normalizedActivityType == "run" || normalizedActivityType.contains("running")
            case .walk:
                isMatch = normalizedActivityType == "walk" || normalizedActivityType.contains("walking")
            case .workout:
                // "Weight Training" should match "Workout" commitment
                isMatch = normalizedActivityType.contains("workout") ||
                         normalizedActivityType.contains("weight") ||
                         normalizedActivityType.contains("training") ||
                         normalizedActivityType.contains("strength") ||
                         normalizedActivityType.contains("gym")
            case .yoga:
                isMatch = normalizedActivityType.contains("yoga") || normalizedActivityType.contains("meditation")
            }
        }

        print("🔍 CommitmentService: Checking activity type '\(normalizedActivityType)' against commitment '\(commitmentType)' - Match: \(isMatch)")

        if isMatch {
            _ = try await fulfillCommitment(commitmentId: todaysCommitment.id!)
            return true
        }

        return false
    }

    // MARK: - Get User's Commitment History

    static func getCommitmentHistory(for userId: Int, limit: Int = 30) async throws -> [DailyCommitment] {
        let response = try await supabase
            .from("daily_commitments")
            .select()
            .eq("athlete_id", value: userId)  // Changed to athlete_id
            .order("commitment_date", ascending: false)
            .limit(limit)
            .execute()

        let data = response.data
        let commitments = try JSONDecoder().decode([DailyCommitment].self, from: data)

        return commitments
    }

    // MARK: - Delete Commitment

    static func deleteCommitment(id: Int) async throws {
        _ = try await supabase
            .from("daily_commitments")
            .delete()
            .eq("id", value: id)
            .execute()

        print("✅ CommitmentService: Deleted commitment with id: \(id)")
    }

    // MARK: - Get Commitment Stats

    static func getCommitmentStats(for userId: Int, days: Int = 30) async throws -> CommitmentStats {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let startDateString = DateFormatter.dateOnly.string(from: startDate)

        let response = try await supabase
            .from("daily_commitments")
            .select()
            .eq("athlete_id", value: userId)  // Changed to athlete_id
            .gte("commitment_date", value: startDateString)
            .execute()

        let data = response.data
        let commitments = try JSONDecoder().decode([DailyCommitment].self, from: data)

        let totalCommitments = commitments.count
        let fulfilledCommitments = commitments.filter { $0.isFulfilled }.count
        let fulfillmentRate = totalCommitments > 0 ? Double(fulfilledCommitments) / Double(totalCommitments) : 0.0

        return CommitmentStats(
            totalCommitments: totalCommitments,
            fulfilledCommitments: fulfilledCommitments,
            fulfillmentRate: fulfillmentRate,
            currentStreak: calculateCurrentStreak(commitments: commitments)
        )
    }

    // MARK: - Helper Methods

    private static func calculateCurrentStreak(commitments: [DailyCommitment]) -> Int {
        let sortedCommitments = commitments
            .sorted { $0.commitmentDateAsDate > $1.commitmentDateAsDate }

        var streak = 0
        for commitment in sortedCommitments {
            if commitment.isFulfilled {
                streak += 1
            } else {
                break
            }
        }

        return streak
    }
}

// MARK: - Commitment Stats Model

struct CommitmentStats {
    let totalCommitments: Int
    let fulfilledCommitments: Int
    let fulfillmentRate: Double // 0.0 to 1.0
    let currentStreak: Int

    var fulfillmentPercentage: Double {
        return fulfillmentRate * 100.0
    }
}

// MARK: - Update Models

struct CommitmentFulfillmentUpdate: Codable {
    let isFulfilled: Bool
    let fulfilledAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case isFulfilled = "is_fulfilled"
        case fulfilledAt = "fulfilled_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Custom Errors

enum SupabaseError: Error, LocalizedError {
    case decodingError(String)
    case invalidData(String)

    var errorDescription: String? {
        switch self {
        case .decodingError(let message):
            return "Decoding error: \(message)"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        }
    }
}