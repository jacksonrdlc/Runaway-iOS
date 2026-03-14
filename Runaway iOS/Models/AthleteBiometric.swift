import Foundation

struct AthleteBiometric: Codable, Identifiable {
    let id: UUID?
    let athleteId: Int
    let entryDate: String // YYYY-MM-DD
    let hrvMs: Double?
    let rhrBpm: Int?
    let sleepScore: Int?
    let readinessScore: Int?
    let recoveryPhase: String?
    let stressLevel: Double?
    let rawSource: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case athleteId = "athlete_id"
        case entryDate = "entry_date"
        case hrvMs = "hrv_ms"
        case rhrBpm = "rhr_bpm"
        case sleepScore = "sleep_score"
        case readinessScore = "readiness_score"
        case recoveryPhase = "recovery_phase"
        case stressLevel = "stress_level"
        case rawSource = "raw_source"
    }
}
