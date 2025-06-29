//
//  GoalModels.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 6/28/25.
//

import Foundation

// MARK: - Goal Types
enum GoalType: String, CaseIterable, Codable {
    case distance = "distance"
    case time = "time"
    case pace = "pace"
    
    var displayName: String {
        switch self {
        case .distance: return "Distance Goal"
        case .time: return "Time Goal"
        case .pace: return "Pace Goal"
        }
    }
    
    func unit(isMetric: Bool = false) -> String {
        switch self {
        case .distance: return isMetric ? "km" : "miles"
        case .time: return "minutes"
        case .pace: return isMetric ? "min/km" : "min/mile"
        }
    }
}

// MARK: - Running Goal
struct RunningGoal: Codable, Identifiable {
    let id: Int?
    let userId: Int?
    let type: GoalType
    let targetValue: Double
    let deadline: Date
    let createdDate: Date
    let updatedDate: Date?
    let title: String
    let isActive: Bool
    let isCompleted: Bool
    let currentProgress: Double
    let completedDate: Date?
    
    // Client-side init for new goals
    init(type: GoalType, targetValue: Double, deadline: Date, title: String) {
        self.id = nil
        self.userId = nil
        self.type = type
        self.targetValue = targetValue
        self.deadline = deadline
        self.createdDate = Date()
        self.updatedDate = nil
        self.title = title
        self.isActive = true
        self.isCompleted = false
        self.currentProgress = 0.0
        self.completedDate = nil
    }
    
    // Database init for existing goals
    init(id: Int?, userId: Int?, type: GoalType, targetValue: Double, deadline: Date, 
         createdDate: Date, updatedDate: Date?, title: String, isActive: Bool, 
         isCompleted: Bool, currentProgress: Double, completedDate: Date?) {
        self.id = id
        self.userId = userId
        self.type = type
        self.targetValue = targetValue
        self.deadline = deadline
        self.createdDate = createdDate
        self.updatedDate = updatedDate
        self.title = title
        self.isActive = isActive
        self.isCompleted = isCompleted
        self.currentProgress = currentProgress
        self.completedDate = completedDate
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case type = "goal_type"
        case targetValue = "target_value"
        case deadline
        case createdDate = "created_at"
        case updatedDate = "updated_at"
        case title
        case isActive = "is_active"
        case isCompleted = "is_completed"
        case currentProgress = "current_progress"
        case completedDate = "completed_at"
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(userId, forKey: .userId)
        try container.encode(type.rawValue, forKey: .type)
        try container.encode(targetValue, forKey: .targetValue)
        try container.encode(deadline, forKey: .deadline)
        try container.encode(createdDate, forKey: .createdDate)
        try container.encodeIfPresent(updatedDate, forKey: .updatedDate)
        try container.encode(title, forKey: .title)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encode(currentProgress, forKey: .currentProgress)
        try container.encodeIfPresent(completedDate, forKey: .completedDate)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id)
        userId = try container.decodeIfPresent(Int.self, forKey: .userId)
        
        // Decode goal type
        let typeString = try container.decode(String.self, forKey: .type)
        guard let goalType = GoalType(rawValue: typeString) else {
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Invalid goal type: \(typeString)")
        }
        type = goalType
        
        targetValue = try container.decode(Double.self, forKey: .targetValue)
        deadline = try container.decode(Date.self, forKey: .deadline)
        createdDate = try container.decode(Date.self, forKey: .createdDate)
        updatedDate = try container.decodeIfPresent(Date.self, forKey: .updatedDate)
        title = try container.decode(String.self, forKey: .title)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        currentProgress = try container.decode(Double.self, forKey: .currentProgress)
        completedDate = try container.decodeIfPresent(Date.self, forKey: .completedDate)
    }
    
    func formattedTarget(isMetric: Bool = false) -> String {
        switch type {
        case .distance:
            if isMetric {
                let kmValue = targetValue * 1.60934 // Convert miles to km
                return String(format: "%.1f km", kmValue)
            } else {
                return String(format: "%.1f miles", targetValue)
            }
        case .time:
            let hours = Int(targetValue / 60)
            let minutes = Int(targetValue.truncatingRemainder(dividingBy: 60))
            return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
        case .pace:
            let minutes = Int(targetValue)
            let seconds = Int((targetValue - Double(minutes)) * 60)
            let unit = isMetric ? "km" : "mile"
            return String(format: "%d:%02d/%@", minutes, seconds, unit)
        }
    }
    
    var daysRemaining: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: deadline).day ?? 0
    }
    
    var weeksRemaining: Double {
        Double(daysRemaining) / 7.0
    }
}

// MARK: - Training Recommendations
struct TrainingRecommendation: Codable, Identifiable {
    let id: UUID
    let runNumber: Int
    let distance: Double
    let targetPace: Double
    let description: String
    let reasoning: String
    let scheduledDate: Date?
    
    init(runNumber: Int, distance: Double, targetPace: Double, description: String, reasoning: String, scheduledDate: Date? = nil) {
        self.id = UUID()
        self.runNumber = runNumber
        self.distance = distance
        self.targetPace = targetPace
        self.description = description
        self.reasoning = reasoning
        self.scheduledDate = scheduledDate
    }
    
    var formattedDistance: String {
        return String(format: "%.1f miles", distance)
    }
    
    var formattedPace: String {
        let minutes = Int(targetPace)
        let seconds = Int((targetPace - Double(minutes)) * 60)
        return String(format: "%d:%02d/mile", minutes, seconds)
    }
}

// MARK: - Goal Progress Data
struct GoalProgressPoint: Codable, Identifiable {
    let id: UUID
    let date: Date
    let actualProgress: Double
    let targetProgress: Double
    let weekNumber: Int
    
    init(date: Date, actualProgress: Double, targetProgress: Double, weekNumber: Int) {
        self.id = UUID()
        self.date = date
        self.actualProgress = actualProgress
        self.targetProgress = targetProgress
        self.weekNumber = weekNumber
    }
}

// MARK: - Goal Analysis Result
struct GoalAnalysis {
    let goal: RunningGoal
    let currentProgress: Double
    let projectedCompletion: Double
    let isOnTrack: Bool
    let recommendations: [TrainingRecommendation]
    let progressPoints: [GoalProgressPoint]
    
    var progressPercentage: Double {
        return min(currentProgress * 100, 100.0)
    }
    
    var trackingStatus: TrackingStatus {
        if projectedCompletion >= 100.0 {
            return .onTrack
        } else if projectedCompletion >= 80.0 {
            return .slightlyBehind
        } else {
            return .significantlyBehind
        }
    }
}

enum TrackingStatus {
    case onTrack
    case slightlyBehind
    case significantlyBehind
    
    var color: String {
        switch self {
        case .onTrack: return "green"
        case .slightlyBehind: return "orange" 
        case .significantlyBehind: return "red"
        }
    }
    
    var description: String {
        switch self {
        case .onTrack: return "On Track"
        case .slightlyBehind: return "Slightly Behind"
        case .significantlyBehind: return "Behind Schedule"
        }
    }
}