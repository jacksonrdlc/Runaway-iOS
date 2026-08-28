# Training Profile and Complementary Scheduling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an on-device Fitness Profile that safely blends running with selected strength, cycling, swimming, walking, hiking, and mobility sessions across onboarding, weekly plans, and Today recommendations.

**Architecture:** A versioned `TrainingProfile` and observable local store become the single source of truth for activity preferences. A pure `ComplementarySchedulingPolicy` ranks valid workouts using semantic workout traits; `TrainingPlanService` and `TodayRecommendationPolicy` consume that policy so weekly plans and daily alternatives cannot drift.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing, UserDefaults, Codable, existing Runaway design tokens, iOS 27 Foundation Models only for optional wording

**Spec:** `docs/superpowers/specs/2026-08-27-training-profile-design.md`

## Global Constraints

- Minimum deployment target remains iOS 27.
- All scheduling decisions must be deterministic and available offline.
- No external LLM API, new Edge Function, or server-side profile dependency is allowed.
- Apple Foundation Models may phrase structured reasons but cannot choose or alter a workout.
- Running mileage and run count must exclude every non-running activity.
- Completed workouts must never be overwritten during regeneration.
- Existing stored plan and workout raw values must continue decoding.
- Use the existing Runaway spacing, surface, typography, and accessibility patterns.
- Amber remains reserved for running emphasis and primary actions; supporting activities use restrained semantic color.
- Do not perform Git operations unless the user separately requests them.

## File Structure

### New Files

- `Runaway iOS/Models/TrainingProfile.swift`: versioned profile value types, roles, validation, migration defaults, and fingerprinting.
- `Runaway iOS/Services/TrainingProfileStore.swift`: local loading, repair, persistence, and published profile state.
- `Runaway iOS/Models/ComplementarySchedulingPolicy.swift`: pure candidate scoring, constraints, load classes, and structured reasons.
- `Runaway iOS/Components/TrainingProfileComponents.swift`: shared SwiftUI controls used by onboarding and settings.
- `Runaway iOS/Views/TrainingProfileView.swift`: settings editor, save behavior, and regeneration choice.
- `Runaway iOS/Runaway iOSTests/TrainingProfileTests.swift`: profile defaults, validation, migration, persistence, and fingerprint tests.
- `Runaway iOS/Runaway iOSTests/ComplementarySchedulingPolicyTests.swift`: scheduling constraints, preference ranking, and impossible-schedule tests.
- `Runaway iOS/Runaway iOSTests/TrainingProfileIntegrationTests.swift`: regeneration, Today consistency, and mileage isolation tests.

### Modified Files

- `Runaway iOS/Models/WeeklyTrainingPlan.swift`: explicit activity types and semantic workout traits.
- `Runaway iOS/Models/TodayRecommendationPolicy.swift`: profile-aware alternatives and structured reason consumption.
- `Runaway iOS/Services/TrainingPlanService.swift`: profile-aware generation and safe remaining-week regeneration.
- `Runaway iOS/Managers/DataManager.swift`: profile fingerprint cache metadata and safe plan replacement.
- `Runaway iOS/Models/OnboardingModels.swift`: activity and schedule answers in onboarding state.
- `Runaway iOS/Services/OnboardingService.swift`: convert onboarding answers into the shared profile model.
- `Runaway iOS/Views/Onboarding/OnboardingContainerView.swift`: insert profile steps and provide the shared store.
- `Runaway iOS/Views/Onboarding/OnboardingStepViews.swift`: activity mix and schedule constraint steps.
- `Runaway iOS/Views/CoachSettingsView.swift`: route Training Preferences to the profile editor.
- `Runaway iOS/Views/SettingsView.swift`: expose profile personalization status if this is the current preferences entry point.
- `Runaway iOS/Components/WorkoutComponents.swift`: profile-aware Next Up reason and human-readable badges.
- `Runaway iOS/Views/WeeklyTrainingPlanView.swift`: profile personalization prompt and regeneration states.
- `Runaway iOS/Runaway_iOSApp.swift`: inject one shared `TrainingProfileStore` if the app currently uses root environment injection.
- `Runaway iOS.xcodeproj/project.pbxproj`: register new source and test files when the project is not folder-synchronized.

---

### Task 1: Versioned Training Profile and Local Store

