# Codebase Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove dead code, eliminate duplication, improve performance, and establish a maintenance system across the Runaway iOS codebase.

**Architecture:** 11 sequenced cleanup tasks across 3 days — Day 1 deletes and guards (zero risk), Day 2 consolidates duplicate logic, Day 3 refactors large structures. Each task commits independently so work is always in a releasable state.

**Tech Stack:** Swift 5.9, SwiftUI, Supabase SDK, WidgetKit, SwiftData (Persistence layer)

**Spec:** `docs/superpowers/specs/2026-05-01-codebase-cleanup-design.md`

---

## File Map

### Files to Delete
- `Runaway iOS/Services/ContentScraper.swift` — unused web scraper
- `Runaway iOS/Services/ResearchService.swift` — unused article fetcher
- `Runaway iOS/Utils/APIRequestManager.swift` — unused request deduplicator
- `Runaway iOS/Utils/SupabaseDecoder.swift` — redundant custom decoder

### Files to Modify
- `Runaway iOS/Services/ChatService.swift` — remove 3 stub methods with TODO comments
- `Runaway iOS/Services/ActivityService.swift` — consolidate 4 fetch methods into 2
- `Runaway iOS/Services/WidgetSyncService.swift` — absorb WidgetRefreshService methods
- `Runaway iOS/Services/WidgetRefreshService.swift` — delete after merging
- `Runaway iOS/Views/TrainingView.swift` — VStack → LazyVStack
- `Runaway iOS/Views/ActivitiesView.swift` — fix filteredActivities recomputation
- `Runaway iOS/Utils/Theme.swift` — add adaptive color helpers
- All call sites of deleted ActivityService methods
- All 72 files with unguarded `print()` calls

### Files to Create
- `Runaway iOS/Components/ReadinessComponents.swift`
- `Runaway iOS/Components/WorkoutComponents.swift`
- `Runaway iOS/Components/StatsComponents.swift`
- `Runaway iOS/Components/DiscoveryComponents.swift`
- `docs/CLEANUP.md` — living backlog

### Files to Refactor
- `Runaway iOS/Components/StreamlinedTrainingComponents.swift` — split into 4 files above, then delete
- `Runaway iOS/Components/ActivityCommitmentCard.swift` — extract shared VM
- `Runaway iOS/Components/CompactCommitmentCard.swift` — use shared VM
- `Runaway iOS/Components/MicroCommitmentCard.swift` — use shared VM

---

## DAY 1 — DELETE & GUARD

---

### Task 1: Delete dead files

**Files:**
- Delete: `Runaway iOS/Services/ContentScraper.swift`
- Delete: `Runaway iOS/Services/ResearchService.swift`
- Delete: `Runaway iOS/Utils/APIRequestManager.swift`
- Delete: `Runaway iOS/Utils/SupabaseDecoder.swift`

- [ ] **Step 1: Verify ContentScraper has no callers**

```bash
grep -r "ContentScraper" "Runaway iOS/" --include="*.swift"
```

Expected: zero results (or only the file itself). If any caller appears, investigate before deleting.

- [ ] **Step 2: Verify ResearchService has no callers**

```bash
grep -r "ResearchService" "Runaway iOS/" --include="*.swift"
```

Expected: zero results.

- [ ] **Step 3: Verify APIRequestManager has no callers**

```bash
grep -r "APIRequestManager" "Runaway iOS/" --include="*.swift"
```

Expected: zero results.

- [ ] **Step 4: Verify SupabaseDecoder has no callers**

```bash
grep -r "SupabaseDecoder" "Runaway iOS/" --include="*.swift"
```

Expected: zero results.

- [ ] **Step 5: Delete the files**

In Xcode: select each file → Delete → Move to Trash. Do NOT use "Remove Reference Only."

Or from terminal:
```bash
cd "Runaway iOS"
rm "Runaway iOS/Services/ContentScraper.swift"
rm "Runaway iOS/Services/ResearchService.swift"
rm "Runaway iOS/Utils/APIRequestManager.swift"
rm "Runaway iOS/Utils/SupabaseDecoder.swift"
```

Then remove from Xcode project: in Project Navigator, any red (missing) file entries should be deleted.

- [ ] **Step 6: Build and confirm clean**

