# Phase 5 — Identity-Aware Coach Chat Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the runner's MindsetProfile and earned milestones into the on-device Foundation Models chat so the coach system prompt, proactive greeting, and suggested prompts are identity-aware.

**Architecture:** `ChatViewModel` fetches `MindsetProfile` + milestones from Supabase on appear using the existing `RunnerMindsetService`. It passes a new `RunnerIdentityContext` value type into `FoundationModelsService.generateCoachResponse`, which injects an identity block into the system prompt. When no profile exists, every code path falls through to the existing generic behavior unchanged.

**Tech Stack:** Swift, SwiftUI, `@MainActor`, `FoundationModels` (iOS 26+), Supabase Swift SDK, XCTest

---

## File Map

| File | Change |
|---|---|
| `Runaway iOS/Runaway iOS/Services/FoundationModels/FoundationModelsService.swift` | Add `RunnerIdentityContext`; extend `generateCoachResponse` + `buildRunningCoachSystemPrompt` |
| `Runaway iOS/Runaway iOS/ViewModels/ChatViewModel.swift` | Add identity state; fetch on appear; pass context in `sendMessage`; identity greeting; identity suggested prompts |
| `Runaway iOS/Runaway iOS/Runaway iOSTests/FoundationModelsIdentityTests.swift` | New — tests for system prompt identity block |
| `Runaway iOS/Runaway iOS/Runaway iOSTests/ChatViewModelIdentityTests.swift` | New — tests for `suggestedPrompts` with/without profile |

---

## Existing types to know

```swift
// Models/MindsetModels.swift
struct MindsetProfile: Equatable, Sendable {
    let runnerIdentity: String
    let identitySummary: String
    let whyIRun: String
    let coreValues: [String]
}

struct RunnerIdentityMilestone: Identifiable, Decodable {
    let id: UUID
    let milestoneKey: String
    let label: String
    let description: String
    let earned: Bool
    let earnedAt: Date?
}

// Services/RunnerMindsetService.swift (Phase 2)
struct RunnerMindsetService {
    static func fetchProfile(athleteId: Int) async throws -> MindsetProfile?
    static func fetchMilestones(athleteId: Int) async throws -> [RunnerIdentityMilestone]
}
```

Test files use `@testable import Runaway_iOS` and `XCTest`.

---

## Task 1: `RunnerIdentityContext` + identity system prompt block

**Files:**
- Modify: `Runaway iOS/Runaway iOS/Services/FoundationModels/FoundationModelsService.swift`
- Create: `Runaway iOS/Runaway iOS/Runaway iOSTests/FoundationModelsIdentityTests.swift`

The key change: make `buildRunningCoachSystemPrompt` `internal` (not `private`) so tests can call it directly. Add `RunnerIdentityContext` as a top-level struct in the same file. Extend `generateCoachResponse` with a defaulted `identityContext` parameter.

- [ ] **Step 1: Create the test file with two failing tests**

Create `Runaway iOS/Runaway iOS/Runaway iOSTests/FoundationModelsIdentityTests.swift`:

```swift
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
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
xcodebuild test \
  -project "Runaway iOS/Runaway iOS.xcodeproj" \
  -scheme "Runaway iOS" \
  -destination "id=9989C246-EED8-4A64-A9D3-7E9915AD12F0" \
  -only-testing:"Runaway iOSTests/FoundationModelsIdentityTests" \
  2>&1 | tail -20
```

Expected: compile error (`RunnerIdentityContext` not found, `buildRunningCoachSystemPrompt` is private).

- [ ] **Step 3: Add `RunnerIdentityContext` struct to `FoundationModelsService.swift`**

At the bottom of `FoundationModelsService.swift`, before the `// MARK: - Supporting Types` section that already contains `AthleteContext`, `ActivitySummary`, and `GoalSummary`, add:

```swift
struct RunnerIdentityContext {
    let runnerIdentity: String
    let whyIRun: String
    let coreValues: [String]
    let earnedMilestoneKeys: [String]
}
```