**Files:**
- Create: `Runaway iOS/Models/TrainingProfile.swift`
- Create: `Runaway iOS/Services/TrainingProfileStore.swift`
- Create: `Runaway iOS/Runaway iOSTests/TrainingProfileTests.swift`
- Modify: `Runaway iOS.xcodeproj/project.pbxproj`

**Interfaces:**
- Produces: `TrainingActivity`, `TrainingActivityRole`, `TrainingActivityPreference`, `StrengthEquipment`, `TrainingExperience`, `TrainingProfile`, `TrainingProfile.ValidationResult`, and `TrainingProfileStore`.
- Produces: `TrainingProfile.validated(existingPlan:) -> TrainingProfile.ValidationResult`.
- Produces: `TrainingProfile.fingerprint: String`.
- Produces: `TrainingProfileStore.profile`, `TrainingProfileStore.needsPersonalization`, `save(_:)`, and `resetToDefault()`.

- [ ] **Step 1: Write failing profile model tests**

```swift
import Testing
@testable import Runaway_iOS

@Suite("Training profile")
struct TrainingProfileTests {
    @Test("Default is a valid running-first profile")
    func runningFirstDefault() {
        let profile = TrainingProfile.runningFirstDefault
        #expect(profile.schemaVersion == 1)
        #expect(profile.preference(for: .running)?.role == .primary)
        #expect(profile.primaryActivity == .running)
    }

    @Test("Validation keeps one primary and caps requested sessions")
    func validationRepairsImpossibleMix() {
        let profile = TrainingProfile(
            schemaVersion: 1,
            activities: [
                .init(activity: .running, role: .primary, sessionsPerWeek: 5),
                .init(activity: .strength, role: .primary, sessionsPerWeek: 4)
            ],
            trainingDaysPerWeek: 4,
            preferredLongRunWeekday: 1,
            unavailableWeekdays: [],
            strengthEquipment: .dumbbells,
            strengthExperience: .intermediate
        )

        let result = profile.validated(existingPlan: nil)
        #expect(result.profile.activities.filter { $0.role == .primary }.count == 1)
        #expect(result.profile.activities.reduce(0) { $0 + $1.sessionsPerWeek } <= 4)
        #expect(result.wasRepaired)
    }

    @Test("Fingerprint changes only when scheduling inputs change")
    func stableFingerprint() {
        let original = TrainingProfile.runningFirstDefault
        var changed = original
        changed.trainingDaysPerWeek = 6
        #expect(original.fingerprint == TrainingProfile.runningFirstDefault.fingerprint)
        #expect(original.fingerprint != changed.fingerprint)
    }
}
```

- [ ] **Step 2: Run the new suite and confirm it fails because profile types do not exist**

Run:

```bash
xcodebuild test -project "Runaway iOS.xcodeproj" -scheme "Runaway iOS" -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -only-testing:'Runaway iOSTests/TrainingProfileTests'
```

Expected: compilation fails on `TrainingProfile` and related symbols.

- [ ] **Step 3: Implement the profile model with stable Codable raw values**

```swift
enum TrainingActivity: String, Codable, CaseIterable, Identifiable, Sendable {
    case running, strength, cycling, swimming, walking, hiking, mobility
    var id: String { rawValue }
}

enum TrainingActivityRole: String, Codable, CaseIterable, Sendable {
    case primary, supporting, optional
}

struct TrainingActivityPreference: Codable, Equatable, Sendable, Identifiable {
    var activity: TrainingActivity
    var role: TrainingActivityRole
    var sessionsPerWeek: Int
    var id: TrainingActivity { activity }
}

struct TrainingProfile: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1
    var schemaVersion: Int
    var activities: [TrainingActivityPreference]
    var trainingDaysPerWeek: Int
    var preferredLongRunWeekday: Int
    var unavailableWeekdays: Set<Int>
    var strengthEquipment: StrengthEquipment
    var strengthExperience: TrainingExperience
}
```

Validation must clamp days to `1...7`, remove duplicate activities, preserve running as primary when multiple primaries are supplied, lower optional then supporting frequencies before primary frequency, and always return one primary activity.

- [ ] **Step 4: Add failing store migration and persistence tests**

