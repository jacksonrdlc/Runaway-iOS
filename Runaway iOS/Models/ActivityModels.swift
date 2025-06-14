import Foundation
import SwiftUI

// MARK: - Activity Models
public struct Activity: Identifiable, Codable {
    public let id: Int
    public let name: String?
    public let type: String?
    public let summary_polyline: String?
    public let distance: Double?
    public let start_date: TimeInterval?
    public let elapsed_time: TimeInterval?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case distance
        case start_date
        case elapsed_time
        case summary_polyline
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        distance = try container.decodeIfPresent(Double.self, forKey: .distance)
        elapsed_time = try container.decodeIfPresent(TimeInterval.self, forKey: .elapsed_time)
        summary_polyline = try container.decodeIfPresent(String.self, forKey: .summary_polyline)
        // Custom decoding for start_date
        if let dateString = try container.decodeIfPresent(String.self, forKey: .start_date) {
            let formatter = ISO8601DateFormatter()
            if let date = formatter.date(from: dateString) {
                start_date = date.timeIntervalSince1970
            } else {
                start_date = nil
            }
        } else {
            start_date = try container.decodeIfPresent(TimeInterval.self, forKey: .start_date)
        }
    }
    
    public init(
        id: Int,
        name: String?,
        type: String?,
        summary_polyline: String?,
        distance: Double?,
        start_date: TimeInterval?,
        elapsed_time: TimeInterval?
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.summary_polyline = summary_polyline
        self.distance = distance
        self.start_date = start_date
        self.elapsed_time = elapsed_time
    }
}

public struct LocalActivity: Identifiable {
    public let id: Int
    public let name: String?
    public let type: String?
    public let summary_polyline: String?
    public let distance: Double?
    public let start_date: Date?
    public let elapsed_time: TimeInterval?
    
    public init(
        id: Int,
        name: String?,
        type: String?,
        summary_polyline: String? = nil,
        distance: Double?,
        start_date: Date?,
        elapsed_time: TimeInterval?
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.summary_polyline = summary_polyline
        self.distance = distance
        self.start_date = start_date
        self.elapsed_time = elapsed_time
    }
}

public struct Map: Codable {
    public let id: Int?
    public let map_id: String?
    public let summaryPolyline: String?
    public let polyline: String?

    public init(id: Int?, map_id: String?, summaryPolyline: String?, polyline: String?) {
        self.id = id
        self.map_id = map_id
        self.summaryPolyline = summaryPolyline
        self.polyline = polyline
    }
}

public struct ActivityDay: Identifiable {
    public let id = UUID()
    public var date: Date
    public var minutes: Double
    
    public init(date: Date, minutes: Double) {
        self.date = date
        self.minutes = minutes
    }
}

public struct RAActivity: Codable {
    public var day: String
    public var type: String?
    public var distance: Double
    public var time: Double
    
    public init(day: String, type: String?, distance: Double, time: Double) {
        self.day = day
        self.type = type
        self.distance = distance
        self.time = time
    }
}

