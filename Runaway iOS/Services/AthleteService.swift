import Foundation
import Supabase

class AthleteService {
    // Function to get athlete by athlete ID
    static func getAthleteByUserId(userId: Int) async throws -> Athlete {
        return try await supabase
            .from("athletes")
            .select(
                """
                id,
                auth_user_id,
                email,
                first_name,
                last_name,
                sex,
                description,
                weight,
                city,
                state,
                country,
                created_at
                """
            )
            .eq("id", value: userId)
            .single()
            .execute()
            .value
    }

    // Function to get athlete stats by athlete ID
    static func getAthleteStats(userId: Int) async throws -> AthleteStats? {
        do {
            return try await supabase
                .from("athlete_stats")
                .select()
                .eq("athlete_id", value: userId)
                .single()
                .execute()
                .value
        } catch {
            // If no stats found, return nil (this is normal for new athletes)
            print("⚠️ AthleteService: No stats found for athlete \(userId), this is normal for new athletes")
            return nil
        }
    }
} 