- [ ] **Step 4: Extend `generateCoachResponse` and `buildRunningCoachSystemPrompt`**

Replace the existing `generateCoachResponse` method (lines 186–201) with:

```swift
func generateCoachResponse(
    message: String,
    athleteContext: AthleteContext? = nil,
    recentActivities: [ActivitySummary]? = nil,
    identityContext: RunnerIdentityContext? = nil
) async throws -> String {
    let systemPrompt = buildRunningCoachSystemPrompt(
        athleteContext: athleteContext,
        recentActivities: recentActivities,
        identityContext: identityContext
    )
    return try await generateResponse(prompt: message, systemPrompt: systemPrompt, maxTokens: 2048)
}
```

Replace the existing `buildRunningCoachSystemPrompt` method signature and body (currently `private func buildRunningCoachSystemPrompt(athleteContext:recentActivities:)`) with the new three-parameter version. Change `private` to `internal` so tests can access it:

```swift
func buildRunningCoachSystemPrompt(
    athleteContext: AthleteContext?,
    recentActivities: [ActivitySummary]?,
    identityContext: RunnerIdentityContext? = nil
) -> String {
    var prompt = """
    You are Runaway Coach, an expert AI running coach. You provide personalized training advice, motivation, and analysis.

    Guidelines:
    - Be encouraging but honest
    - Provide specific, actionable advice
    - Consider the athlete's fitness level and goals
    - Prioritize injury prevention and recovery
    - Keep responses concise and conversational
    """

    if let athlete = athleteContext {
        prompt += "\n\nAthlete Profile:"
        if let weeklyMileage = athlete.weeklyMileage {
            prompt += "\n- Weekly mileage: \(String(format: "%.1f", weeklyMileage)) miles"
        }
        if let goal = athlete.currentGoal {
            prompt += "\n- Current goal: \(goal)"
        }
    }

    if let activities = recentActivities, !activities.isEmpty {
        prompt += "\n\nRecent Activities:"
        for activity in activities.prefix(3) {
            prompt += "\n- \(activity.distanceMiles) mi @ \(activity.averagePace)"
        }
    }

    if let identity = identityContext {
        let valuesString = identity.coreValues.joined(separator: ", ")
        let milestonesString = identity.earnedMilestoneKeys.isEmpty
            ? "none yet"
            : identity.earnedMilestoneKeys.joined(separator: ", ")
        prompt += """


        Runner Identity:
        - They identify as: \(identity.runnerIdentity)
        - Why they run: \(identity.whyIRun)
        - Core values: \(valuesString)
        - Earned milestones: \(milestonesString)
        Use this identity when they ask about motivation, struggle, or what kind of runner they are. Do not recite these facts back to them unprompted — let them inform the tone and framing of your responses.
        """
    }

    return prompt
}
```

- [ ] **Step 5: Run tests to confirm they pass**

```bash
xcodebuild test \
  -project "Runaway iOS/Runaway iOS.xcodeproj" \
  -scheme "Runaway iOS" \
  -destination "id=9989C246-EED8-4A64-A9D3-7E9915AD12F0" \
  -only-testing:"Runaway iOSTests/FoundationModelsIdentityTests" \
  2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add \
  "Runaway iOS/Runaway iOS/Services/FoundationModels/FoundationModelsService.swift" \
  "Runaway iOS/Runaway iOS/Runaway iOSTests/FoundationModelsIdentityTests.swift"
git commit -m "feat: add RunnerIdentityContext and identity system prompt block (Phase 5)"
```

---

## Task 2: `ChatViewModel` identity fetch, wiring, greeting, and suggested prompts

**Files:**
- Modify: `Runaway iOS/Runaway iOS/ViewModels/ChatViewModel.swift`
- Create: `Runaway iOS/Runaway iOS/Runaway iOSTests/ChatViewModelIdentityTests.swift`