```bash
xcodebuild -project "Runaway iOS.xcodeproj" -scheme "Runaway iOS" \
  -destination "platform=iOS Simulator,name=iPhone 15" build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "Delete 4 dead files: ContentScraper, ResearchService, APIRequestManager, SupabaseDecoder"
```

---

### Task 2: Wrap all print() calls in #if DEBUG

**Files:** 72+ Swift files containing unguarded `print()`, `debugPrint()`, or `dump()` calls

- [ ] **Step 1: Find all affected files**

```bash
grep -rl "^\s*print(" "Runaway iOS/" --include="*.swift" | sort
```

Save this list — you'll work through it.

- [ ] **Step 2: Find all debugPrint and dump calls too**

```bash
grep -rl "^\s*debugPrint\|^\s*dump(" "Runaway iOS/" --include="*.swift"
```

- [ ] **Step 3: Wrap each print in #if DEBUG**

The pattern for every unguarded print:

```swift
// BEFORE
print("❌ CommitmentManager: Failed: \(error)")

// AFTER
#if DEBUG
print("❌ CommitmentManager: Failed: \(error)")
#endif
```

For consecutive prints in the same block, wrap the whole group in one `#if DEBUG`:

```swift
// BEFORE
print("🔍 Checking commitment")
print("📊 Found \(count) activities")

// AFTER
#if DEBUG
print("🔍 Checking commitment")
print("📊 Found \(count) activities")
#endif
```

Use Xcode's Find Navigator (⌘⇧F) with "In Project" scope to work through each file. Check each print before wrapping — if it's already inside `#if DEBUG`, skip it.

- [ ] **Step 4: Verify no unguarded prints remain**

```bash
# This looks for print( NOT preceded by #if DEBUG on prior lines
# Manual check is more reliable — grep and eyeball each result
grep -rn "^\s*print(" "Runaway iOS/" --include="*.swift" | grep -v "^Binary"
```

Any result that appears should be inside a `#if DEBUG` block. If uncertain, open the file and check context.

- [ ] **Step 5: Build and confirm clean**

```bash
xcodebuild -project "Runaway iOS.xcodeproj" -scheme "Runaway iOS" \
  -destination "platform=iOS Simulator,name=iPhone 15" build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "Wrap all print() calls in #if DEBUG guards"
```

---

### Task 3: Resolve ChatService TODOs

**Files:**
- Modify: `Runaway iOS/Services/ChatService.swift`

Three stub methods at lines ~136–162 have TODO comments and return empty data. If nothing calls them, delete them. If something calls them, remove the TODO comments (the stubs are fine).

- [ ] **Step 1: Check callers of each stub**

```bash
grep -rn "getConversation\|listConversations\|deleteConversation" "Runaway iOS/" --include="*.swift"
```

- [ ] **Step 2a: If NO callers found — delete all three methods**

Remove from `ChatService.swift`:
```swift
// DELETE these three methods entirely:
static func getConversation(id: String) async throws -> Conversation { ... }
static func listConversations(limit: Int = 10) async throws -> [ConversationSummary] { ... }
static func deleteConversation(id: String) async throws { ... }
```

- [ ] **Step 2b: If callers ARE found — remove the TODO comments only**

```swift
// BEFORE
static func getConversation(id: String) async throws -> Conversation {
    // TODO: Implement conversation storage in new backend
    // For now, return empty conversation
    let now = ISO8601DateFormatter().string(from: Date())
    return Conversation(id: id, userId: "", messages: [], context: nil,
                        createdAt: now, updatedAt: now)
}

// AFTER
static func getConversation(id: String) async throws -> Conversation {
    let now = ISO8601DateFormatter().string(from: Date())
    return Conversation(id: id, userId: "", messages: [], context: nil,
                        createdAt: now, updatedAt: now)
}
```

Apply same pattern to `listConversations` and `deleteConversation`.

- [ ] **Step 3: Build and confirm clean**

```bash
xcodebuild -project "Runaway iOS.xcodeproj" -scheme "Runaway iOS" \
  -destination "platform=iOS Simulator,name=iPhone 15" build 2>&1 | tail -5
```

- [ ] **Step 4: Commit**

```bash
git add "Runaway iOS/Services/ChatService.swift"
git commit -m "Resolve ChatService TODOs: delete or clean stub conversation methods"
```

