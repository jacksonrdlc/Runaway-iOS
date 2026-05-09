//  ChatViewModelIdentityTests.swift
//  Runaway iOSTests

import XCTest
@testable import Runaway_iOS

@MainActor
final class ChatViewModelIdentityTests: XCTestCase {

    func test_suggestedPrompts_withProfile_includesIdentityPrompt() {
        let vm = ChatViewModel()
        vm.mindsetProfile = MindsetProfile(
            runnerIdentity: "Comeback Kid",
            identitySummary: "Someone returning after a break",
            whyIRun: "to prove I can",
            coreValues: ["resilience"]
        )
        let prompts = vm.suggestedPrompts
        XCTAssertTrue(
            prompts.contains(where: { $0.contains("Comeback Kid") }),
            "Expected identity-anchored prompt when profile is set"
        )
    }

    func test_suggestedPrompts_withoutProfile_usesGenericFourthPrompt() {
        let vm = ChatViewModel()
        // mindsetProfile defaults to nil
        let prompts = vm.suggestedPrompts
        XCTAssertTrue(
            prompts.contains("Create a training plan for me"),
            "Expected generic fourth prompt when no profile"
        )
    }
}
