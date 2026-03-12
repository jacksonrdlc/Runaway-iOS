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
        let response: [String: RaceCourse?] = try await supabase.functions
            .invoke("get-race-course",
                    options: .init(query: [
                        URLQueryItem(name: "race_id", value: "\(raceId)"),
                        URLQueryItem(name: "event_id", value: "\(eventId)")
                    ]))

        return response["course"] ?? nil
    }

    func uploadCourse(raceId: Int, eventId: Int, polyline: String, elevationData: [CourseElevationPoint]) async throws -> RaceCourse {
        struct UploadBody: Encodable {
            let runsignup_race_id: Int
            let event_id: Int
            let polyline: String
            let elevation_data: [CourseElevationPoint]
        }

        let response: [String: RaceCourse] = try await supabase.functions
            .invoke("upload-race-course",
                    options: .init(
                        method: .post,
                        body: UploadBody(
                            runsignup_race_id: raceId,
                            event_id: eventId,
                            polyline: polyline,
                            elevation_data: elevationData
                        )
                    ))

        guard let course = response["course"] else {
            throw NSError(domain: "CourseRecon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response"])
        }

        return course
    }
}