```swift
@Test("Missing profile migrates without blocking existing users")
@MainActor
func migratesMissingProfile() {
    let defaults = UserDefaults(suiteName: #function)!
    defaults.removePersistentDomain(forName: #function)
    let store = TrainingProfileStore(defaults: defaults, existingPlan: nil)
    #expect(store.profile.primaryActivity == .running)
    #expect(store.needsPersonalization)
}

@Test("Saved profile reloads")
@MainActor
func roundTrip() throws {
    let defaults = UserDefaults(suiteName: #function)!
    defaults.removePersistentDomain(forName: #function)
    let store = TrainingProfileStore(defaults: defaults, existingPlan: nil)
    var profile = store.profile
    profile.trainingDaysPerWeek = 6
    try store.save(profile)
    #expect(TrainingProfileStore(defaults: defaults, existingPlan: nil).profile.trainingDaysPerWeek == 6)
}
```

- [ ] **Step 5: Implement `TrainingProfileStore` using injected UserDefaults**

Use `trainingProfile.v1` for encoded data and `trainingProfile.personalized.v1` for the prompt state. Decode, validate, and repair before publishing. `save(_:)` validates first, writes atomically through `UserDefaults.set(Data, forKey:)`, updates `profile`, and marks personalization complete only after encoding succeeds.

- [ ] **Step 6: Run Task 1 tests**

Expected: all `TrainingProfileTests` pass.

---

### Task 2: Explicit Workout Types and Semantic Traits

**Files:**
- Modify: `Runaway iOS/Models/WeeklyTrainingPlan.swift`
- Create: `Runaway iOS/Runaway iOSTests/ComplementarySchedulingPolicyTests.swift`

**Interfaces:**
- Consumes: `TrainingActivity` from Task 1.
- Produces: additive `WorkoutType` cases `.cycling`, `.swimming`, `.walking`, and `.hiking`.
- Produces: `WorkoutType.activity`, `loadClass`, `isRecoveryCompatible`, `isLowerBodyDemanding`, `isHighIntensity`, and `displayName`.

- [ ] **Step 1: Write failing semantic trait tests**

```swift
@Suite("Workout semantics")
struct WorkoutSemanticTests {
    @Test func explicitActivitiesDoNotCountAsRuns() {
        for type in [WorkoutType.cycling, .swimming, .walking, .hiking] {
            #expect(!type.isRunning)
        }
    }

    @Test func demandingAndRecoveryTraitsAreExplicit() {
        #expect(WorkoutType.lowerBody.isLowerBodyDemanding)
        #expect(WorkoutType.intervalRun.isHighIntensity)
        #expect(WorkoutType.stretchMobility.isRecoveryCompatible)
        #expect(WorkoutType.easyRun.displayName == "Easy Run")
    }
}
```

- [ ] **Step 2: Run the semantic tests and confirm missing-case failures**

Expected: compilation fails for the new cases and traits.

- [ ] **Step 3: Add cases without changing existing raw values**

```swift
enum TrainingLoadClass: Int, Codable, Comparable, Sendable {
    case recovery, low, moderate, high
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}
```

Map every existing and new workout type explicitly. Do not infer semantics from names. Keep `.crossTraining` for old plans and map it to a generic optional aerobic activity rather than deleting or renaming it.

- [ ] **Step 4: Run semantic tests and existing weekly-plan decoding tests**

Expected: new tests pass and existing plans still decode.

---

### Task 3: Pure Complementary Scheduling Policy

**Files:**
- Create: `Runaway iOS/Models/ComplementarySchedulingPolicy.swift`
- Modify: `Runaway iOS/Runaway iOSTests/ComplementarySchedulingPolicyTests.swift`

**Interfaces:**
- Consumes: `TrainingProfile`, `WorkoutType`, `DailyWorkout`, readiness disposition, recent completed workouts, and weekday availability.
- Produces: `SchedulingContext`, `WorkoutCandidate`, `SchedulingReason`, `rankedCandidates(for:)`, and `buildWeeklyAssignments(context:)`.

- [ ] **Step 1: Write the hard-constraint tests**