`ChatViewModel` is `@MainActor`. The two new stored properties are `internal` (not private) so tests can set them directly.

- [ ] **Step 1: Create test file with two failing tests**

Create `Runaway iOS/Runaway iOS/Runaway iOSTests/ChatViewModelIdentityTests.swift`:

```swift
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
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
xcodebuild test \
  -project "Runaway iOS/Runaway iOS.xcodeproj" \
  -scheme "Runaway iOS" \
  -destination "id=9989C246-EED8-4A64-A9D3-7E9915AD12F0" \
  -only-testing:"Runaway iOSTests/ChatViewModelIdentityTests" \
  2>&1 | tail -20
```

Expected: compile error (`mindsetProfile` not found on `ChatViewModel`).

- [ ] **Step 3: Add identity state properties to `ChatViewModel`**

In `ChatViewModel.swift`, after the `@Published var isUsingOnDeviceAI = false` line in the Published Properties section, add:

```swift
// Identity context loaded on appear — internal so tests can inject directly
var mindsetProfile: MindsetProfile? = nil
var earnedMilestones: [RunnerIdentityMilestone] = []
```

- [ ] **Step 4: Fetch profile and milestones on appear**

In `generateProactiveGreeting()`, before the `hasGeneratedGreeting = true` line, add the concurrent fetch:

```swift
// Load runner identity for this session
if let athleteId = DataManager.shared.athlete?.id {
    async let profileFetch = RunnerMindsetService.fetchProfile(athleteId: athleteId)
    async let milestonesFetch = RunnerMindsetService.fetchMilestones(athleteId: athleteId)
    mindsetProfile = try? await profileFetch
    earnedMilestones = ((try? await milestonesFetch) ?? []).filter { $0.earned }
}
```

- [ ] **Step 5: Pass identity context in `sendMessage(_:)`**

In `sendMessage(_:)`, find the block that calls `ChatService.buildAthleteContext()` and `buildRecentActivities()`. After building those, add the identity context and pass it to `generateCoachResponse`:

```swift
// Build identity context from loaded profile
let identityContext: RunnerIdentityContext? = mindsetProfile.map { profile in
    RunnerIdentityContext(
        runnerIdentity: profile.runnerIdentity,
        whyIRun: profile.whyIRun,
        coreValues: profile.coreValues,
        earnedMilestoneKeys: earnedMilestones.map { $0.milestoneKey }
    )
}

let response = try await foundationModelsService.generateCoachResponse(
    message: text,
    athleteContext: athleteContext,
    recentActivities: recentActivities,
    identityContext: identityContext
)
```

The existing call to `foundationModelsService.generateCoachResponse` in `sendMessage` passes only `message`, `athleteContext`, and `recentActivities`. Replace it with the call above that also passes `identityContext`.

- [ ] **Step 6: Update `buildFallbackGreeting()` to be identity-aware**

Replace the entire `buildFallbackGreeting()` method with:

