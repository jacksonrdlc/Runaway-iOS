# Runaway iOS — Codebase Cleanup Design

**Date:** 2026-05-01  
**Scope:** Weekend sprint (11 tasks) + ongoing maintenance system  
**Trigger:** Step back and clean house after many iterative additions and removals

---

## Audit Summary

Full audit surfaced 48 issues across 6 categories:

| Category | Count | High | Medium | Low |
|----------|-------|------|--------|-----|
| Dead code / unused files | 6 | 0 | 4 | 2 |
| Duplicate logic | 7 | 3 | 4 | 0 |
| Large files doing too much | 9 | 5 | 4 | 0 |
| Singleton / data flow sprawl | 6 | 2 | 4 | 0 |
| Performance red flags | 11 | 3 | 6 | 2 |
| Developer workflow gaps | 9 | 4 | 3 | 2 |
| **Total** | **48** | **17** | **23** | **8** |

---

## Weekend Sprint — 11 Tasks

Sequenced so each task makes the next easier. Day 1 is deletion and guarding (no risk), Day 2 is consolidation, Day 3 is refactoring.

### Day 1 — Delete & Guard

**Task 1: Delete 4 dead files**

Files confirmed as unreferenced:
- `Services/ContentScraper.swift`
- `Services/ResearchService.swift`
- `Utils/APIRequestManager.swift`
- `Utils/SupabaseDecoder.swift`

Grep for references before deleting. If any reference exists, investigate before removing.

**Task 2: Wrap all `print()` in `#if DEBUG`**

72 files contain unguarded `print()`, `debugPrint()`, or `dump()` calls. Script the fix:
```bash
# Find files with unguarded prints
grep -rl "^\s*print(" --include="*.swift" .
```
Wrap each call:
```swift
// Before
print("❌ CommitmentManager: Failed: \(error)")

// After
#if DEBUG
print("❌ CommitmentManager: Failed: \(error)")
#endif
```
Do not remove the prints — they're useful in development. Just guard them.

**Task 3: Resolve ChatService TODOs**

`ChatService.swift` lines 136, 151, 158 contain `// TODO: Implement conversation storage`. Either implement the stub or remove the dead code path. No half-finished features in committed code.

---

### Day 2 — Consolidate

**Task 4: Merge ActivityService fetch methods**

Three methods fetch nearly identical data with minor variation:
- `getAllActivities()`
- `getAllActivitiesByUser(userId:limit:)`
- `getActivitiesPaginated(userId:page:pageSize:)`

Consolidate into one method with optional parameters:
```swift
static func fetchActivities(
    userId: Int,
    limit: Int = 50,
    offset: Int = 0
) async throws -> [Activity]
```
Update all call sites. Delete the old methods.

**Task 5: Extract theme color helpers**

Theme-aware color resolution (`themeManager.isDarkMode ? AppTheme.Colors.DarkMode.x : AppTheme.Colors.LightMode.x`) is copy-pasted into 5+ views. Add computed properties to `AppTheme` or use SwiftUI's native adaptive color approach so views reference a single token. Remove the inline ternaries from view bodies.

**Task 6: Consolidate widget sync**

`WidgetSyncService` and `WidgetRefreshService` overlap in functionality. `DataManager` also triggers widget updates independently. Designate one owner (`WidgetSyncService`), move all widget-update logic there, and remove the duplicate. `DataManager` calls `WidgetSyncService.sync()` — nothing else touches widget state directly.

**Task 7: LazyVStack in TrainingView**

`TrainingView` uses `VStack` inside `ScrollView`, rendering all cards immediately on load. Replace with `LazyVStack` so off-screen cards render on demand:
```swift
// Before
ScrollView { VStack(spacing: 16) { ... } }

// After
ScrollView { LazyVStack(spacing: 16) { ... } }
```

**Task 8: Fix `filteredActivities` recomputation**

In `ActivitiesView`, `filteredActivities` is a computed property that re-filters the full activity list on every render. Move to `@State` and update only in `.onChange(of: filterType)` and `.onChange(of: dataManager.activities)`.

---

### Day 3 — Refactor

**Task 9: Consolidate commitment cards**

Three components share ~70% logic:
- `ActivityCommitmentCard.swift` (736 lines)
- `CompactCommitmentCard.swift` (824 lines)
- `MicroCommitmentCard.swift` (305 lines)

Extract shared state management and Supabase interaction into a `CommitmentCardViewModel`. Each card becomes a thin view that takes the view model and renders its variant. Target: each card file under 200 lines.

**Task 10: Split StreamlinedTrainingComponents.swift**

1,370-line file contains 15+ unrelated components. Split by responsibility:
- `ReadinessComponents.swift` — ReadinessBanner, ReadinessRing, ReadinessDetailView
- `WorkoutComponents.swift` — NextUpCard, TodaysFocusCard, WorkoutRow
- `StatsComponents.swift` — WeeklySummaryCard, LatestActivitySection
- `SharedComponents.swift` — EyebrowLabel, MiniStatTile, anything used by 2+ of the above

Delete `StreamlinedTrainingComponents.swift` once all components are moved.

**Task 11: Model naming normalization**

Current confusion: `Activity` vs `LocalActivity`, `Athlete` vs `SDAthlete`. Rule: the shorter, canonical name wins.

Canonical names:
- `Activity` (not `LocalActivity`)
- `Athlete` (not `SDAthlete`)

Steps:
1. Grep for all usages of the non-canonical names
2. Global rename via Xcode (right-click → Rename) to preserve all references
3. Delete type aliases and deprecated variants
4. Build and fix any remaining compilation errors

---

## Ongoing Maintenance System

### Living Backlog (`docs/CLEANUP.md`)

A committed file in the repo. When a cleanup opportunity is noticed during feature work, add it here instead of fixing it mid-task. Review at the start of each feature sprint and pull the top item into the next sprint.

Initial backlog (38 issues not addressed in the sprint) is seeded from the full audit.

### File Size Rule

Any file over 400 lines is a candidate for splitting before new code is added. Not a hard block — a forcing function to notice growth before it becomes a problem.

### `#if DEBUG` Discipline

Any new `print()` added during development is wrapped at write time. The Task 2 fix establishes the baseline; new code maintains it.

---

## Out of Scope

These were considered and deferred — not forgotten:

| Item | Reason deferred |
|------|----------------|
| Singleton DI refactor (11 singletons) | Too much blast radius for a cleanup sprint; deserves its own initiative |
| Test coverage | Starting from near-zero is a separate initiative |
| N+1 batch fix in HybridActivityRepository | Correctness fix, not cleanup; own focused session |
| AnalysisView / PlanView splits | Large but functional; defer until those screens get feature work |

All deferred items are in `docs/CLEANUP.md`.

---

## Success Criteria

- Zero unreferenced dead files (Tasks 1, 9, 10 deletions confirm)
- All `print()` calls wrapped in `#if DEBUG` (grep confirms 0 unguarded)
- No file over 1,000 lines (Tasks 9, 10 bring the outliers down)
- Single canonical model names compile cleanly (Task 11)
- `docs/CLEANUP.md` exists with the remaining 38 backlog items