---

## DAY 2 — CONSOLIDATE

---

### Task 4: Merge ActivityService fetch methods

**Files:**
- Modify: `Runaway iOS/Services/ActivityService.swift`
- Modify: call sites in `RestDayService.swift`, `RealtimeService.swift`, `ReadinessService.swift`, `AwardsService.swift`

`ActivityService` has 4 fetch methods. Consolidate to 2: one for paginated/limited fetches, one for complete batched fetch.

- [ ] **Step 1: Read the current signatures**

Open `ActivityService.swift` and note the exact signatures of:
- `getAllActivities()`
- `getAllActivitiesByUser(userId:limit:offset:)`
- `getActivitiesPaginated(userId:page:pageSize:)` — returns `PaginatedResponse<Activity>`
- `getAllActivitiesByUserComplete(userId:)` — batches until empty

- [ ] **Step 2: Find all call sites**

```bash
grep -rn "getAllActivities\|getActivitiesPaginated\|getAllActivitiesByUserComplete" \
  "Runaway iOS/" --include="*.swift"
```

- [ ] **Step 3: Consolidate getAllActivities into getAllActivitiesByUser**

`getAllActivities()` (no user filter) can be replaced with `getAllActivitiesByUser` where the caller passes their userId. Check each call site from Step 2 — update it to pass userId explicitly.

- [ ] **Step 4: Delete getAllActivities()**

Remove the method from `ActivityService.swift`. Build to confirm all callers updated.

- [ ] **Step 5: Evaluate getActivitiesPaginated**

This method returns `PaginatedResponse<Activity>` (includes `hasMore` flag), which is a different return type from `getAllActivitiesByUser`. Check if any UI uses the `hasMore` flag:

```bash
grep -rn "getActivitiesPaginated\|\.hasMore" "Runaway iOS/" --include="*.swift"
```

If `hasMore` is unused, consolidate into `getAllActivitiesByUser` with an `offset` parameter. If `hasMore` is actively used in pagination UI, keep `getActivitiesPaginated` and only remove the redundant others.

- [ ] **Step 6: Build and confirm clean**

```bash
xcodebuild -project "Runaway iOS.xcodeproj" -scheme "Runaway iOS" \
  -destination "platform=iOS Simulator,name=iPhone 15" build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "Consolidate ActivityService fetch methods, remove getAllActivities()"
```

---

### Task 5: Extract theme color helpers

**Files:**
- Modify: `Runaway iOS/Utils/Theme.swift`
- Modify: views using inline `themeManager.isDarkMode ? ... : ...` ternaries

Views currently resolve theme-aware colors inline. Move this to `AppTheme` so views reference a token, not a ternary.

- [ ] **Step 1: Find all inline theme ternaries in views**

```bash
grep -rn "isDarkMode ?" "Runaway iOS/Views/" --include="*.swift"
grep -rn "isDarkMode ?" "Runaway iOS/Components/" --include="*.swift"
```

List all the color pairs that appear (e.g., `DarkMode.cardBackground` vs `LightMode.cardBackground`).

- [ ] **Step 2: Add adaptive helpers to Theme.swift**

At the bottom of `Theme.swift`, add an extension with `@Environment`-free static helpers using SwiftUI's native adaptive approach. Add to the `AppTheme` struct or a new `AppTheme.AdaptiveColors` namespace:

```swift
extension AppTheme.Colors {
    // Use these in views instead of isDarkMode ternaries.
    // These automatically adapt to the current color scheme.
    static var adaptiveCardBackground: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(AppTheme.Colors.DarkMode.cardBackground)
                : UIColor(AppTheme.Colors.LightMode.cardBackground)
        })
    }

    static var adaptiveSurfaceBackground: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(AppTheme.Colors.DarkMode.surfaceBackground)
                : UIColor(AppTheme.Colors.LightMode.surfaceBackground)
        })
    }

    static var adaptivePrimaryText: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(AppTheme.Colors.DarkMode.primaryText)
                : UIColor(AppTheme.Colors.LightMode.primaryText)
        })
    }
}
```

Add one helper per color pair you found in Step 1. Name them `adaptive<TokenName>`.

- [ ] **Step 3: Replace ternaries in views**

