import Foundation
import Supabase

struct TwinInsight: Codable {
    let acwr: Double
    let hrvTrend: Double
    let readiness: Int
    let twinStatus: String
    let insight: InsightDetail
    
    struct InsightDetail: Codable {
        let message: String
        let action: String
    }
    
    enum CodingKeys: String, CodingKey {
        case acwr
        case hrvTrend = "hrv_trend"
        case readiness
        case twinStatus = "twin_status"
        case insight
    }
}

class TwinEngineService {
    static let shared = TwinEngineService()
    
    struct TwinEngineBody: Encodable {
        let athlete_id: Int
    }
    
    func fetchTwinInsights() async throws -> TwinInsight {
        guard let athleteId = await UserSession.shared.userId else {
            throw NSError(domain: "TwinEngine", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }
        
        let response: TwinInsight = try await supabase.functions
            .invoke("twin-engine", options: .init(
                body: TwinEngineBody(athlete_id: athleteId)
            ))
            
        return response
    }
}