```swift
@Test("Heavy legs never border long or quality runs")
func protectsKeyRuns() {
    let context = SchedulingFixtures.runningAndStrength(longRunWeekday: 1)
    let assignments = ComplementarySchedulingPolicy().buildWeeklyAssignments(context: context)
    let lowerBodyDays = assignments.filter { $0.workoutType.isLowerBodyDemanding }.map(\.weekday)
    #expect(!lowerBodyDays.contains(7))
    #expect(!lowerBodyDays.contains(2))
}

@Test("Unselected activities are never candidates")
func respectsProfile() {
    let context = SchedulingFixtures.runningOnly()
    let candidates = ComplementarySchedulingPolicy().rankedCandidates(for: context.today)
    #expect(candidates.allSatisfy { $0.workoutType.activity == .running || $0.workoutType == .rest })
}

@Test("Completed and unavailable days remain untouched")
func preservesProtectedDays() {
    let context = SchedulingFixtures.withCompletedTuesdayAndUnavailableFriday()
    let result = ComplementarySchedulingPolicy().buildWeeklyAssignments(context: context)
    #expect(result.first(where: { $0.weekday == 3 })?.id == context.completedTuesday.id)
    #expect(result.first(where: { $0.weekday == 6 }) == nil)
}
```

- [ ] **Step 2: Run policy tests and verify they fail on missing policy types**

- [ ] **Step 3: Implement hard constraints before preference scoring**

`SchedulingContext` must contain seven dated slots, fixed primary workouts, completed workouts, readiness, race phase, and profile. Candidate rejection returns a structured reason for diagnostics. Build primary run anchors first, then fill supporting sessions without mutating inputs.

- [ ] **Step 4: Add failing preference tests**

```swift
@Test("Upper body is preferred after a long run")
func upperBodyAfterLongRun() {
    let candidates = ComplementarySchedulingPolicy().rankedCandidates(
        for: SchedulingFixtures.dayAfterLongRun()
    )
    #expect(candidates.first?.workoutType == .upperBody)
    #expect(candidates.first?.reason == .preservesLegRecovery)
}

@Test("Low readiness prefers mobility or low aerobic work")
func lowReadinessAlternatives() {
    let candidates = ComplementarySchedulingPolicy().rankedCandidates(
        for: SchedulingFixtures.lowReadinessMixedAthlete()
    )
    #expect(candidates.first?.workoutType.isRecoveryCompatible == true)
    #expect(candidates.allSatisfy { !$0.workoutType.isHighIntensity })
}

@Test("Impossible mix preserves primary work")
func primaryWins() {
    let result = ComplementarySchedulingPolicy().buildWeeklyAssignments(
        context: SchedulingFixtures.impossibleSixSessionsAcrossFourDays()
    )
    #expect(result.filter { $0.workoutType.activity == .running }.count == 3)
    #expect(result.count == 4)
}
```

- [ ] **Step 5: Implement deterministic preference scoring**

Use integer scores with explicit constants: required primary `1000`, profile frequency need `300`, recovery fit `150`, preferred adjacency `100`, duplicate-category penalty `-120`, high-load readiness penalty `-500`, and hard-constraint rejection. Sort ties by `WorkoutType.rawValue` so repeated generation is stable.

- [ ] **Step 6: Run the complete scheduling suite**

Expected: all trait, constraint, ranking, and impossible-schedule tests pass.

---

### Task 4: Plan Generation, Cache Fingerprints, and Safe Regeneration

**Files:**
- Modify: `Runaway iOS/Services/TrainingPlanService.swift`
- Modify: `Runaway iOS/Managers/DataManager.swift`
- Create: `Runaway iOS/Runaway iOSTests/TrainingProfileIntegrationTests.swift`

**Interfaces:**
- Consumes: `TrainingProfile`, `ComplementarySchedulingPolicy`, and existing plan generation inputs.
- Produces: `PlanRegenerationScope.nextWeek` and `.remainingCurrentWeek`.
- Produces: `TrainingPlanService.generatePlan(profile:scope:existingPlan:)`.
- Produces: cache metadata `profileFingerprint` and `profileSchemaVersion`.

- [ ] **Step 1: Write failing plan integration tests**

