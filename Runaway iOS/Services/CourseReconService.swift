//
//  CourseReconService.swift
//  Runaway iOS
//

import Foundation
import Supabase

struct RaceCourse: Codable, Identifiable {
    let id: UUID
    let runsignupRaceId: Int
    let eventId: Int
    let polyline: String?
    let elevationData: [CourseElevationPoint]?
    let tacticalInsights: [TacticalInsight]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case runsignupRaceId = "runsignup_race_id"
        case eventId = "event_id"
        case polyline
        case elevationData = "elevation_data"
        case tacticalInsights = "tactical_insights"
    }
}

struct CourseElevationPoint: Codable {
    let distance: Double // meters from start
    let elevation: Double // meters
    let grade: Double // percentage
}

struct TacticalInsight: Codable, Identifiable {
    var id: String { "\(mile)-\(type)" }
    let mile: Double
    let type: String // "climb", "descent", "turn", "fuel"
    let description: String
}

class CourseReconService {
    static let shared = CourseReconService()
    
    func fetchCourse(raceId: Int, eventId: Int) async throws -> RaceCourse? {
        let queryItems = [
            URLQueryItem(name: "race_id", value: "\(raceId)"),
            URLQueryItem(name: "event_id", value: "\(eventId)")
        ]
        
        let response: [String: RaceCourse?] = try await supabase.functions
            .invoke("get-race-course", 
                    options: .init(query: queryItems))
        
        return response["course"] ?? nil
    }
    
    /// Placeholder for AI analysis of course crux
    func generateTacticalInsights(course: RaceCourse) async throws -> [TacticalInsight] {
        return [
            TacticalInsight(mile: 21.2, type: "climb", description: "Final steep grade (4%) - preserve glycogen in the miles leading up to this."),
            TacticalInsight(mile: 13.5, type: "fuel", description: "Halfway point. High probability of mental fatigue—hit your caffeine gel here.")
        ]
    }
}
