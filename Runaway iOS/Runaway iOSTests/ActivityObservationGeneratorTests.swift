import XCTest
@testable import Runaway_iOS

@MainActor
final class ActivityObservationGeneratorTests: XCTestCase {
    func testUnavailableModelUsesMetricGroundedFallback() async {
        let model = ObservationModelStub(isAvailable: false, response: "")
        let generator = ActivityObservationGenerator(model: model)

        let observation = await generator.generate(activity: sampleActivity)

        XCTAssertTrue(observation.contains("3.1 miles"))
        XCTAssertTrue(observation.contains("8:03/mi"))
        XCTAssertEqual(model.callCount, 0)
    }

    func testAvailableModelUsesConciseGeneratedObservation() async {
        let model = ObservationModelStub(
            isAvailable: true,
            response: "Three controlled miles at 8:03 pace, with no invented context."
        )
        let generator = ActivityObservationGenerator(model: model)

        let observation = await generator.generate(activity: sampleActivity)

        XCTAssertEqual(observation, "Three controlled miles at 8:03 pace, with no invented context.")
        XCTAssertEqual(model.callCount, 1)
        XCTAssertTrue(model.lastPrompt?.contains("Distance: 3.1 miles") == true)
    }

    private var sampleActivity: LocalActivity {
        LocalActivity(
            id: 42,
            name: "Morning Run",
            type: "Run",
            distance: 5_000,
            start_date: Date(timeIntervalSince1970: 1_700_000_000),
            elapsed_time: 1_500
        )
    }
}

@MainActor
private final class ObservationModelStub: OnDeviceTextGenerating {
    let isAvailable: Bool
    let response: String
    private(set) var callCount = 0
    private(set) var lastPrompt: String?

    init(isAvailable: Bool, response: String) {
        self.isAvailable = isAvailable
        self.response = response
    }

    func generateResponse(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int
    ) async throws -> String {
        callCount += 1
        lastPrompt = prompt
        return response
    }
}
