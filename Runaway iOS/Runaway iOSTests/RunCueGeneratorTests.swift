import XCTest
@testable import Runaway_iOS

@MainActor
final class RunCueGeneratorTests: XCTestCase {
    func test_availableAppleModelGeneratesAndParsesLocalCues() async {
        let model = StubRunCueTextGenerator(
            isAvailable: true,
            response: """
            1. Settle into the work you chose.
            2. Patient effort is still progress.
            3. Run with the courage you value.
            4. Your consistency is showing today.
            5. Finish as the runner you are becoming.
            """
        )
        let generator = RunCueGenerator(model: model)

        let cues = await generator.generate(profile: profile, milestones: [])

        XCTAssertEqual(cues.count, 5)
        XCTAssertEqual(cues.first, "Settle into the work you chose.")
        XCTAssertEqual(model.callCount, 1)
        XCTAssertTrue(model.lastPrompt?.contains("Why they run: To prove I can do hard things") == true)
    }

    func test_unavailableAppleModelUsesDeterministicCuesWithoutCallingModel() async {
        let model = StubRunCueTextGenerator(isAvailable: false, response: "Unused")
        let generator = RunCueGenerator(model: model)

        let cues = await generator.generate(profile: profile, milestones: [])

        XCTAssertGreaterThanOrEqual(cues.count, 5)
        XCTAssertTrue(cues.contains { $0.contains("To prove I can do hard things") })
        XCTAssertEqual(model.callCount, 0)
    }

    func test_malformedAppleResponseFallsBackToDeterministicCues() async {
        let model = StubRunCueTextGenerator(isAvailable: true, response: "One cue only")
        let generator = RunCueGenerator(model: model)

        let cues = await generator.generate(profile: profile, milestones: [])

        XCTAssertGreaterThanOrEqual(cues.count, 5)
        XCTAssertNotEqual(cues, ["One cue only"])
        XCTAssertEqual(model.callCount, 1)
    }

    private var profile: MindsetProfile {
        MindsetProfile(
            runnerIdentity: "Consistent Builder",
            identitySummary: "You keep showing up.",
            whyIRun: "To prove I can do hard things",
            coreValues: ["Courage", "Patience"]
        )
    }
}

@MainActor
private final class StubRunCueTextGenerator: OnDeviceTextGenerating {
    let isAvailable: Bool
    private let response: String
    private(set) var callCount = 0
    private(set) var lastPrompt: String?

    init(isAvailable: Bool, response: String) {
        self.isAvailable = isAvailable
        self.response = response
    }

    func generateResponse(prompt: String, systemPrompt: String?, maxTokens: Int) async throws -> String {
        callCount += 1
        lastPrompt = prompt
        return response
    }
}
