# Warning Fixes Plan

57 warnings across 6 categories. Ordered cheapest → most involved.

---

## Group 1 — Unused variables (14 warnings, ~5 min)

Mechanical: replace binding with `_` or convert to a boolean guard.

| File | Line | Fix |
|------|------|-----|
| `WeeklyTrainingPlan.swift` | 365 | `if activities.first(where: ...) != nil` — drop `let activity =` |
| `ReadinessService.swift` | 244 | Remove `let calendar = Calendar.current` (never used below) |
| `DataManager.swift` | 214 | Remove `let calendar = Calendar.current` |
| `DataManager.swift` | 269 | Remove `let calendar = Calendar.current` |
| `DataManager.swift` | 211 | `guard UserSession.shared.userId != nil else { return }` |
| `TrainingPlanService.swift` | 434 | Remove `let calendar = Calendar.current` |
| `HealthKitManager.swift` | 165 | `guard HKObjectType.quantityType(forIdentifier: .heartRate) != nil else { return false }` |
| `RealtimeService.swift` | 366 | Change destructuring to `let (_, needsReconnection, userId)` |
| `Router.swift` | 89 | `case .activityDetail(_):` |
| `Router.swift` | 116 | `case .journalEntry(_):` |
| `RunningAnalyzer.swift` | 317 | `if activities.last != nil` — drop `let lastActivity =` |
| `RunningAnalyzer.swift` | 369 | `let _ = ...avgDistance` or remove the calculation entirely |
| `RunningAnalyzer.swift` | 370 | Same for `avgPace` |
| `AnalysisView.swift` | 906 | Remove `let startOfMonth = ...` |
| `Runaway_iOSApp.swift` | 106 | `let _ = try await supabase.auth.session(from: url)` |
| `HealthKitWorkoutService.swift` | 119 | `let _ = routeBuilder` or remove the variable |

---

## Group 2 — Remove unnecessary `await` (3 warnings, ~2 min)

The called functions are synchronous; `await` is a no-op.

| File | Line | Fix |
|------|------|-----|
| `ReadinessComponents.swift` | 263 | Remove `await` keyword |
| `ReadinessService.swift` | 44 | Remove `await` keyword |
| `TrainingViewModel.swift` | 178 | Remove `await` keyword |

---

## Group 3 — Deprecated `onChange` (13 warnings, ~10 min)

iOS 17 requires a two-parameter closure. Pattern:

```swift
// Before
.onChange(of: foo) { newValue in ... }

// After
.onChange(of: foo) { _, newValue in ... }
```

Files: `CoachSettingsView.swift` (330, 335), `AthleteView.swift` (254, 374),
`AnalysisView.swift` (1023), `SignUpView.swift` (66, 86, 112),
`SettingsView.swift` (124), `ChatView.swift` (60),
`RunningGoalComponents.swift` (417), `ForgotPasswordView.swift` (84),
`OnboardingStepViews.swift` (296, 320), `AccountInformationView.swift` (72)

---

## Group 4 — Deprecated Supabase storage upload (3 warnings, ~5 min)

The `upload(path:file:options:)` signature was renamed.

```swift
// Before
.upload(path: fileName, file: imageData, options: ...)

// After
.upload(fileName, data: imageData, options: ...)
```

Files: `StorageService.swift` (42, 119), `SupabaseStorageService.swift` (37)

---

## Group 5 — Unreachable catch / always-succeeds cast (5 warnings, ~10 min)

### Unreachable catch blocks
`setupRealtimeSubscription` and the sync body never throw, so the catch is dead code.

- `RealtimeService.swift:66` — Remove the `do/catch` wrapper; keep the body
- `SyncEngine.swift:167` — Remove the `catch` block

### Always-fails casts in `ChatView.swift` (465–466)
`UIGestureRecognizer` can never be cast to `UIDragInteraction`/`UIDropInteraction`
(different class hierarchies). The intent is to disable drag/drop gesture recognizers
by class name. Replace direct `is` cast with string check that already exists:

```swift
// Remove these two lines (they always evaluate false):
if gesture is UIDragInteraction ||
   gesture is UIDropInteraction ||
// Keep only:
if String(describing: type(of: gesture)).contains("Drag") ||
   String(describing: type(of: gesture)).contains("Drop") {
```

### Always-succeeds cast in `HealthKitManager.swift` (72)
`HKSeriesType` is already a subtype of `HKObjectType`; `as?` always succeeds.