For each view from Step 1, replace:
```swift
// BEFORE
themeManager.isDarkMode
    ? AppTheme.Colors.DarkMode.cardBackground
    : AppTheme.Colors.LightMode.cardBackground

// AFTER
AppTheme.Colors.adaptiveCardBackground
```

- [ ] **Step 4: Build and confirm clean**

```bash
xcodebuild -project "Runaway iOS.xcodeproj" -scheme "Runaway iOS" \
  -destination "platform=iOS Simulator,name=iPhone 15" build 2>&1 | tail -5
```

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Extract adaptive theme color helpers, remove inline isDarkMode ternaries"
```

---

### Task 6: Consolidate widget sync services

**Files:**
- Modify: `Runaway iOS/Services/WidgetSyncService.swift`
- Delete: `Runaway iOS/Services/WidgetRefreshService.swift`
- Modify: `Runaway iOS/Services/ActivityService.swift` (call site)
- Modify: any other files calling `WidgetRefreshService`

`WidgetRefreshService` (79 lines) is a thin dispatcher with 5 trigger methods that all call through to `WidgetSyncService`. Move those methods directly onto `WidgetSyncService` and delete the intermediary.

- [ ] **Step 1: Find all WidgetRefreshService call sites**

```bash
grep -rn "WidgetRefreshService" "Runaway iOS/" --include="*.swift"
```

- [ ] **Step 2: Read WidgetRefreshService.swift**

Open the file and note all 5 public methods and what each one does (which `WidgetSyncService` method or `WidgetCenter` call they trigger).

- [ ] **Step 3: Add convenience methods to WidgetSyncService**

For each method in `WidgetRefreshService`, add a matching static or instance method to `WidgetSyncService`. Example pattern:

```swift
// In WidgetSyncService.swift — add these to the existing class:

func refreshForActivityUpdate() {
    scheduleUpdate()  // or whatever WidgetRefreshService.refreshForActivityUpdate() called
}

func refreshForGoalUpdate() {
    scheduleUpdate()
}

func refreshForUserUpdate() {
    scheduleUpdate()
}

func refreshForAuthUpdate() {
    scheduleUpdate()
}

func refreshForLocationUpdate() {
    scheduleUpdate()
}
```

Match the exact method names from `WidgetRefreshService` so call sites compile with a one-word change.

- [ ] **Step 4: Update all call sites**

For each file from Step 1, replace `WidgetRefreshService.shared.refreshFor*()` with `WidgetSyncService.shared.refreshFor*()`.

- [ ] **Step 5: Audit DataManager for direct widget calls**

```bash
grep -n "WidgetCenter\|reloadAllTimelines\|WidgetRefresh" \
  "Runaway iOS/Managers/DataManager.swift"
```

If DataManager calls `WidgetCenter.shared.reloadAllTimelines()` or similar directly, replace those with `WidgetSyncService.shared.scheduleUpdate()` (or whichever method is appropriate). Only `WidgetSyncService` should touch widget state.

- [ ] **Step 6: Delete WidgetRefreshService.swift**

```bash
rm "Runaway iOS/Services/WidgetRefreshService.swift"
```

Remove the red entry from Xcode project navigator.

- [ ] **Step 7: Build and confirm clean**

```bash
xcodebuild -project "Runaway iOS.xcodeproj" -scheme "Runaway iOS" \
  -destination "platform=iOS Simulator,name=iPhone 15" build 2>&1 | tail -5
```

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "Consolidate WidgetRefreshService into WidgetSyncService, delete intermediary"
```

---

### Task 7: LazyVStack in TrainingView

**Files:**
- Modify: `Runaway iOS/Views/TrainingView.swift`

- [ ] **Step 1: Find the ScrollView/VStack pair in TrainingView**

```bash
grep -n "VStack\|ScrollView" "Runaway iOS/Views/TrainingView.swift"
```

- [ ] **Step 2: Replace VStack with LazyVStack**

```swift
// BEFORE
ScrollView {
    VStack(spacing: 16) {
        // cards
    }
    .padding(...)
}

// AFTER
ScrollView {
    LazyVStack(spacing: 16) {
        // cards
    }
    .padding(...)
}
```