```swift
@Test("Running and strength plan places two strength sessions safely")
func mixedPlan() async throws {
    let plan = try await makeService().generatePlan(
        profile: .runningAndStrengthFixture,
        scope: .nextWeek,
        existingPlan: nil
    )
    #expect(plan.workouts.filter { $0.workoutType.isStrength }.count == 2)
    #expect(plan.workouts.filter { $0.workoutType.isRunning }.count == 4)
}

@Test("Remaining-week regeneration preserves completed workouts")
func preservesCompleted() async throws {
    let existing = WeeklyTrainingPlan.fixtureWithCompletedMonday
    let regenerated = try await makeService().generatePlan(
        profile: .runningAndStrengthFixture,
        scope: .remainingCurrentWeek,
        existingPlan: existing
    )
    #expect(regenerated.workouts.first?.id == existing.workouts.first?.id)
    #expect(regenerated.workouts.first?.isCompleted == true)
}

@Test("Non-running sessions do not change mileage or run count")
func mileageIsolation() async throws {
    let plan = try await makeService().generatePlan(
        profile: .runningStrengthCyclingFixture,
        scope: .nextWeek,
        existingPlan: nil
    )
    #expect(plan.totalPlannedMiles == plan.workouts.filter { $0.workoutType.isRunning }.compactMap(\.distanceMiles).reduce(0, +))
    #expect(plan.plannedRunCount == plan.workouts.filter { $0.workoutType.isRunning }.count)
}
```

- [ ] **Step 2: Run integration tests and confirm failures on missing generation interface**

- [ ] **Step 3: Replace the hardcoded supporting-day layout with policy assignments**

Keep existing race phase, weekly mileage, quality session, long-run, and taper calculations. Convert those results into fixed primary anchors, ask the policy to fill valid remaining days, then create `DailyWorkout` values. Generate deterministic coaching reasons directly from `SchedulingReason`; optional Foundation Models wording must be a presentation-only post-process.

- [ ] **Step 4: Add profile metadata to cached plan records**

When loading a cached plan, compare both `profileSchemaVersion` and `profileFingerprint`. A mismatch marks the plan stale but does not delete it. Only replace the active plan after new plan generation succeeds.

- [ ] **Step 5: Implement both regeneration scopes**

`.nextWeek` leaves the current plan untouched and stores the generated plan at the next weekly boundary. `.remainingCurrentWeek` copies completed workouts and dates exactly, preserves today's completed workout, and regenerates only future incomplete slots.

- [ ] **Step 6: Run profile integration tests plus existing training-plan tests**

Expected: mixed scheduling, cache invalidation, safe regeneration, mileage, and existing running progression all pass.

---

### Task 5: Profile-Aware Today Recommendations

**Files:**
- Modify: `Runaway iOS/Models/TodayRecommendationPolicy.swift`
- Modify: `Runaway iOS/Components/WorkoutComponents.swift`
- Modify: `Runaway iOS/Runaway iOSTests/TodayRecommendationPolicyTests.swift`
- Modify: `Runaway iOS/Runaway iOSTests/TrainingProfileIntegrationTests.swift`

**Interfaces:**
- Consumes: `TrainingProfile`, recent workouts, planned workout, readiness, and `ComplementarySchedulingPolicy.rankedCandidates(for:)`.
- Produces: `TodayRecommendation` with `workoutType`, `title`, `reason`, and existing adjustment action.

- [ ] **Step 1: Add failing Today behavior tests**

```swift
@Test("Strength athlete receives upper body after long run")
func profileAwareNextUp() {
    let result = TodayRecommendationPolicy.recommend(
        plannedWorkout: nil,
        profile: .runningAndStrengthFixture,
        recentWorkouts: [.completedLongRunYesterday],
        readiness: .moderate
    )
    #expect(result.workoutType == .upperBody)
    #expect(result.reason == "Placed after yesterday's long run to preserve leg recovery.")
}

@Test("Running-only fallback remains a run or recovery")
func runningOnlyFallback() {
    let result = TodayRecommendationPolicy.recommend(
        plannedWorkout: nil,
        profile: .runningFirstDefault,
        recentWorkouts: [],
        readiness: .good
    )
    #expect(result.workoutType.isRunning || result.workoutType.isRecoveryCompatible)
}
```

- [ ] **Step 2: Run Today tests and confirm the old run-only fallback fails the new cases**

- [ ] **Step 3: Route fallback and readiness alternatives through the shared policy**

Planned workouts remain first priority unless the existing readiness logic requires an adjustment. When no workout is planned, use the highest-ranked profile-valid candidate. Preserve the existing user choice flow for recovery, easier session, original session, receipt, and Undo.

- [ ] **Step 4: Fix badge and explanation presentation**

Replace raw-value badge formatting with `workoutType.displayName`. Show a single muted explanation line only when a structured placement reason exists. Use semantic color from the activity category; do not make all supporting-workout badges amber.

- [ ] **Step 5: Run Today and integration suites**

