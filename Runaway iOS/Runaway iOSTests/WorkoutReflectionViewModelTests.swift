import XCTest
@testable import Runaway_iOS

@MainActor
final class WorkoutReflectionViewModelTests: XCTestCase {
    func test_formRequiresBodyAndMoodBeforeSubmission() {
        let viewModel = WorkoutReflectionViewModel()

        XCTAssertFalse(viewModel.canSubmit)

        viewModel.bodyStatus = .good
        XCTAssertFalse(viewModel.canSubmit)

        viewModel.mood = .steady
        XCTAssertTrue(viewModel.canSubmit)
    }

    func test_toggleConditionAddsAndRemovesOneSelection() {
        let viewModel = WorkoutReflectionViewModel()

        viewModel.toggleCondition(.poorSleep)
        XCTAssertEqual(viewModel.selectedConditions, [.poorSleep])

        viewModel.toggleCondition(.poorSleep)
        XCTAssertTrue(viewModel.selectedConditions.isEmpty)
    }

    func test_noteIsClampedToDomainLimit() {
        let viewModel = WorkoutReflectionViewModel()

        viewModel.note = String(repeating: "a", count: 1_010)

        XCTAssertEqual(viewModel.note.count, 1_000)
        XCTAssertEqual(viewModel.noteCharactersRemaining, 0)
    }

    func test_snapshotUsesRoundedEffortAndStableConditionOrder() throws {
        let viewModel = WorkoutReflectionViewModel()
        viewModel.effort = 7.6
        viewModel.bodyStatus = .tight
        viewModel.mood = .proud
        viewModel.toggleCondition(.hills)
        viewModel.toggleCondition(.wind)
        viewModel.note = "  Stayed patient.  "

        let snapshot = try XCTUnwrap(viewModel.snapshot())

        XCTAssertEqual(snapshot.effort, 8)
        XCTAssertEqual(snapshot.bodyStatus, .tight)
        XCTAssertEqual(snapshot.mood, .proud)
        XCTAssertEqual(snapshot.conditions, [.hills, .wind])
        XCTAssertEqual(snapshot.note, "Stayed patient.")
    }

    func test_formChoicesMapToPersistedDomainValues() {
        XCTAssertEqual(ReflectionBodyChoice.allCases.map(\.domainValue), [.good, .tight, .sore])
        XCTAssertEqual(ReflectionMoodChoice.allCases.map(\.domainValue), [.better, .same, .lower])
        XCTAssertEqual(
            ReflectionConditionChoice.allCases.map(\.domainValue),
            [.heat, .hills, .wind, .poorSleep, .stress]
        )
    }
}
