import Foundation
import Testing
@testable import Runaway_iOS

struct WorkoutDebriefPolicyTests {
    @Test
    func painOverridesPerformanceEncouragement() throws {
        let result = WorkoutDebriefPolicy.debrief(
            for: try makeReflection(effort: 9, bodyState: .pain, mood: .lower),
            activity: runSummary
        )

        #expect(result.localizedCaseInsensitiveContains("stop"))
        #expect(result.localizedCaseInsensitiveContains("pain"))
        #expect(!result.localizedCaseInsensitiveContains("push"))
    }

    @Test
    func highEffortAcknowledgesRecovery() throws {
        let result = WorkoutDebriefPolicy.debrief(
            for: try makeReflection(effort: 9, bodyState: .good, mood: .same),
            activity: runSummary
        )

        #expect(result.localizedCaseInsensitiveContains("recovery"))
    }

    @Test
    func reportedConditionsAreNotInvented() throws {
        let result = WorkoutDebriefPolicy.debrief(
            for: try makeReflection(
                effort: 6,
                bodyState: .good,
                mood: .better,
                conditions: [.heat]
            ),
            activity: runSummary
        )

        #expect(result.localizedCaseInsensitiveContains("heat"))
        #expect(!result.localizedCaseInsensitiveContains("wind"))
    }

    @Test
    func sorenessAfterHardEffortPrioritizesMonitoring() throws {
        let result = WorkoutDebriefPolicy.debrief(
            for: try makeReflection(effort: 8, bodyState: .sore, mood: .same),
            activity: runSummary
        )

        #expect(result.localizedCaseInsensitiveContains("sore"))
        #expect(result.localizedCaseInsensitiveContains("recovery"))
    }

    private var runSummary: WorkoutActivitySummary {
        WorkoutActivitySummary(
            distanceMeters: 5_000,
            elapsedSeconds: 1_800,
            sportType: "Run"
        )
    }

    private func makeReflection(
        effort: Int,
        bodyState: ReflectionBodyState,
        mood: ReflectionMood,
        conditions: [ReflectionCondition] = []
    ) throws -> WorkoutReflection {
        try WorkoutReflection.validated(
            id: UUID(uuidString: "B1BB54CB-7A0A-4B48-BCB3-627BB23E53A1")!,
            activityId: 42,
            userId: UUID(uuidString: "2769E3EF-B753-4EE6-8DA2-D370A57BF7B6")!,
            athleteId: 7,
            perceivedEffort: effort,
            bodyState: bodyState,
            mood: mood,
            conditionTags: conditions,
            note: nil,
            now: Date(timeIntervalSince1970: 1_787_601_600)
        )
    }
}