Expected: existing adaptation tests and new profile-aware tests pass.

---

### Task 6: Shared Fitness Profile Editor and Safe Save Flow

**Files:**
- Create: `Runaway iOS/Components/TrainingProfileComponents.swift`
- Create: `Runaway iOS/Views/TrainingProfileView.swift`
- Modify: `Runaway iOS/Views/CoachSettingsView.swift`
- Modify: `Runaway iOS/Views/SettingsView.swift`
- Modify: `Runaway iOS/Runaway_iOSApp.swift`
- Modify: `Runaway iOS.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: shared `TrainingProfileStore` and `TrainingPlanService` regeneration API.
- Produces: `ActivityMixEditor`, `TrainingScheduleEditor`, and `TrainingProfileView`.

**UI Intent:** Help an athlete describe how they actually train without making setup feel clinical or complicated.

**Hierarchy:** The readable weekly mix summary leads; selected activities are second; schedule constraints and equipment are supporting details.

**Palette:** Existing Runaway navy surfaces; restrained blue for aerobic cross-training, green for recovery/mobility, and amber only for running emphasis and primary save actions.

**Depth:** Existing subtle surface shifts and quiet borders, avoiding new shadow or radius systems.

**Surfaces:** Reuse current grouped settings cards and input surfaces.

**Typography:** Reuse existing Runaway type tokens; activity names use primary text, roles use secondary text, and metadata uses muted text.

**Spacing:** Reuse the existing 4-point token grid and 44-point minimum controls.

- [ ] **Step 1: Add a UI model test for conditional controls and summary copy**

```swift
@Test("Profile summary reflects the selected weekly mix")
func summaryCopy() {
    #expect(TrainingProfile.runningAndStrengthFixture.summary == "4 runs + 2 strength sessions, long run Sunday")
    #expect(TrainingProfile.runningFirstDefault.showsStrengthControls == false)
}
```

- [ ] **Step 2: Run the focused test and verify missing presentation properties**

- [ ] **Step 3: Implement reusable native SwiftUI controls**

`ActivityMixEditor` binds to a draft profile and renders `TrainingActivity.allCases` as native buttons with checkmarks, role menus, and weekly steppers. It must prevent removing the only primary activity and hide strength equipment/experience unless strength is selected.

`TrainingScheduleEditor` binds training days, preferred long-run weekday, and unavailable weekdays. It surfaces validation repairs inline before save.

- [ ] **Step 4: Implement `TrainingProfileView` with draft-state saving**

Saving an unchanged profile dismisses immediately. A material change saves the profile, then presents native confirmation actions:

- `Update next week` as default.
- `Rebalance this week` as secondary.
- `Cancel` without plan mutation.

On regeneration failure, keep the saved profile, preserve the old plan, show the failure message, and offer Retry.

- [ ] **Step 5: Wire the existing Training Preferences row to the editor**

Use the app's existing navigation style and environment injection. Do not add a second settings destination or duplicate profile store.

- [ ] **Step 6: Run model tests and perform accessibility-focused UI validation**

Verify activity rows, role menus, steppers, weekday controls, save, retry, and regeneration choices have labels and at least 44-point hit targets.

---

### Task 7: Onboarding and Existing-User Personalization

**Files:**
- Modify: `Runaway iOS/Models/OnboardingModels.swift`
- Modify: `Runaway iOS/Services/OnboardingService.swift`
- Modify: `Runaway iOS/Views/Onboarding/OnboardingContainerView.swift`
- Modify: `Runaway iOS/Views/Onboarding/OnboardingStepViews.swift`
- Modify: `Runaway iOS/Views/WeeklyTrainingPlanView.swift`
- Modify: `Runaway iOS/Components/WorkoutComponents.swift`
- Modify: `Runaway iOS/Runaway iOSTests/TrainingProfileIntegrationTests.swift`

**Interfaces:**
- Consumes: `ActivityMixEditor`, `TrainingScheduleEditor`, and `TrainingProfileStore`.
- Produces: onboarding state that saves exactly one validated `TrainingProfile`.
- Produces: dismissible existing-user personalization prompt.

- [ ] **Step 1: Write failing onboarding conversion and prompt tests**

```swift
@Test("Onboarding and settings create the same profile shape")
func sharedProfileShape() throws {
    let answers = OnboardingAnswers.runningAndStrengthFixture
    let onboardingProfile = try OnboardingService.makeTrainingProfile(from: answers)
    #expect(onboardingProfile == TrainingProfile.runningAndStrengthFixture)
}

