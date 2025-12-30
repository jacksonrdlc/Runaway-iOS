//
//  ReadinessModels.swift
//  Runaway iOS
//
//  Models for daily readiness/recovery scoring based on HealthKit data
//

import Foundation

// MARK: - Readiness Level

/// Visual/textual representation of daily readiness state
/// Named DailyReadinessLevel to avoid conflict with goal DailyReadinessLevel in RunningAnalyzer
enum DailyReadinessLevel: String, CaseIterable, Codable {
    case optimal = "Optimal"       // 85-100
    case good = "Good"             // 70-84
    case moderate = "Moderate"     // 50-69
    case low = "Low"               // 30-49
    case poor = "Poor"             // 0-29

    static func from(score: Int) -> DailyReadinessLevel {
        switch score {
        case 85...100: return .optimal
        case 70...84: return .good
        case 50...69: return .moderate
        case 30...49: return .low
        default: return .poor
        }
    }

    var color: String {
        switch self {
        case .optimal: return "#22C55E"  // Green
        case .good: return "#84CC16"     // Lime
        case .moderate: return "#EAB308" // Yellow
        case .low: return "#F97316"      // Orange
        case .poor: return "#EF4444"     // Red
        }
    }

    var systemImageName: String {
        switch self {
        case .optimal: return "bolt.fill"
        case .good: return "checkmark.circle.fill"
        case .moderate: return "minus.circle.fill"
        case .low: return "exclamationmark.triangle.fill"
        case .poor: return "xmark.circle.fill"
        }
    }

    var recommendation: String {
        switch self {
        case .optimal:
            return "You're fully recovered. Great day for a hard workout or race."
        case .good:
            return "Good recovery. Proceed with planned training."
        case .moderate:
            return "Moderate recovery. Consider reducing intensity today."
        case .low:
            return "Lower recovery. Consider an easy day or active recovery."
        case .poor:
            return "Poor recovery. Rest or very light activity recommended."
        }
    }
}

// MARK: - Readiness Factor

/// Individual factor contributing to overall readiness score
struct ReadinessFactor: Identifiable, Codable {
    let id: String
    let name: String
    let score: Int          // 0-100
    let weight: Double      // 0-1 (contribution to total)
    let value: String       // Display value (e.g., "7h 32m", "45ms")
    let change: String?     // Change from baseline (e.g., "+5%", "-3 bpm")
    let trend: FactorTrend  // Improving, stable, declining

    enum FactorTrend: String, Codable {
        case improving = "improving"
        case stable = "stable"
        case declining = "declining"

        var systemImageName: String {
            switch self {
            case .improving: return "arrow.up.right"
            case .stable: return "arrow.right"
            case .declining: return "arrow.down.right"
            }
        }

        var color: String {
            switch self {
            case .improving: return "#22C55E"
            case .stable: return "#6B7280"
            case .declining: return "#EF4444"
            }
        }
    }
}

// MARK: - Daily Readiness

/// Complete daily readiness assessment
struct DailyReadiness: Identifiable, Codable {
    let id: UUID
    let athleteId: Int
    let date: Date
    let score: Int          // 0-100 overall score
    let level: DailyReadinessLevel
    let factors: [ReadinessFactor]
    let recommendation: String
    let calculatedAt: Date

    init(
        id: UUID = UUID(),
        athleteId: Int,
        date: Date,
        score: Int,
        factors: [ReadinessFactor],
        recommendation: String? = nil,
        calculatedAt: Date = Date()
    ) {
        self.id = id
        self.athleteId = athleteId
        self.date = date
        self.score = max(0, min(100, score)) // Clamp to 0-100
        self.level = DailyReadinessLevel.from(score: score)
        self.factors = factors
        self.recommendation = recommendation ?? self.level.recommendation
        self.calculatedAt = calculatedAt
    }

    /// Check if this readiness is for today
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    /// Get a specific factor by ID
    func factor(id: String) -> ReadinessFactor? {
        factors.first { $0.id == id }
    }
}

// MARK: - Readiness History