If there are multiple VStacks inside the ScrollView, only replace the outermost one. Inner VStacks (e.g., inside a card) should stay as VStack.

- [ ] **Step 3: Build and confirm clean**

```bash
xcodebuild -project "Runaway iOS.xcodeproj" -scheme "Runaway iOS" \
  -destination "platform=iOS Simulator,name=iPhone 15" build 2>&1 | tail -5
```

- [ ] **Step 4: Commit**

```bash
git add "Runaway iOS/Views/TrainingView.swift"
git commit -m "Use LazyVStack in TrainingView to defer off-screen card rendering"
```

---

### Task 8: Fix filteredActivities recomputation in ActivitiesView

**Files:**
- Modify: `Runaway iOS/Views/ActivitiesView.swift`

The `filteredActivities` computed property currently re-filters on every render. Convert it to `@State` updated only when inputs change.

- [ ] **Step 1: Read the current filteredActivities implementation**

Open `ActivitiesView.swift` and find the `var filteredActivities` computed property. Note:
- What inputs it reads (filter type? search text? dataManager.activities?)
- What filtering logic it applies

- [ ] **Step 2: Replace computed property with @State + onChange**

```swift
// BEFORE (computed property — runs every render):
private var filteredActivities: [Activity] {
    guard selectedFilter != .all else { return dataManager.activities }
    return dataManager.activities.filter { $0.type?.lowercased() == selectedFilter.rawValue }
}

// AFTER (@State — only updates when inputs change):
@State private var filteredActivities: [Activity] = []

// Add this wherever the view initializes (e.g., .task or .onAppear):
.task {
    filteredActivities = applyFilter(to: dataManager.activities)
}
.onChange(of: selectedFilter) { _, _ in
    filteredActivities = applyFilter(to: dataManager.activities)
}
.onChange(of: dataManager.activities) { _, _ in
    filteredActivities = applyFilter(to: dataManager.activities)
}
```

Extract the filter logic into a private function:
```swift
private func applyFilter(to activities: [Activity]) -> [Activity] {
    guard selectedFilter != .all else { return activities }
    return activities.filter { $0.type?.lowercased() == selectedFilter.rawValue }
}
```

Adjust property names (`selectedFilter`, `.all`, `.rawValue`) to match the actual ActivitiesView code.

- [ ] **Step 3: Build and confirm clean**

```bash
xcodebuild -project "Runaway iOS.xcodeproj" -scheme "Runaway iOS" \
  -destination "platform=iOS Simulator,name=iPhone 15" build 2>&1 | tail -5
```

- [ ] **Step 4: Commit**

```bash
git add "Runaway iOS/Views/ActivitiesView.swift"
git commit -m "Fix filteredActivities: compute only on filter/data change, not every render"
```

---

## DAY 3 — REFACTOR

---

### Task 9: Consolidate commitment cards

**Files:**
- Create: `Runaway iOS/Components/CommitmentCardViewModel.swift`
- Modify: `Runaway iOS/Components/ActivityCommitmentCard.swift`
- Modify: `Runaway iOS/Components/CompactCommitmentCard.swift`
- Modify: `Runaway iOS/Components/MicroCommitmentCard.swift`

Three card components share ~70% logic. Extract the shared state and Supabase interaction into a ViewModel.

- [ ] **Step 1: Read all three card files**

Open and read:
- `ActivityCommitmentCard.swift` (736 lines)
- `CompactCommitmentCard.swift` (824 lines)
- `MicroCommitmentCard.swift` (305 lines)

List the state variables and functions that appear in 2 or more of them. These are the candidates for extraction.

- [ ] **Step 2: Create CommitmentCardViewModel.swift**

```swift
// Runaway iOS/Components/CommitmentCardViewModel.swift
import Foundation
import Observation

@MainActor
@Observable
final class CommitmentCardViewModel {
    private(set) var isLoading = false
    private(set) var error: Error?

    var commitment: DailyCommitment? {
        CommitmentManager.shared.todaysCommitment
    }

    func createCommitment(_ type: CommitmentActivityType) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await CommitmentManager.shared.createCommitment(type)
        } catch {
            self.error = error
        }
    }

    func deleteCommitment() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await CommitmentManager.shared.deleteCommitment()
        } catch {
            self.error = error
        }
    }
}
```