```swift
// Before
if let routeType = HKSeriesType.workoutRoute() as? HKObjectType {
// After
let routeType: HKObjectType = HKSeriesType.workoutRoute()
types.insert(routeType)
```

---

## Group 6 — Miscellaneous easy fixes (3 warnings, ~5 min)

### `TrainingPlanService.swift:61` — nil coalescing on non-optional
`workout.description` is already `String?`, `?? ""` on the outer expression is redundant because the string interpolation handles nil. Remove `?? ""`.

### `TrainingViewModel.swift:86–87` — `async let` inferred as `()`
`loadQuickWins()` and `loadCurrentJournal()` return `Void`. Using `async let` on `Void`-returning functions is valid for concurrency but triggers the warning. Rewrite:

```swift
// Before
async let quickWinsTask = loadQuickWins()
async let journalTask = loadCurrentJournal()
_ = await (quickWinsTask, journalTask)

// After — explicit concurrent execution, no inferred ()
await withTaskGroup(of: Void.self) { group in
    group.addTask { await self.loadQuickWins() }
    group.addTask { await self.loadCurrentJournal() }
}
```

### `CelebrationOverlay.swift:247` — non-Sendable closure in Sendable struct
Mark the stored closure `@Sendable`:

```swift
// Before
private let pathBuilder: (CGRect) -> Path

// After
private let pathBuilder: @Sendable (CGRect) -> Path
```

---

## Group 7 — Main actor isolation (Swift 6 readiness, ~30 min)

These are today's warnings, tomorrow's errors. Two sub-patterns:

### 7a — `shared` singleton accessed from nonisolated default parameter

When a `@MainActor`-isolated class exposes `static let shared`, referencing it in
a default parameter (e.g., `init(dataManager: DataManager = .shared)`) is nonisolated
and will be an error in Swift 6.

**Fix:** Mark each `shared` property `nonisolated(unsafe)`. This is correct for
singletons that are initialized at app start and never replaced:

```swift
// Before
static let shared = DataManager()

// After
nonisolated(unsafe) static let shared = DataManager()
```

Apply to: `DataManager`, `AdaptiveTrainingAlgorithm` (init default param),
`ChatViewModel` (init default param), `PlanViewModel` (init default param),
`ThemeManager` (EnvironmentKey default).

### 7b — Protocol conformance crosses into `@MainActor`

Classes annotated `@MainActor` that conform to non-`@MainActor` protocols generate
a data-race warning. Fix by adding `@MainActor` to the protocol declaration:

```swift
// Before
protocol AthleteStoreProtocol { ... }
protocol ActivityStoreProtocol { ... }
protocol CommitmentManagerProtocol { ... }
protocol GoalManagerProtocol { ... }
protocol RepositoryProvider { ... }

// After
@MainActor protocol AthleteStoreProtocol { ... }
// etc.
```

Files: `AthleteStore.swift` (protocol source TBD), `ActivityStore.swift`,
`CommitmentManager.swift`, `GoalManager.swift`, `RepositoryFactory.swift`

### 7c — `AppDelegate.swift:31` — mutating `pendingAPNsToken` from nonisolated Task

`pendingAPNsToken` is a stored property of `AppDelegate` (implicitly `@MainActor`
via `UIApplicationDelegate`). Mutation from a bare `Task {}` is nonisolated.

```swift
// Before
self?.pendingAPNsToken = nil

// After
await MainActor.run { self?.pendingAPNsToken = nil }
```

### 7d — `AccountInformationView.swift:93` — same pattern, different property

```swift
// Before (inside Task)
pendingAPNsToken = nil

// After
await MainActor.run { self.pendingAPNsToken = nil }
```

---

## Group 8 — Non-Sendable captures in `APIRequestManager` (3 warnings, ~10 min)

`APIRequestManager` is a class referenced from `@Sendable` `Task` closures but not
marked `Sendable`. The captures are safe (protected by `requestQueue` serial queue)
but Swift can't prove it.

**Option A (preferred):** Mark `@unchecked Sendable`:
```swift
final class APIRequestManager: @unchecked Sendable { ... }
```

**Option B:** Capture only the queue and dictionary directly to avoid capturing `self`.

---

## Execution order

1. Groups 1–4 in one pass (mechanical, low risk) → build, commit
2. Groups 5–6 (logic cleanup) → build, commit
3. Groups 7–8 (concurrency) → build, test, commit