/// Historical readiness data for trends
struct ReadinessHistory: Codable {
    let athleteId: Int
    let entries: [DailyReadiness]
    let averageScore: Double
    let trend: ReadinessFactor.FactorTrend

    init(athleteId: Int, entries: [DailyReadiness]) {
        self.athleteId = athleteId
        self.entries = entries.sorted { $0.date > $1.date }

        // Calculate average
        if entries.isEmpty {
            self.averageScore = 0
            self.trend = .stable
        } else {
            self.averageScore = Double(entries.map { $0.score }.reduce(0, +)) / Double(entries.count)

            // Calculate trend based on recent vs older entries
            let recent = entries.prefix(3).map { $0.score }
            let older = entries.dropFirst(3).prefix(3).map { $0.score }

            if recent.isEmpty || older.isEmpty {
                self.trend = .stable
            } else {
                let recentAvg = Double(recent.reduce(0, +)) / Double(recent.count)
                let olderAvg = Double(older.reduce(0, +)) / Double(older.count)
                let diff = recentAvg - olderAvg

                if diff > 5 {
                    self.trend = .improving
                } else if diff < -5 {
                    self.trend = .declining
                } else {
                    self.trend = .stable
                }
            }
        }
    }
}

// MARK: - Factor IDs

/// Standard factor identifiers
extension ReadinessFactor {
    static let sleepId = "sleep"
    static let hrvId = "hrv"
    static let restingHRId = "resting_hr"
    static let trainingLoadId = "training_load"
}

// MARK: - Database Response

/// Response structure from Supabase daily_readiness table
struct DailyReadinessResponse: Codable {
    let id: String
    let athlete_id: Int
    let date: String
    let score: Int
    let sleep_score: Int?
    let hrv_score: Int?
    let resting_hr_score: Int?
    let training_load_score: Int?
    let recommendation: String?
    let factors: [String: AnyCodable]?
    let created_at: String

    /// Convert to DailyReadiness model
    func toDailyReadiness() -> DailyReadiness? {
        guard let uuid = UUID(uuidString: id),
              let dateValue = ISO8601DateFormatter().date(from: date + "T00:00:00Z") else {
            return nil
        }

        var factorsArray: [ReadinessFactor] = []

        if let sleepScore = sleep_score {
            factorsArray.append(ReadinessFactor(
                id: ReadinessFactor.sleepId,
                name: "Sleep",
                score: sleepScore,
                weight: 0.30,
                value: "",
                change: nil,
                trend: .stable
            ))
        }

        if let hrvScore = hrv_score {
            factorsArray.append(ReadinessFactor(
                id: ReadinessFactor.hrvId,
                name: "HRV",
                score: hrvScore,
                weight: 0.25,
                value: "",
                change: nil,
                trend: .stable
            ))
        }

        if let restingHRScore = resting_hr_score {
            factorsArray.append(ReadinessFactor(
                id: ReadinessFactor.restingHRId,
                name: "Resting HR",
                score: restingHRScore,
                weight: 0.20,
                value: "",
                change: nil,
                trend: .stable
            ))
        }

        if let trainingLoadScore = training_load_score {
            factorsArray.append(ReadinessFactor(
                id: ReadinessFactor.trainingLoadId,
                name: "Training Load",
                score: trainingLoadScore,
                weight: 0.25,
                value: "",
                change: nil,
                trend: .stable
            ))
        }

        return DailyReadiness(
            id: uuid,
            athleteId: athlete_id,
            date: dateValue,
            score: score,
            factors: factorsArray,
            recommendation: recommendation,
            calculatedAt: ISO8601DateFormatter().date(from: created_at) ?? Date()
        )
    }
}

// MARK: - Readiness Summary for Widget

/// Lightweight readiness data for widget display
struct ReadinessWidgetData: Codable {
    let score: Int
    let level: DailyReadinessLevel
    let recommendation: String
    let updatedAt: Date

    init(from readiness: DailyReadiness) {
        self.score = readiness.score
        self.level = readiness.level
        self.recommendation = readiness.recommendation
        self.updatedAt = readiness.calculatedAt
    }
}