Add additional methods for any shared logic you found in Step 1.

- [ ] **Step 3: Refactor ActivityCommitmentCard to use the ViewModel**

```swift
struct ActivityCommitmentCard: View {
    @State private var viewModel = CommitmentCardViewModel()

    var body: some View {
        // Replace inline state management with viewModel.commitment,
        // viewModel.isLoading, viewModel.createCommitment(), etc.
        // Keep only the UI layout code here.
    }
}
```

Remove duplicated state variables and Supabase calls. Delegate to `viewModel`.

- [ ] **Step 4: Refactor CompactCommitmentCard the same way**

Same pattern as Step 3. `@State private var viewModel = CommitmentCardViewModel()`.

- [ ] **Step 5: Refactor MicroCommitmentCard the same way**

Same pattern. If MicroCommitmentCard needs different behavior (e.g., micro-commitment specific actions), add a method to the ViewModel for it.

- [ ] **Step 6: Build and confirm clean**

```bash
xcodebuild -project "Runaway iOS.xcodeproj" -scheme "Runaway iOS" \
  -destination "platform=iOS Simulator,name=iPhone 15" build 2>&1 | tail -5
```

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "Extract CommitmentCardViewModel, remove duplicated logic from 3 commitment cards"
```

---

### Task 10: Split StreamlinedTrainingComponents.swift

**Files:**
- Create: `Runaway iOS/Components/ReadinessComponents.swift`
- Create: `Runaway iOS/Components/WorkoutComponents.swift`
- Create: `Runaway iOS/Components/StatsComponents.swift`
- Create: `Runaway iOS/Components/DiscoveryComponents.swift`
- Delete: `Runaway iOS/Components/StreamlinedTrainingComponents.swift`

1,370-line file with 14 components. Split by responsibility.

**Component assignment:**
| Component | Target file |
|-----------|-------------|
| `ReadinessBanner` | `ReadinessComponents.swift` |
| `ReadinessCalculationSheet` | `ReadinessComponents.swift` |
| `TodaysFocusCard` | `WorkoutComponents.swift` |
| `WeekProgressRow` | `WorkoutComponents.swift` |
| `WeekDayActivityTile` | `WorkoutComponents.swift` |
| `KeyMetricsGrid` | `StatsComponents.swift` |
| `KeyMetricTile` | `StatsComponents.swift` |
| `ThisWeekActivitiesSection` | `StatsComponents.swift` |
| `CompactActivityRow` | `StatsComponents.swift` |
| `CompactTrendsChart` | `StatsComponents.swift` |
| `MiniWeeklyChart` | `StatsComponents.swift` |
| `CoachInsightCard` | `DiscoveryComponents.swift` |
| `ExploreSection` | `DiscoveryComponents.swift` |
| `ExplorePill` | `DiscoveryComponents.swift` |

- [ ] **Step 1: Create ReadinessComponents.swift**

Create the file with the standard header:
```swift
import SwiftUI

// MARK: - Readiness UI Components
```

Cut `ReadinessBanner` (line 13) and `ReadinessCalculationSheet` (line 134) from `StreamlinedTrainingComponents.swift` and paste into the new file. Include any private helpers used only by these components.

- [ ] **Step 2: Create WorkoutComponents.swift**

```swift
import SwiftUI

// MARK: - Workout UI Components
```

Cut `TodaysFocusCard` (line 214), `WeekProgressRow` (line 485), `WeekDayActivityTile` (line 674) and paste.

- [ ] **Step 3: Create StatsComponents.swift**

```swift
import SwiftUI

// MARK: - Stats UI Components
```

Cut `KeyMetricsGrid` (line 892), `KeyMetricTile` (line 1024), `ThisWeekActivitiesSection` (line 1063), `CompactActivityRow` (line 1123), `CompactTrendsChart` (line 1202), `MiniWeeklyChart` (line 1238) and paste.

- [ ] **Step 4: Create DiscoveryComponents.swift**

```swift
import SwiftUI

