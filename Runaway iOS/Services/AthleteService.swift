import Foundation
import Supabase

class AthleteService {
    // Function to get athlete by user ID
    static func getAthleteByUserId(userId: Int) async throws -> Athlete {
        return try await supabase
            .from("athletes")
            .select()
            .eq("user_id", value: userId)
            .single()
            .execute()
            .value
    }
    
    // Function to get athlete stats by athlete ID
    static func getAthleteStats() async throws -> AthleteStats {
        return try await supabase
            .from("athlete_stats")
            .select()
            .single()
            .execute()
            .value
    }
} 
