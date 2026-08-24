import Foundation
import Supabase

class AthleteService {
    static let shared = AthleteService()
    private init() {}

    private static let decoder = SupabaseDecoder.shared

    // Function to get athlete by athlete ID
    static func getAthleteByUserId(userId: Int) async throws -> Athlete {
        #if DEBUG
        print("🔍 AthleteService: Looking up athlete with id = \(userId)")
        #endif

        let response = try await supabase
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
            .execute()

        let data = response.data
        let athletes = try Self.decoder.decode([Athlete].self, from: data)

        if let athlete = athletes.first {
            #if DEBUG
            print("✅ AthleteService: Found athlete: \(athlete.firstname ?? "Unknown")")
            #endif
            return athlete
        }

        #if DEBUG
        print("❌ AthleteService: No athlete found for id \(userId)")
        #endif
        throw AthleteServiceError.athleteNotFound
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
            #if DEBUG
            print("⚠️ AthleteService: No stats found for athlete \(userId), this is normal for new athletes")
            #endif
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

    // MARK: - Athlete Creation

    /// Get athlete by auth user ID (Supabase auth UUID)
    static func getAthleteByAuthId(authId: UUID) async throws -> Athlete? {
        let uuidUppercase = authId.uuidString
        let uuidLowercase = authId.uuidString.lowercased()

        #if DEBUG
        print("🔍 AthleteService: Looking up athlete by auth_user_id = \(uuidUppercase)")
        #endif

        // Try uppercase first
        let response = try await supabase
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
            .eq("auth_user_id", value: uuidUppercase)
            .execute()

        let athletes = try Self.decoder.decode([Athlete].self, from: response.data)
        if let athlete = athletes.first {
            #if DEBUG
            print("✅ AthleteService: Found athlete \(athlete.id ?? 0) (uppercase)")
            #endif
            return athlete
        }

        // Try lowercase
        #if DEBUG
        print("🔄 AthleteService: Trying lowercase format...")
        #endif
        let response2 = try await supabase
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
            .eq("auth_user_id", value: uuidLowercase)
            .execute()

        let athletes2 = try Self.decoder.decode([Athlete].self, from: response2.data)
        if let athlete = athletes2.first {
            #if DEBUG
            print("✅ AthleteService: Found athlete \(athlete.id ?? 0) (lowercase)")
            #endif
            return athlete
        }

        // No athlete found - this is expected for new users
        #if DEBUG
        print("⚠️ AthleteService: No athlete found for auth user \(authId)")
        #endif
        return nil
    }

    /// Ensures an athlete record exists for the given auth user.
    /// Creates one if it doesn't exist (fallback for when DB trigger doesn't fire).
    /// Returns the athlete ID.
    static func ensureAthleteExists(authId: UUID, email: String?) async throws -> Int {
        // First check if athlete already exists
        if let existingAthlete = try await getAthleteByAuthId(authId: authId),
           let athleteId = existingAthlete.id {
            #if DEBUG
            print("✅ AthleteService: Athlete already exists with ID \(athleteId)")
            #endif
            return athleteId
        }

        // Call the database function to create athlete
        #if DEBUG
        print("🔄 AthleteService: Creating new athlete for auth user \(authId)")
        #endif

        struct EnsureAthleteParams: Encodable {
            let p_auth_user_id: String
            let p_email: String?
        }

        let params = EnsureAthleteParams(
            p_auth_user_id: authId.uuidString,
            p_email: email
        )

        let response = try await supabase
            .rpc("ensure_athlete_exists", params: params)
            .execute()
        let athleteId = try decodeEnsureAthleteId(from: response.data)

        #if DEBUG
        print("✅ AthleteService: Created athlete with ID \(athleteId)")
        #endif
        return athleteId
    }

    static func decodeEnsureAthleteId(from data: Data) throws -> Int {
        try JSONDecoder().decode(Int.self, from: data)
    }
}

enum AthleteServiceError: Error, LocalizedError {
    case athleteNotFound

    var errorDescription: String? {
        switch self {
        case .athleteNotFound:
            return "No athlete record found"
        }
    }
}
