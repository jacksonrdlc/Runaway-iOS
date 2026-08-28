import Foundation

struct TrainingZoneTarget: Equatable, Sendable {
    let lowerZone: Int
    let upperZone: Int
    let name: String
    let detail: String

    var label: String {
        lowerZone == upperZone ? "Zone \(lowerZone)" : "Zones \(lowerZone)-\(upperZone)"
    }
}

enum AppleTrainingZoneSource: String, Equatable, Sendable {
    case system = "Apple personalized"
    case user = "Custom in Health"
    case app = "Runaway"
}

struct AppleHeartRateZone: Equatable, Sendable, Identifiable {
    let index: Int
    let minimumBPM: Int?
    let maximumBPM: Int?

    var id: Int { index }
}

struct AppleHeartRateZoneSnapshot: Equatable, Sendable {
    let source: AppleTrainingZoneSource
    let zones: [AppleHeartRateZone]

    func bpmRange(for target: TrainingZoneTarget) -> String? {
        let selected = zones.filter { target.lowerZone...target.upperZone ~= $0.index }
        guard !selected.isEmpty else { return nil }
        let minimum = selected.compactMap(\.minimumBPM).min()
        let maximum = selected.compactMap(\.maximumBPM).max()
        switch (minimum, maximum) {
        case let (.some(low), .some(high)): return "\(low)-\(high) bpm"
        case let (.some(low), .none): return "\(low)+ bpm"
        case let (.none, .some(high)): return "Up to \(high) bpm"
        default: return nil
        }
    }
}

struct TrainingWeatherSnapshot: Equatable, Sendable {
    let symbolName: String
    let feelsLikeCelsius: Double
    let humidity: Double
    let windMetersPerSecond: Double
    let precipitationChance: Double
    let uvIndex: Int
}

enum EnvironmentalLoadLevel: Equatable, Sendable {
    case favorable
    case caution
    case high
}

struct WeatherTrainingGuidance: Equatable, Sendable {
    let level: EnvironmentalLoadLevel
    let title: String
    let detail: String
    let intensityReduction: Double
    let affectsReadinessScore: Bool
}

enum CalibrationConfidenceLevel: String, Equatable, Sendable {
    case high = "High"
    case moderate = "Moderate"
    case limited = "Limited"
}

struct ReadinessCalibrationAssessment: Equatable, Sendable {
    let level: CalibrationConfidenceLevel
    let detail: String
}

enum NativeTrainingGuidancePolicy {
    static func zoneTarget(for workoutType: WorkoutType) -> TrainingZoneTarget? {
        switch workoutType {
        case .recoveryRun:
            return TrainingZoneTarget(lowerZone: 1, upperZone: 2, name: "Recovery", detail: "Keep this genuinely light.")
        case .easyRun, .longRun:
            return TrainingZoneTarget(lowerZone: 2, upperZone: 2, name: "Conversational", detail: "Aerobic effort you can sustain comfortably.")
        case .tempoRun:
            return TrainingZoneTarget(lowerZone: 3, upperZone: 4, name: "Controlled quality", detail: "Build steadily without turning the workout into a race.")
        case .intervalRun, .hillRun:
            return TrainingZoneTarget(lowerZone: 4, upperZone: 5, name: "Hard repetitions", detail: "Use the high zones only during prescribed work intervals.")
        default:
            return nil
        }
    }

    static func weatherGuidance(
        for weather: TrainingWeatherSnapshot,
        workoutType: WorkoutType
    ) -> WeatherTrainingGuidance {
        guard workoutType.isRunning else {
            return WeatherTrainingGuidance(
                level: .favorable,
                title: "Indoor plan unaffected",
                detail: "Weather is advisory only for this session.",
                intensityReduction: 0,
                affectsReadinessScore: false
            )
        }

        let humidHeat = weather.feelsLikeCelsius >= 30 && weather.humidity >= 0.65
        let extremeHeat = weather.feelsLikeCelsius >= 35
        if humidHeat || extremeHeat {
            return WeatherTrainingGuidance(
                level: .high,
                title: "High environmental load",
                detail: "Shift to an easy effort, hydrate early, or move the session to a cooler time.",
                intensityReduction: 0.20,
                affectsReadinessScore: false
            )
        }

        let strongWind = weather.windMetersPerSecond >= 10
        let likelyPrecipitation = weather.precipitationChance >= 0.55
        let cold = weather.feelsLikeCelsius <= -5
        let highUV = weather.uvIndex >= 7
        if strongWind || likelyPrecipitation || cold || highUV {
            let reason: String
            if strongWind { reason = "Strong wind will raise effort; run by feel instead of pace." }
            else if likelyPrecipitation { reason = "Wet conditions may affect footing and pace." }
            else if cold { reason = "Allow extra warm-up time before increasing effort." }
            else { reason = "High UV favors shade, protection, or a different start time." }
            return WeatherTrainingGuidance(
                level: .caution,
                title: "Conditions need an adjustment",
                detail: reason,
                intensityReduction: 0.10,
                affectsReadinessScore: false
            )
        }

        return WeatherTrainingGuidance(
            level: .favorable,
            title: "Conditions support the plan",
            detail: "No weather adjustment is recommended.",
            intensityReduction: 0,
            affectsReadinessScore: false
        )
    }
}

enum ReadinessCalibrationPolicy {
    static func assessment(
        availableWeight: Double,
        hasPersonalZones: Bool
    ) -> ReadinessCalibrationAssessment {
        if availableWeight >= 0.85 && hasPersonalZones {
            return ReadinessCalibrationAssessment(
                level: .high,
                detail: "Strong Health signal coverage with personalized Apple zones."
            )
        }
        if availableWeight >= 0.60 {
            return ReadinessCalibrationAssessment(
                level: .moderate,
                detail: hasPersonalZones
                    ? "Useful signal coverage with personalized effort zones."
                    : "Useful signal coverage; Apple zones will improve effort calibration."
            )
        }
        return ReadinessCalibrationAssessment(
            level: .limited,
            detail: "The score is an estimate until more Health signals are available."
        )
    }
}