// MARK: - Discovery UI Components
```

Cut `CoachInsightCard` (line 836), `ExploreSection` (line 1287), `ExplorePill` (line 1323) and paste.

- [ ] **Step 5: Add new files to Xcode project**

In Xcode Project Navigator: right-click `Components` group → Add Files → select the 4 new files. Ensure target membership is `Runaway iOS`.

- [ ] **Step 6: Build and fix any issues**

```bash
xcodebuild -project "Runaway iOS.xcodeproj" -scheme "Runaway iOS" \
  -destination "platform=iOS Simulator,name=iPhone 15" build 2>&1 | grep -E "error:|warning:" | head -20
```

Common issues: private helpers referenced across files (make them internal), missing imports. Fix each error before continuing.

- [ ] **Step 7: Delete StreamlinedTrainingComponents.swift**

Once build is clean:
```bash
rm "Runaway iOS/Components/StreamlinedTrainingComponents.swift"
```

Remove from Xcode project navigator. Build again to confirm still clean.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "Split StreamlinedTrainingComponents into 4 focused component files"
```

---

### Task 11: Audit and document model naming

**Files:**
- Read: `Runaway iOS/Models/ActivityModels.swift`
- Read: `Runaway iOS/Persistence/Models/SDAthlete.swift`
- Read: `Runaway iOS/Persistence/Models/SDActivity.swift`
- Possibly modify: `Runaway iOS/Models/ActivityModels.swift`

> **Important caveat before starting:** The `SD` prefix (SDAthlete, SDActivity, SDDailyCommitment) is the SwiftData convention in this codebase — these are persistence layer models, intentionally distinct from the Supabase API models. Do NOT rename `SDAthlete` → `Athlete` or `SDActivity` → `Activity`; that would cause namespace conflicts with the existing API types.

The real confusion is `LocalActivity` vs `Activity`. This task audits what `LocalActivity` actually is and normalizes it if safe.

- [ ] **Step 1: Map the model layers**

Read these files and determine what each type represents:
```bash
grep -n "^struct\|^class\|^typealias" "Runaway iOS/Models/ActivityModels.swift"
grep -n "^struct\|^class\|^typealias" "Runaway iOS/Persistence/Models/SDActivity.swift"
grep -n "^struct\|^class\|^typealias" "Runaway iOS/Persistence/Models/SDAthlete.swift"
```

Draw a mental map:
- `Activity` = Supabase API model (network layer)
- `LocalActivity` = ??? (read ActivityModels.swift to determine)
- `SDActivity` = SwiftData persistence model (local DB layer)
- `SDAthlete` = SwiftData persistence model (local DB layer)

- [ ] **Step 2: Determine if LocalActivity is redundant**

Read `ActivityModels.swift` in full. If `LocalActivity` is:

**A) A typealias or thin wrapper for `Activity`** — it's redundant. Continue to Step 3 to remove it.

**B) A ViewModel/DTO with display-specific computed properties** — it serves a purpose. Document it with a comment at the top of the struct, commit, and stop here.

**C) The same as `SDActivity`** — there's a mapping layer doing unnecessary work. Document both and add to `docs/CLEANUP.md` as a larger refactor item.

- [ ] **Step 3: If LocalActivity is a typealias — remove it**

```bash
grep -rn "LocalActivity" "Runaway iOS/" --include="*.swift"
```

For each call site, replace `LocalActivity` with `Activity`. Then delete the typealias from `ActivityModels.swift`.

- [ ] **Step 4: If LocalActivity is a DTO — add a clear docstring**

```swift
/// Display model for activity data. Distinct from `Activity` (the Supabase API model)
/// and `SDActivity` (the SwiftData persistence model).
/// Use this type when building view-specific representations of activity data.
struct LocalActivity {
    // ...existing fields...
}
```

- [ ] **Step 5: Add naming convention documentation to ActivityModels.swift**

At the top of the file, add:
```swift
// MARK: - Model Layer Conventions
//
// This codebase uses three distinct model layers:
//   Activity      — Supabase API model. Decodable from PostgREST JSON.
//   LocalActivity — View/display model. Built from Activity for UI consumption.
//   SDActivity    — SwiftData persistence model. SD prefix = SwiftData convention.
//
// Do not conflate these types. Each layer has a distinct purpose.
```

- [ ] **Step 6: Build and confirm clean**

