//  FoundationModelsIdentityTests.swift
//  Runaway iOSTests

import XCTest
@testable import Runaway_iOS

@MainActor
final class FoundationModelsIdentityTests: XCTestCase {

    func test_systemPrompt_withIdentityContext_includesIdentityBlock() {
        let service = FoundationModelsService.shared
        let identity = RunnerIdentityContext(
            runnerIdentity: "Consistent Builder",
            whyIRun: "to clear my head",
            coreValues: ["consistency", "mental health"],
            earnedMilestoneKeys: ["first_run", "streak_7"]
        )
        let prompt = service.buildRunningCoachSystemPrompt(
            athleteContext: nil,
            recentActivities: nil,
            identityContext: identity
        )
        XCTAssertTrue(prompt.contains("Consistent Builder"), "Expected runner identity in prompt")
        XCTAssertTrue(prompt.contains("to clear my head"), "Expected whyIRun in prompt")
        XCTAssertTrue(prompt.contains("streak_7"), "Expected earned milestone in prompt")
        XCTAssertTrue(prompt.contains("Runner Identity:"), "Expected identity section header")
    }

    func test_systemPrompt_withoutIdentityContext_omitsIdentityBlock() {
        let service = FoundationModelsService.shared
        let prompt = service.buildRunningCoachSystemPrompt(
            athleteContext: nil,
            recentActivities: nil,
            identityContext: nil
        )
        XCTAssertFalse(prompt.contains("Runner Identity:"), "No identity section when context is nil")
    }
}
