import Foundation
import Testing
@testable import Runaway_iOS

struct WorkoutReflectionTests {
    @Test
    func effortBoundsAreInclusive() throws {
        _ = try makeReflection(effort: 1)
        _ = try makeReflection(effort: 10)
    }

    @Test(arguments: [0, 11])
    func invalidEffortIsRejected(_ effort: Int) {
        do {
            _ = try makeReflection(effort: effort)
            Issue.record("Expected effort \(effort) to be rejected")
        } catch let error as WorkoutReflection.ValidationError {
            #expect(error == .invalidEffort)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func notesAreTrimmedAndConditionTagsAreUnique() throws {
        let reflection = try makeReflection(
            conditions: [.heat, .heat, .wind],
            note: "  steady effort  "
        )

        #expect(reflection.note == "steady effort")
        #expect(reflection.conditionTags == [.heat, .wind])
    }

    @Test
    func emptyNoteBecomesNil() throws {
        let reflection = try makeReflection(note: "   \n  ")
        #expect(reflection.note == nil)
    }

    @Test
    func oversizedNoteIsRejected() {
        do {
            _ = try makeReflection(note: String(repeating: "x", count: 1_001))
            Issue.record("Expected oversized note to be rejected")
        } catch let error as WorkoutReflection.ValidationError {
            #expect(error == .noteTooLong)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    private func makeReflection(
        effort: Int = 5,
        bodyState: ReflectionBodyState = .good,
        mood: ReflectionMood = .same,
        conditions: [ReflectionCondition] = [],
        note: String? = nil
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
            note: note,
            now: Date(timeIntervalSince1970: 1_787_601_600)
        )
    }
}