```bash
xcodebuild -project "Runaway iOS.xcodeproj" -scheme "Runaway iOS" \
  -destination "platform=iOS Simulator,name=iPhone 15" build 2>&1 | tail -5
```

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "Document model naming conventions, clarify LocalActivity vs Activity vs SDActivity"
```

---

## Final: Create CLEANUP.md backlog

**Files:**
- Create: `docs/CLEANUP.md`

- [ ] **Step 1: Create the backlog file**

```bash
cat > "docs/CLEANUP.md" << 'EOF'
# Cleanup Backlog

Issues identified in the May 2026 audit that didn't make the weekend sprint.
Pull from this list at the start of each feature sprint.

## High Priority

- [ ] Singleton DI refactor — 11 singletons with no coordination; introduce a service locator or environment-based injection. High blast radius, separate initiative.
- [ ] N+1 fix in HybridActivityRepository.fullSync() — currently issues individual create/update calls in a loop; needs batch upsert.
- [ ] Consolidate RestDayService + ReadinessService + AdaptiveTrainingAlgorithm recovery logic into a single RecoveryAnalyzer.
- [ ] AthleteService.getAthleteByUserId() and AthleteRepository.getAthlete() are duplicate queries — delete one.
- [ ] DataManager and ActivityStore both cache activities independently with no clear ownership — consolidate.

## Medium Priority

- [ ] SettingsView.swift (1391 lines) — split into ProfileSettingsView, IntegrationSettingsView, GoalSettingsView.
- [ ] PlanView.swift (1093 lines) — extract UpcomingRacesSection, TrainingPlanCard.
- [ ] AnalysisView.swift (1045 lines) — extract 8 nested view builders into separate components.
- [ ] AwardBadgeDesigns.swift (1091 lines) — split by badge state (unlocked/locked/progress).
- [ ] OnboardingStepViews.swift (967 lines) — one file per onboarding step.
- [ ] AwardsService.swift (604 lines) — split into AwardCalculator + MilestoneTracker.
- [ ] ActivityTypeDisc icon/color mapping duplicated in 3+ places — single source of truth.
- [ ] Widget sync: DataManager also triggers widget updates independently of WidgetSyncService — remove DataManager's direct widget calls.
- [ ] MainActor conflicts in HybridActivityRepository — background fetch modifying @MainActor state.
- [ ] Missing cache invalidation in TrainingPlanService — plan cached with no invalidation on goal change.
- [ ] Store binding callbacks (ActivityStore.onActivitiesChanged + DataManager.setupStoreBindings) may cause double-updates — audit and consolidate.

## Low Priority

- [ ] Sheet state in SettingsView — 4 @State booleans for sheet presentation, should be one enum SheetType.
- [ ] Unused imports — MapKit in ActivityDetailView, Charts in AthleteView.
- [ ] UserSession.shared accessed directly in ActivityStore and AthleteStore — should be injected.
- [ ] Calendar.current.isDate() called per-activity in list loops — cache the calendar call.
- [ ] Inconsistent model naming decision for LocalActivity — see Task 11 notes.
- [ ] Test coverage — near zero; start with Services that have pure input/output logic.
- [ ] Documentation gaps in SyncEngine.swift and HybridActivityRepository.

## Rules (established in May 2026 sprint)

- Files over 400 lines are candidates for splitting before new code is added.
- All print() calls must be wrapped in #if DEBUG at write time.
- When noticing a cleanup opportunity during feature work, add it here instead of fixing mid-task.
- Review this list at the start of each feature sprint.
EOF
```

- [ ] **Step 2: Commit**

```bash
git add docs/CLEANUP.md
git commit -m "Add CLEANUP.md with ongoing backlog from codebase audit"
```

- [ ] **Step 3: Push everything**

```bash
git push origin main
```

---

## Success Criteria

- [ ] `grep -r "ContentScraper\|ResearchService\|APIRequestManager\|SupabaseDecoder" Runaway\ iOS/ --include="*.swift"` → zero results
- [ ] `grep -rn "^\s*print(" Runaway\ iOS/ --include="*.swift"` → all results inside `#if DEBUG` blocks
- [ ] `find Runaway\ iOS/ -name "*.swift" | xargs wc -l | sort -rn | head -10` → no file over 1000 lines
- [ ] `xcodebuild ... build` → `** BUILD SUCCEEDED **`
- [ ] `docs/CLEANUP.md` exists with the backlog