```swift
private func buildFallbackGreeting() -> String {
    let activities = dataManager.activities.prefix(5)

    let thisWeekCount = activities.filter { activity in
        guard let timestamp = activity.activity_date ?? activity.start_date else { return false }
        let activityDate = Date(timeIntervalSince1970: timestamp)
        return Calendar.current.isDate(activityDate, equalTo: Date(), toGranularity: .weekOfYear)
    }.count

    // Identity-aware greeting when profile is present
    if let profile = mindsetProfile {
        if thisWeekCount > 0 {
            return """
            You're a \(profile.runnerIdentity) — and the data backs that up.

            \(thisWeekCount) \(thisWeekCount == 1 ? "run" : "runs") this week. You're showing up, which is exactly how that identity gets built.

            What's on your mind?
            """
        } else if !activities.isEmpty {
            return """
            You're a \(profile.runnerIdentity) — and rest is part of that.

            It's been quiet this week. Sometimes that's intentional, sometimes life just happens. Either way, you're still here.

            What's going on?
            """
        } else {
            return """
            You're a \(profile.runnerIdentity) — every identity starts somewhere.

            I don't see any runs yet. But you're here, and that matters. What's bringing you to running?
            """
        }
    }

    // Generic fallback (no profile set)
    if activities.isEmpty {
        return """
        Hey. 👋

        I'm here — not just as a coach, but as a mirror. My job is to reflect back who you're becoming, especially when you can't see it yourself.

        Whether you're just starting out or finding your way back, every step forward is an act of self-definition. What's on your mind today?
        """
    } else if thisWeekCount > 0 {
        return """
        Hey. 👋

        \(thisWeekCount) \(thisWeekCount == 1 ? "run" : "runs") this week. You're showing up — and that's not nothing. That's exactly how you become someone different than who you thought you were.

        I've been looking at your recent training. What are you feeling? What's working, what's not? I'm curious where your head is at.
        """
    } else {
        return """
        Hey. 👋

        It's been a minute since your last run. That's okay — sometimes life gets in the way, sometimes we need the break. What matters is you're here now.

        When you're ready, I'm ready. What's going on? Want to ease back in, or talk through what's been holding you back?
        """
    }
}
```

- [ ] **Step 7: Update `suggestedPrompts` to include identity-anchored option**

Replace the existing `suggestedPrompts` computed property with:

```swift
var suggestedPrompts: [String] {
    if messages.isEmpty {
        var prompts = [
            "How am I doing with my training?",
            "What should my easy run pace be?",
            "Can you analyze my recent runs?",
            "Create a training plan for me"
        ]
        if let profile = mindsetProfile {
            prompts[3] = "What does being a \(profile.runnerIdentity) actually mean for my training?"
        }
        return prompts
    } else {
        return [
            "Tell me more",
            "What else should I focus on?",
            "How can I improve?"
        ]
    }
}
```

- [ ] **Step 8: Run tests to confirm they pass**

```bash
xcodebuild test \
  -project "Runaway iOS/Runaway iOS.xcodeproj" \
  -scheme "Runaway iOS" \
  -destination "id=9989C246-EED8-4A64-A9D3-7E9915AD12F0" \
  -only-testing:"Runaway iOSTests/ChatViewModelIdentityTests" \
  2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 9: Commit**

```bash
git add \
  "Runaway iOS/Runaway iOS/ViewModels/ChatViewModel.swift" \
  "Runaway iOS/Runaway iOS/Runaway iOSTests/ChatViewModelIdentityTests.swift"
git commit -m "feat: identity-aware greeting, context wiring, and suggested prompts in ChatViewModel (Phase 5)"
```

---

## Task 3: Build verification

**Files:** None — read-only verification step.

- [ ] **Step 1: Run full build**

```bash
xcodebuild \
  -project "Runaway iOS/Runaway iOS.xcodeproj" \
  -scheme "Runaway iOS" \
  -destination "id=9989C246-EED8-4A64-A9D3-7E9915AD12F0" \
  build \
  2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 2: Run all unit tests**

```bash
xcodebuild test \
  -project "Runaway iOS/Runaway iOS.xcodeproj" \
  -scheme "Runaway iOS" \
  -destination "id=9989C246-EED8-4A64-A9D3-7E9915AD12F0" \
  -only-testing:"Runaway iOSTests" \
  2>&1 | grep -E "TEST SUCCEEDED|TEST FAILED|error:"
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 3: Commit if any minor fixes were needed during verification**

Only commit if changes were required. Otherwise skip.

---

## Success Criteria

- Runner with a `MindsetProfile` opens chat → greeting names their runner identity, not a generic "Hey"
- Runner sends a message → system prompt contains the identity block; coach responses are identity-informed
- Runner without a profile → greeting, system prompt, and suggested prompts are identical to pre-Phase-5 behavior
- `fetchProfile` throws → `mindsetProfile = nil`, chat proceeds with generic behavior
- All unit tests pass; `xcodebuild` clean build succeeds
