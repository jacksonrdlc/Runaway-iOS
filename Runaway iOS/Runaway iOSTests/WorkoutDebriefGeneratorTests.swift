import XCTest
@testable import Runaway_iOS

@MainActor
final class WorkoutDebriefGeneratorTests: XCTestCase {
    func test_generationFailureCircuitBreakerBlocksRetriesUntilAvailabilityRefresh() {
        var circuitBreaker = FoundationModelFailureCircuitBreaker()

        XCTAssertTrue(circuitBreaker.canAttemptGeneration)

        circuitBreaker.recordFailure()

        XCTAssertFalse(circuitBreaker.canAttemptGeneration)

        circuitBreaker.reset()

        XCTAssertTrue(circuitBreaker.canAttemptGeneration)
    }

    func test_availableAppleModelGeneratesDebriefFromLocalReflectionContext() async {
        let model = StubOnDeviceTextGenerator(isAvailable: true, response: "  You managed a demanding run with patience.  ")
        let generator = WorkoutDebriefGenerator(model: model)

        let result = await generator.generate(input: .init(
            effort: 8,
            bodyStatus: "sore",
            mood: "proud",
            conditionTags: ["humid", "hills"],
            note: "Stayed patient on the climbs.",
            localDebrief: "Hard work with good control.",
            activitySummary: "5.0 miles in 52 minutes"
        ))

        XCTAssertEqual(result.text, "You managed a demanding run with patience.")
        XCTAssertEqual(result.source, .appleOnDevice)
        XCTAssertEqual(model.callCount, 1)
        XCTAssertTrue(model.lastPrompt?.contains("Effort: 8/10") == true)
        XCTAssertTrue(model.lastPrompt?.contains("Body: sore") == true)
        XCTAssertTrue(model.lastPrompt?.contains("Stayed patient on the climbs.") == true)
    }

    func test_unavailableAppleModelReturnsDeterministicDebriefWithoutGeneration() async {
        let model = StubOnDeviceTextGenerator(isAvailable: false, response: "Unused")
        let generator = WorkoutDebriefGenerator(model: model)

        let result = await generator.generate(input: .init(
            effort: 5,
            bodyStatus: "good",
            mood: "steady",
            conditionTags: [],
            note: nil,
            localDebrief: "A steady run that matched how you felt.",
            activitySummary: nil
        ))

        XCTAssertEqual(result.text, "A steady run that matched how you felt.")
        XCTAssertEqual(result.source, .deterministic)
        XCTAssertEqual(model.callCount, 0)
    }

    func test_failedAppleGenerationReturnsDeterministicDebrief() async {
        let model = StubOnDeviceTextGenerator(isAvailable: true, error: StubError.failed)
        let generator = WorkoutDebriefGenerator(model: model)

        let result = await generator.generate(input: .init(
            effort: 9,
            bodyStatus: "tight",
            mood: "drained",
            conditionTags: ["heat"],
            note: nil,
            localDebrief: "That was demanding. Recovery comes first.",
            activitySummary: "6.2 miles in 61 minutes"
        ))

        XCTAssertEqual(result.text, "That was demanding. Recovery comes first.")
        XCTAssertEqual(result.source, .deterministic)
        XCTAssertEqual(model.callCount, 1)
    }
}

@MainActor
private final class StubOnDeviceTextGenerator: OnDeviceTextGenerating {
    let isAvailable: Bool
    private let response: String
    private let error: Error?
    private(set) var callCount = 0
    private(set) var lastPrompt: String?

    init(isAvailable: Bool, response: String = "", error: Error? = nil) {
        self.isAvailable = isAvailable
        self.response = response
        self.error = error
    }

    func generateResponse(prompt: String, systemPrompt: String?, maxTokens: Int) async throws -> String {
        callCount += 1
        lastPrompt = prompt
        if let error { throw error }
        return response
    }
}

private enum StubError: Error {
    case failed
}
