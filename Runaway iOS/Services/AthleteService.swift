import Foundation
import Supabase

class AthleteService {
    static let shared = AthleteService()
    private init() {}

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
                created_at,
                strava_connected,
                strava_connected_at,
                strava_disconnected_at,
                profile,
                profile_medium
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

    // Function to update athlete profile information
    func updateAthlete(
        athleteId: Int,
        firstname: String?,
        lastname: String?,
        profileURL: URL?
    ) async throws {
        struct AthleteUpdate: Encodable {
            let first_name: String?
            let last_name: String?
            let profile: String?
            let profile_medium: String?
        }

        let updates = AthleteUpdate(
            first_name: firstname,
            last_name: lastname,
            profile: profileURL?.absoluteString,
            profile_medium: profileURL?.absoluteString
        )

        try await supabase
            .from("athletes")
            .update(updates)
            .eq("id", value: athleteId)
            .execute()
    }
} 
