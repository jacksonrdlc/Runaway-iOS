import Foundation

struct PersonalBest: Identifiable, Codable {
    let id: Int
    let athleteId: Int
    let distanceLabel: String
    let distanceMeters: Double
    let timeSeconds: Int
    let activityId: Int?
    let achievedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case athleteId    = "athlete_id"
        case distanceLabel  = "distance_label"
        case distanceMeters = "distance_meters"
        case timeSeconds    = "time_seconds"
        case activityId   = "activity_id"
        case achievedAt   = "achieved_at"
    }

    var formattedTime: String {
        let h = timeSeconds / 3600
        let m = (timeSeconds % 3600) / 60
        let s = timeSeconds % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }
}

// Standard distance brackets used for PR detection
enum PRDistance: CaseIterable {
    case mile, fiveK, tenK, halfMarathon, marathon

    var label: String {
        switch self {
        case .mile:         return "mile"
        case .fiveK:        return "5k"
        case .tenK:         return "10k"
        case .halfMarathon: return "half_marathon"
        case .marathon:     return "marathon"
        }
    }

    var displayName: String {
        switch self {
        case .mile:         return "Mile"
        case .fiveK:        return "5K"
        case .tenK:         return "10K"
        case .halfMarathon: return "Half Marathon"
        case .marathon:     return "Marathon"
        }
    }

    // Inclusive meter range that qualifies as this distance
    var metersRange: ClosedRange<Double> {
        switch self {
        case .mile:         return 1500...1800
        case .fiveK:        return 4700...5300
        case .tenK:         return 9400...10600
        case .halfMarathon: return 19500...22000
        case .marathon:     return 40000...44500
        }
    }

    var nominalMeters: Double {
        switch self {
        case .mile:         return 1609.34
        case .fiveK:        return 5000
        case .tenK:         return 10000
        case .halfMarathon: return 21097.5
        case .marathon:     return 42195
        }
    }

    // Number of consecutive 1km splits that cover this distance (nil = no clean mapping)
    var splitWindowSize: Int? {
        switch self {
        case .mile:         return nil  // 1.6km doesn't map to whole 1km splits
        case .fiveK:        return 5
        case .tenK:         return 10
        case .halfMarathon: return 21
        case .marathon:     return 42
        }
    }
}