@Test("Personalization prompt can be dismissed without changing profile")
@MainActor
func dismissPrompt() {
    let store = TrainingProfileStore.testStore(needsPersonalization: true)
    let original = store.profile
    store.dismissPersonalizationPrompt()
    #expect(!store.needsPersonalization)
    #expect(store.profile == original)
}
```

- [ ] **Step 2: Run integration tests and confirm missing conversion/prompt APIs**

- [ ] **Step 3: Add onboarding activity and schedule state**

Running is preselected as primary for race and running-goal paths. Activity choices and conditional strength details use the shared components rather than duplicate controls. Continue is disabled only when validation cannot produce one primary activity.

- [ ] **Step 4: Insert two focused onboarding steps**

Step one is titled `How do you want to train?`; step two collects schedule constraints. Show a plain-language summary before leaving the second step. Saving completes before initial local plan generation so the first plan uses the profile.

- [ ] **Step 5: Add the existing-user personalization prompt**

Show one dismissible card on Today when `needsPersonalization` is true, plus a persistent status entry in Training Preferences. The card routes to `TrainingProfileView`. Dismissal writes only the prompt flag and leaves the migrated profile and plan untouched.

- [ ] **Step 6: Run onboarding and profile integration suites**

Expected: shared profile conversion, dismissal, initial plan generation, and existing-user migration pass.

---

### Task 8: Full Regression, UI Flow, and Archive Readiness

**Files:**
- Modify only files implicated by failures from Tasks 1 through 7.

**Interfaces:**
- Verifies all prior interfaces without introducing new feature scope.

- [ ] **Step 1: Run all focused profile and recommendation tests**

```bash
xcodebuild test -project "Runaway iOS.xcodeproj" -scheme "Runaway iOS" -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -only-testing:'Runaway iOSTests/TrainingProfileTests' -only-testing:'Runaway iOSTests/ComplementarySchedulingPolicyTests' -only-testing:'Runaway iOSTests/TrainingProfileIntegrationTests' -only-testing:'Runaway iOSTests/TodayRecommendationPolicyTests'
```

Expected: all selected suites pass with zero failures.

- [ ] **Step 2: Run the complete iOS test target**

```bash
xcodebuild test -project "Runaway iOS.xcodeproj" -scheme "Runaway iOS" -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0'
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 3: Smoke-test the user flows in the iOS 27 simulator**

Verify:

- New onboarding supports running plus strength and generates both safely.
- Settings can add cycling or swimming and choose next-week regeneration.
- Current-week rebalance preserves completed workouts.
- Today can recommend upper-body strength after a long run and explains why.
- Low readiness offers recovery-compatible selected activities.
- Running mileage and run count remain unchanged by non-running workouts.
- Existing users can dismiss personalization without losing their plan.
- All activity, save, cancel, retry, and regeneration controls navigate correctly.

- [ ] **Step 4: Perform the visual checks on representative screens**

Capture Today, Fitness Profile, onboarding activity mix, and Plan screens. Confirm hierarchy survives the squint test, supporting activity color is not amber-heavy, surface depth matches existing screens, dynamic type does not truncate controls, and selected/unselected/error/loading states are distinguishable.

- [ ] **Step 5: Build an archive configuration without uploading**

```bash
xcodebuild archive -project "Runaway iOS.xcodeproj" -scheme "Runaway iOS" -configuration Release -destination 'generic/platform=iOS' -archivePath /tmp/Runaway-TrainingProfile.xcarchive
```

Expected: `** ARCHIVE SUCCEEDED **`. Upload remains a separate user-approved action.

## Completion Checklist

- [ ] Profile persistence is versioned and safely migrated.
- [ ] Workout semantics are explicit and backward-compatible.
- [ ] Scheduling hard constraints and deterministic ranking are tested.
- [ ] Weekly generation and Today use the same policy.
- [ ] Running mileage and counts exclude non-running activity.
- [ ] Settings and onboarding share controls and model conversion.
- [ ] Existing users can personalize or dismiss without disruption.
- [ ] No external LLM or backend dependency was added.
- [ ] Focused tests, full tests, smoke flow, visual review, and archive build pass.
