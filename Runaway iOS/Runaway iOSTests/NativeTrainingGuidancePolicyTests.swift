import Foundation
import Testing
@testable import Runaway_iOS

struct NativeTrainingGuidancePolicyTests {
    @Test func easyAndLongRunsTargetConversationalZone() throws {
        let easy = try #require(NativeTrainingGuidancePolicy.zoneTarget(for: .easyRun))
        let long = try #require(NativeTrainingGuidancePolicy.zoneTarget(for: .longRun))

        #expect(easy.lowerZone == 2)
        #expect(easy.upperZone == 2)
        #expect(long == easy)
    }

    @Test func qualitySessionsUseHigherZonesWithoutPrescribingAllOutEffort() throws {
        let tempo = try #require(NativeTrainingGuidancePolicy.zoneTarget(for: .tempoRun))
        let intervals = try #require(NativeTrainingGuidancePolicy.zoneTarget(for: .intervalRun))

        #expect(tempo.lowerZone == 3)
        #expect(tempo.upperZone == 4)
        #expect(intervals.lowerZone == 4)
        #expect(intervals.upperZone == 5)
    }

    @Test func hotHumidWeatherProducesHighEnvironmentalLoad() {
        let weather = TrainingWeatherSnapshot(
            symbolName: "sun.max.fill",
            feelsLikeCelsius: 31,
            humidity: 0.78,
            windMetersPerSecond: 3,
            precipitationChance: 0,
            uvIndex: 8
        )

        let guidance = NativeTrainingGuidancePolicy.weatherGuidance(for: weather, workoutType: .tempoRun)

        #expect(guidance.level == .high)
        #expect(guidance.intensityReduction == 0.20)
        #expect(guidance.detail.contains("easy effort"))
    }

    @Test func strongWindProducesCautionWithoutChangingBiologicalReadiness() {
        let weather = TrainingWeatherSnapshot(
            symbolName: "wind",
            feelsLikeCelsius: 18,
            humidity: 0.45,
            windMetersPerSecond: 12,
            precipitationChance: 0.1,
            uvIndex: 3
        )

        let guidance = NativeTrainingGuidancePolicy.weatherGuidance(for: weather, workoutType: .easyRun)

        #expect(guidance.level == .caution)
        #expect(guidance.intensityReduction == 0.10)
        #expect(guidance.affectsReadinessScore == false)
    }

    @Test func normalConditionsDoNotInventAnAdjustment() {
        let weather = TrainingWeatherSnapshot(
            symbolName: "cloud.sun.fill",
            feelsLikeCelsius: 17,
            humidity: 0.50,
            windMetersPerSecond: 2,
            precipitationChance: 0.1,
            uvIndex: 2
        )

        let guidance = NativeTrainingGuidancePolicy.weatherGuidance(for: weather, workoutType: .longRun)

        #expect(guidance.level == .favorable)
        #expect(guidance.intensityReduction == 0)
    }

    @Test func calibrationConfidenceRequiresSignalCoverageAndPersonalZones() {
        #expect(ReadinessCalibrationPolicy.assessment(availableWeight: 0.95, hasPersonalZones: true).level == .high)
        #expect(ReadinessCalibrationPolicy.assessment(availableWeight: 0.70, hasPersonalZones: false).level == .moderate)
        #expect(ReadinessCalibrationPolicy.assessment(availableWeight: 0.40, hasPersonalZones: true).level == .limited)
    }
}
