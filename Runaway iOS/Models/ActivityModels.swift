import Foundation
import SwiftUI

// MARK: - Activity Models
public struct Activity: Identifiable, Codable {
    public let id: Int
    public let name: String?
    public let type: String?
    public let distance: Double?
    public let start_date: TimeInterval?
    public let elapsed_time: TimeInterval?
    
    public init(
        id: Int,
        name: String?,
        type: String?,
        distance: Double?,
        start_date: TimeInterval?,
        elapsed_time: TimeInterval?
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.distance = distance
        self.start_date = start_date
        self.elapsed_time = elapsed_time
    }
}

public struct LocalActivity: Identifiable {
    public let id: Int
    public let name: String?
    public let type: String?
    public let distance: Double?
    public let start_date: Int?
    public let elapsed_time: TimeInterval?
    
    public init(
        id: Int,
        name: String?,
        type: String?,
        distance: Double?,
        start_date: Int?,
        elapsed_time: TimeInterval?
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.distance = distance
        self.start_date = start_date
        self.elapsed_time = elapsed_time
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

