# Post-Run Reflection and Automatic Debrief Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a skippable, offline-first post-run reflection that saves locally, synchronizes safely to Supabase, and presents immediate local guidance followed by an enriched server debrief.

**Architecture:** Store subjective reflections in a dedicated SwiftData model and Supabase table instead of modifying provider-owned activities. Extend the existing durable sync queue with separate reflection-upload and debrief-generation operations. Authenticate all writes through user-scoped Edge Functions, enforce RLS as defense in depth, and render local and enriched guidance in one stable UI card.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, Swift Testing/XCTest, Supabase Swift 2.24.7, PostgreSQL/RLS, Supabase Edge Functions, Deno TypeScript.

**Spec:** `docs/superpowers/specs/2026-08-25-post-run-reflection-design.md`

## Global Constraints

- The activity must remain saved when reflection is skipped or synchronization fails.
- Reflection effort is an integer from 1 through 10.
- Notes are trimmed, limited to 1,000 characters, and never emitted to analytics or logs.
- Body state values are exactly `good`, `tight`, `sore`, and `pain`.
- Mood values are exactly `better`, `same`, and `lower`.
- Condition values are exactly `heat`, `hills`, `wind`, `poor_sleep`, and `stress`.
- Pain guidance is conservative and non-diagnostic.
- One reflection and one enriched debrief may exist per user and activity.
- Local persistence completes before any network request.
- Reflection upload and debrief generation retry independently.
- Edge Function user ownership uses the shared user-endpoint guard; client identifiers are never trusted for authorization.
- Every new public table has RLS, ownership policies, and indexes for policy columns.
- No production deployment occurs before local tests pass.
- Do not run git commands or create commits unless the user explicitly requests them.

---

## File Structure

### Runaway iOS

- Create `Runaway iOS/Models/WorkoutReflection.swift`: domain enums, validated reflection value, and activity summary.
- Create `Runaway iOS/Services/WorkoutDebriefPolicy.swift`: pure deterministic local guidance.
- Create `Runaway iOS/Persistence/Models/SDWorkoutReflection.swift`: SwiftData persistence entity.
- Create `Runaway iOS/Repositories/WorkoutReflectionRepository.swift`: local persistence protocol and implementation.
- Create `Runaway iOS/Services/WorkoutReflectionRemoteService.swift`: authenticated upload, delete, debrief request, and server-debrief fetch.
- Create `Runaway iOS/ViewModels/WorkoutReflectionViewModel.swift`: sheet/card state and save/edit orchestration.
- Create `Runaway iOS/Components/PostRunReflectionSheet.swift`: post-save input and local-debrief transition.
- Create `Runaway iOS/Components/WorkoutReflectionCard.swift`: activity-detail reflection display and editing entry point.
- Modify `Runaway iOS/Persistence/PersistenceController.swift`: register `SDWorkoutReflection` in the app schema.
- Modify `Runaway iOS/Persistence/Models/SyncTypes.swift`: add reflection and debrief sync entities.
- Modify `Runaway iOS/Persistence/Sync/SyncEngine.swift`: process reflection operations and preserve generated follow-up operations.
- Modify `Runaway iOS/Views/RunRecordingView.swift`: present the reflection after successful activity save.
- Modify `Runaway iOS/Views/ActivityDetailView.swift`: load, display, add, and edit a reflection.
- Modify `Runaway iOS/Services/ActivityInsightService.swift`: fetch the stable enriched debrief row deterministically.
- Create focused tests under `Runaway iOS/Runaway iOSTests` for each domain, repository, sync, and presentation policy boundary.

### runaway-edge

- Create `supabase/functions/workout-reflection/index.ts`: authenticated reflection upsert/delete handler.
- Create `supabase/functions/_tests/workout-reflection.test.ts`: handler validation, ownership, and idempotency tests.
- Modify `supabase/functions/feedback-workout/index.ts`: reflection-aware, safety-first, idempotent debrief generation.
- Create `supabase/functions/_tests/feedback-workout-reflection.test.ts`: prompt, failure, and upsert tests.
- Modify `supabase/config.toml`: register `workout-reflection` with JWT verification.
- Create migration via `supabase migration new add_activity_reflections`: table, grants, RLS, indexes, and stable activity-insight uniqueness.

---

### Task 1: Reflection Domain and Local Debrief Policy

**Files:**
- Create: `Runaway iOS/Models/WorkoutReflection.swift`
- Create: `Runaway iOS/Services/WorkoutDebriefPolicy.swift`
- Create: `Runaway iOS/Runaway iOSTests/WorkoutReflectionTests.swift`
- Create: `Runaway iOS/Runaway iOSTests/WorkoutDebriefPolicyTests.swift`

**Interfaces:**
- Consumes: `SyncMetadata` from `Persistence/Models/SyncTypes.swift`.
- Produces: `WorkoutReflection.validated(...) throws -> WorkoutReflection`, `WorkoutActivitySummary`, and `WorkoutDebriefPolicy.debrief(for:activity:) -> String`.

- [ ] **Step 1: Write reflection validation tests**

```swift
import Foundation
import Testing
@testable import Runaway_iOS

struct WorkoutReflectionTests {
    @Test func effortBoundsAreInclusive() throws {
        _ = try WorkoutReflection.validated(
            id: UUID(), activityId: 42, userId: UUID(), athleteId: 7,
            perceivedEffort: 1, bodyState: .good, mood: .same,
            conditionTags: [], note: nil, now: .now
        )
        _ = try WorkoutReflection.validated(
            id: UUID(), activityId: 42, userId: UUID(), athleteId: 7,
            perceivedEffort: 10, bodyState: .good, mood: .same,
            conditionTags: [], note: nil, now: .now
        )
    }

    @Test(arguments: [0, 11])
    func invalidEffortIsRejected(_ effort: Int) {
        #expect(throws: WorkoutReflection.ValidationError.invalidEffort) {
            try WorkoutReflection.validated(
                id: UUID(), activityId: 42, userId: UUID(), athleteId: 7,
                perceivedEffort: effort, bodyState: .good, mood: .same,
                conditionTags: [], note: nil, now: .now
            )
        }
    }

    @Test func notesAreTrimmedAndLimited() throws {
        let reflection = try WorkoutReflection.validated(
            id: UUID(), activityId: 42, userId: UUID(), athleteId: 7,
            perceivedEffort: 5, bodyState: .good, mood: .better,
            conditionTags: [.heat, .heat], note: "  steady effort  ", now: .now
        )
        #expect(reflection.note == "steady effort")
        #expect(reflection.conditionTags == [.heat])
        #expect(throws: WorkoutReflection.ValidationError.noteTooLong) {
            try WorkoutReflection.validated(
                id: UUID(), activityId: 42, userId: UUID(), athleteId: 7,
                perceivedEffort: 5, bodyState: .good, mood: .same,
                conditionTags: [], note: String(repeating: "x", count: 1001), now: .now
            )
        }
    }
}
```

- [ ] **Step 2: Run the domain tests and verify RED**

Run:

```bash
xcodebuild test -project 'Runaway iOS.xcodeproj' -scheme 'Runaway iOS' -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:'Runaway iOSTests/WorkoutReflectionTests'
```

Expected: build failure because `WorkoutReflection` and its enums do not exist.

- [ ] **Step 3: Implement the minimal validated domain**

```swift
enum ReflectionBodyState: String, Codable, CaseIterable, Sendable {
    case good, tight, sore, pain
}

enum ReflectionMood: String, Codable, CaseIterable, Sendable {
    case better, same, lower
}

enum ReflectionCondition: String, Codable, CaseIterable, Sendable {
    case heat, hills, wind, poorSleep = "poor_sleep", stress
}

struct WorkoutActivitySummary: Equatable, Sendable {
    let distanceMeters: Double?
    let elapsedSeconds: TimeInterval?
    let sportType: String
}

struct WorkoutReflection: Codable, Identifiable, Equatable {
    enum ValidationError: Error, Equatable {
        case invalidEffort
        case noteTooLong
    }

    let id: UUID
    let activityId: Int
    let userId: UUID
    let athleteId: Int
    var perceivedEffort: Int
    var bodyState: ReflectionBodyState
    var mood: ReflectionMood
    var conditionTags: [ReflectionCondition]
    var note: String?
    var localDebrief: String
    var serverDebrief: String?
    let createdAt: Date
    var updatedAt: Date
    var syncMetadata: SyncMetadata

    static func validated(
        id: UUID, activityId: Int, userId: UUID, athleteId: Int,
        perceivedEffort: Int, bodyState: ReflectionBodyState,
        mood: ReflectionMood, conditionTags: [ReflectionCondition],
        note: String?, now: Date
    ) throws -> WorkoutReflection
}
```

The factory trims the note, converts an empty note to `nil`, rejects more than 1,000 characters, deduplicates tags while preserving first-seen order, and creates pending sync metadata. Initialize `localDebrief` to an empty string; the view model assigns policy output before repository save.

- [ ] **Step 4: Run reflection validation tests and verify GREEN**

Expected: all `WorkoutReflectionTests` pass.

- [ ] **Step 5: Write local debrief policy tests**

```swift
struct WorkoutDebriefPolicyTests {
    @Test func painOverridesPerformanceEncouragement() throws {
        let reflection = try fixture(effort: 9, body: .pain, mood: .lower)
        let result = WorkoutDebriefPolicy.debrief(for: reflection, activity: .run)
        #expect(result.localizedCaseInsensitiveContains("stop"))
        #expect(result.localizedCaseInsensitiveContains("pain"))
        #expect(!result.localizedCaseInsensitiveContains("push"))
    }

    @Test func highEffortAcknowledgesRecovery() throws {
        let result = WorkoutDebriefPolicy.debrief(
            for: try fixture(effort: 9, body: .good, mood: .same),
            activity: .run
        )
        #expect(result.localizedCaseInsensitiveContains("recovery"))
    }

    @Test func conditionsAreOnlyMentionedWhenReported() throws {
        let result = WorkoutDebriefPolicy.debrief(
            for: try fixture(effort: 6, body: .good, mood: .better, conditions: [.heat]),
            activity: .run
        )
        #expect(result.localizedCaseInsensitiveContains("heat"))
        #expect(!result.localizedCaseInsensitiveContains("wind"))
    }
}
```

- [ ] **Step 6: Run policy tests and verify RED**

Expected: build failure because `WorkoutDebriefPolicy` does not exist.

- [ ] **Step 7: Implement the deterministic policy**

Use ordered branches: pain, sore/tight plus effort 8-10, effort 8-10, mood lower, and normal reinforcement. Keep every result to two short sentences and use no random variants.

- [ ] **Step 8: Run both focused suites and verify GREEN**

Expected: all reflection and policy tests pass.

### Task 2: SwiftData Reflection Repository

**Files:**
- Create: `Runaway iOS/Persistence/Models/SDWorkoutReflection.swift`
- Create: `Runaway iOS/Repositories/WorkoutReflectionRepository.swift`
- Modify: `Runaway iOS/Persistence/PersistenceController.swift`
- Create: `Runaway iOS/Runaway iOSTests/WorkoutReflectionRepositoryTests.swift`

**Interfaces:**
- Consumes: `WorkoutReflection`, `ReflectionBodyState`, `ReflectionMood`, `ReflectionCondition`, and `SyncStatus`.
- Produces: `WorkoutReflectionRepositoryProtocol` and `LocalWorkoutReflectionRepository`.

- [ ] **Step 1: Write in-memory repository tests**

Test one reflection per `(userId, activityId)`, edit-in-place behavior, fetch by local UUID, pending status after edit, `markSynced`, server-debrief application without field replacement, and deletion.

```swift
@MainActor
@Test func editPreservesIdentityAndMarksPending() throws {
    let repository = try makeRepository()
    var reflection = try fixture()
    try repository.upsert(reflection)
    try repository.markSynced(localID: reflection.id, serverUpdatedAt: .now)

    reflection.perceivedEffort = 8
    try repository.upsert(reflection)

    let stored = try #require(repository.reflection(
        activityId: reflection.activityId,
        userId: reflection.userId
    ))
    #expect(stored.id == reflection.id)
    #expect(stored.perceivedEffort == 8)
    #expect(stored.syncMetadata.syncStatus == .pendingUpload)
}
```

- [ ] **Step 2: Run repository tests and verify RED**

Expected: build failure because the persistence entity and repository do not exist.

- [ ] **Step 3: Implement `SDWorkoutReflection`**

Store scalar persistence fields, raw enum strings, condition raw strings, local/server debriefs, timestamps, and explicit sync metadata fields. Add a unique compound key string `ownerActivityKey = "\(userId.uuidString):\(activityId)"` with `@Attribute(.unique)` so local upsert cannot create duplicates.

- [ ] **Step 4: Implement the repository protocol**

```swift
@MainActor
protocol WorkoutReflectionRepositoryProtocol {
    func reflection(activityId: Int, userId: UUID) throws -> WorkoutReflection?
    func reflection(localID: UUID) throws -> WorkoutReflection?
    func upsert(_ reflection: WorkoutReflection) throws
    func markSynced(localID: UUID, serverUpdatedAt: Date) throws
    func applyServerDebrief(localID: UUID, content: String, generatedAt: Date) throws
    func delete(activityId: Int, userId: UUID) throws
}
```

Use a supplied `ModelContext` for testability. Convert between domain and storage in private mapper methods inside the repository file.

- [ ] **Step 5: Register the entity in `PersistenceController`**

Add `SDWorkoutReflection.self` to every production, preview, and in-memory test schema construction. Do not alter `SDActivity`.

- [ ] **Step 6: Run repository tests and verify GREEN**

Expected: all repository tests pass against an in-memory SwiftData container.

### Task 3: Production Database Contract

**Files:**
- Create via CLI: `runaway-edge/supabase/migrations/<CLI-generated timestamp>_add_activity_reflections.sql`

**Interfaces:**
- Produces: `public.activity_reflections`, ownership policies, lookup indexes, and `activity_insights_activity_type_unique`.

- [ ] **Step 1: Create the migration using the CLI**

Run from `runaway-edge`:

```bash
supabase migration new add_activity_reflections
```

Use the exact path printed by the CLI. Do not hand-invent the timestamp.

- [ ] **Step 2: Add the table and constraints**

```sql
create table public.activity_reflections (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  athlete_id bigint not null,
  activity_id bigint not null references public.activities(id) on delete cascade,
  perceived_effort smallint not null check (perceived_effort between 1 and 10),
  body_state text not null check (body_state in ('good', 'tight', 'sore', 'pain')),
  mood text not null check (mood in ('better', 'same', 'lower')),
  condition_tags text[] not null default '{}'
    check (condition_tags <@ array['heat', 'hills', 'wind', 'poor_sleep', 'stress']::text[]),
  note text check (note is null or char_length(note) <= 1000),
  client_updated_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, activity_id)
);

create index activity_reflections_user_id_idx
  on public.activity_reflections(user_id);
create index activity_reflections_activity_id_idx
  on public.activity_reflections(activity_id);
create index activity_reflections_athlete_id_idx
  on public.activity_reflections(athlete_id);

create unique index activity_insights_activity_type_unique
  on public.activity_insights(activity_id, insight_type)
  where activity_id is not null;
```

Production inspection on 2026-08-25 confirmed zero duplicate `(activity_id, insight_type)` groups, so the unique index requires no destructive deduplication.

- [ ] **Step 3: Add grants and RLS policies**

```sql
grant select, insert, update, delete on public.activity_reflections to authenticated;
grant select, insert, update, delete on public.activity_reflections to service_role;
alter table public.activity_reflections enable row level security;

create policy "Users read their own activity reflections"
on public.activity_reflections for select to authenticated
using ((select auth.uid()) = user_id);

create policy "Users insert their own activity reflections"
on public.activity_reflections for insert to authenticated
with check (
  (select auth.uid()) = user_id
  and exists (
    select 1 from public.activities a
    where a.id = activity_id
      and a.athlete_id = athlete_id
      and a.auth_user_id = (select auth.uid())
  )
);

create policy "Users update their own activity reflections"
on public.activity_reflections for update to authenticated
using ((select auth.uid()) = user_id)
with check (
  (select auth.uid()) = user_id
  and exists (
    select 1 from public.activities a
    where a.id = activity_id
      and a.athlete_id = athlete_id
      and a.auth_user_id = (select auth.uid())
  )
);

create policy "Users delete their own activity reflections"
on public.activity_reflections for delete to authenticated
using ((select auth.uid()) = user_id);
```

- [ ] **Step 4: Apply only to the local Supabase database and verify constraints**

Run the repository's documented local migration command discovered through `supabase db --help`. Verify valid insert, effort checks, note length, unique ownership/activity, and cross-user RLS with local test users. Do not apply to production in this step.

- [ ] **Step 5: Run local database advisors**

Run `supabase db advisors --local` after confirming its exact flags with `supabase db advisors --help`. Expected: no new RLS or missing-index findings for `activity_reflections`.

### Task 4: Authenticated Reflection Edge Function

**Files:**
- Create: `runaway-edge/supabase/functions/workout-reflection/index.ts`
- Create: `runaway-edge/supabase/functions/workout-reflection/deno.json`
- Create: `runaway-edge/supabase/functions/_tests/workout-reflection.test.ts`
- Modify: `runaway-edge/supabase/config.toml`

**Interfaces:**
- Consumes: `resolveUserEndpointDependencies`, shared CORS headers, and `activity_reflections`.
- Produces: JWT-verified `workout-reflection` actions `upsert` and `delete`.

- [ ] **Step 1: Write failing handler tests**

Cover unauthenticated rejection, malformed effort/body/mood/tags/note, activity ownership rejection, server-derived `user_id` and `athlete_id`, idempotent upsert, stale `client_updated_at`, and delete ownership.

```typescript
Deno.test('upsert derives ownership and ignores client identity fields', async () => {
  const handler = createHandler(dependenciesForAthlete(7))
  const response = await handler(authenticatedRequest({
    action: 'upsert',
    reflection: validReflection({ user_id: 'attacker', athlete_id: 999 }),
  }))
  assertEquals(response.status, 200)
  assertEquals(recordedUpsert.user_id, AUTH_USER_ID)
  assertEquals(recordedUpsert.athlete_id, 7)
})
```

- [ ] **Step 2: Run the focused Deno test and verify RED**

```bash
deno test --allow-env supabase/functions/_tests/workout-reflection.test.ts
```

Expected: module-not-found failure for `workout-reflection/index.ts`.

- [ ] **Step 3: Implement request validation and ownership**

Define discriminated request payloads:

```typescript
type ReflectionAction =
  | { action: 'upsert'; reflection: ReflectionInput }
  | { action: 'delete'; activity_id: number }
```

Resolve the user before database access. Fetch the activity with both `activity_id` and resolved `athleteId`. Return stable errors: `INVALID_REQUEST` (400), `UNAUTHORIZED` (401), `FORBIDDEN` (403), `NOT_FOUND` (404), and `INTERNAL_ERROR` (500). Never log note content or the full request.

- [ ] **Step 4: Implement stale-safe idempotent upsert**

First fetch the existing `(user_id, activity_id)` row. If its `client_updated_at` is newer than the incoming timestamp, return that row without overwriting it. Otherwise upsert using `onConflict: 'user_id,activity_id'`, set `updated_at` server-side, and return the accepted row.

- [ ] **Step 5: Register JWT verification**

```toml
[functions.workout-reflection]
enabled = true
verify_jwt = true
import_map = "./functions/workout-reflection/deno.json"
entrypoint = "./functions/workout-reflection/index.ts"
```

- [ ] **Step 6: Run focused and shared user-auth tests and verify GREEN**

```bash
deno test --allow-env \
  supabase/functions/_tests/workout-reflection.test.ts \
  supabase/functions/_tests/user-endpoint-auth.test.ts
```

Expected: all tests pass.

### Task 5: Reflection-Aware Enriched Debrief

**Files:**
- Modify: `runaway-edge/supabase/functions/feedback-workout/index.ts`
- Create: `runaway-edge/supabase/functions/_tests/feedback-workout-reflection.test.ts`
- Modify: `Runaway iOS/Services/ActivityInsightService.swift`

**Interfaces:**
- Consumes: authenticated activity and its `activity_reflections` row.
- Produces: stable `activity_insights` row with `insight_type = 'post_run_debrief'` and response `{ feedback, effort_label, generated_at }`.

- [ ] **Step 1: Write failing backend tests**

Test that reflection context is fetched by activity/athlete/user, pain inserts mandatory safety prompt rules, notes are passed to the model but never logged or stored in insight JSON, retries upsert one insight row, and model failure returns `503` with `DEBRIEF_UNAVAILABLE`.

- [ ] **Step 2: Run focused tests and verify RED**

Expected: assertions fail because the current function does not fetch reflections and inserts duplicate `adlerian_feedback` rows.

- [ ] **Step 3: Build a pure prompt function**

```typescript
export function buildDebriefPrompt(
  activity: ActivityContext,
  reflection: ReflectionContext,
  identity: IdentityContext,
): string
```

Include only supplied context. For `pain`, require conservative stop/recovery language and prohibit diagnosis. Retain the existing no-goal-comparison and no-pivot-language rules.

- [ ] **Step 4: Replace duplicate insert with stable upsert**

```typescript
await supabaseAdmin.from('activity_insights').upsert({
  activity_id,
  insight_type: 'post_run_debrief',
  insight_data: {
    content: feedback,
    effort_label: effortLabel,
    reflection_id: reflection.id,
    generated_at: new Date().toISOString(),
  },
  generated_by: 'feedback-workout',
}, { onConflict: 'activity_id,insight_type' })
```

Do not include the reflection note in `insight_data`.

- [ ] **Step 5: Update iOS insight fetching**

Fetch `post_run_debrief`, order by `created_at` descending, and use `.limit(1)`. Decode both `content` and optional `generated_at` into a small `ServerWorkoutDebrief` value so sync can apply a deterministic timestamp. If no new debrief exists, fall back to the existing `adlerian_feedback` row so historical activity feedback does not disappear.

- [ ] **Step 6: Run backend tests and focused iOS client tests**

Expected: one stable insight row, correct safety prompt, retryable failure, and deterministic iOS decoding.

### Task 6: Remote Service and Durable Sync Pipeline

**Files:**
- Create: `Runaway iOS/Services/WorkoutReflectionRemoteService.swift`
- Modify: `Runaway iOS/Persistence/Models/SyncTypes.swift`
- Modify: `Runaway iOS/Persistence/Sync/SyncEngine.swift`
- Create: `Runaway iOS/Runaway iOSTests/WorkoutReflectionSyncTests.swift`
- Modify: `Runaway iOS/Runaway iOSTests/SyncEngineTests.swift`

**Interfaces:**
- Consumes: local repository, authenticated Edge Function client, and `ActivityInsightService`.
- Produces: `.workoutReflection` and `.workoutDebrief` queue processing with safe follow-up operations.

- [ ] **Step 1: Write failing queue-follow-up tests**

Test that a successful reflection upload removes its operation, marks the reflection synced, and appends one debrief operation; a failed upload does not append debrief; a failed debrief remains queued while reflection stays synced; repeated edits coalesce old debrief work behind the newest upload; and queue persistence survives reinitialization.

- [ ] **Step 2: Run the sync tests and verify RED**

Expected: build failure because new sync entities and follow-up processing do not exist.

- [ ] **Step 3: Extend sync types**

```swift
enum SyncEntityType: String, Codable {
    case activity
    case athlete
    case dailyCommitment
    case workoutReflection
    case workoutDebrief
}
```

Add `SyncOperation.followUpDebrief(localRecordID:activityId:)` to produce a stable debrief operation for the same reflection.

- [ ] **Step 4: Preserve follow-up operations created during a drain**

Change the operation processor to return an optional follow-up operation:

```swift
private func processOperation(_ operation: SyncOperation) async throws -> SyncOperation?
```

Process a snapshot of the current queue. Remove only successful snapshot IDs, retain failed snapshot operations, then append deduplicated follow-ups. Do not overwrite operations queued concurrently while the snapshot is draining.

- [ ] **Step 5: Implement remote operations**

```swift
@MainActor
protocol WorkoutReflectionRemoteServiceProtocol {
    func upsert(_ reflection: WorkoutReflection) async throws -> Date
    func delete(activityId: Int) async throws
    func generateDebrief(activityId: Int, athleteId: Int) async throws -> ServerWorkoutDebrief
}
```

Mark the concrete remote service and its protocol `@MainActor` instead of requiring the non-Sendable domain value to cross an unchecked boundary. Use `AuthenticatedEdgeFunctionClient` for both Edge Functions. Encode only validated fields; never emit note content to logs.

- [ ] **Step 6: Add reflection processing to `SyncEngine`**

For `.workoutReflection` create/update: load by `localRecordID`, upload, mark synced, and return a debrief follow-up. For delete: call remote delete and remove local state. For `.workoutDebrief`: invoke generation and apply server content locally. A debrief failure throws and leaves only that operation queued.

- [ ] **Step 7: Run all sync tests and verify GREEN**

Expected: existing activity reliability tests and all new reflection tests pass.

### Task 7: Reflection View Model and Components

**Files:**
- Create: `Runaway iOS/ViewModels/WorkoutReflectionViewModel.swift`
- Create: `Runaway iOS/Components/PostRunReflectionSheet.swift`
- Create: `Runaway iOS/Components/WorkoutReflectionCard.swift`
- Create: `Runaway iOS/Runaway iOSTests/WorkoutReflectionViewModelTests.swift`

**Interfaces:**
- Consumes: domain validation, local policy, repository, and `SyncEngine`.
- Produces: `WorkoutReflectionViewModel`, `PostRunReflectionSheet`, and `WorkoutReflectionCard`.

- [ ] **Step 1: Write failing view-model tests**

Test required effort/body/mood, skip without persistence, local save before queueing, local debrief availability on offline save, edit retaining reflection ID, and save failure keeping the form visible.

```swift
@MainActor
@Test func savePersistsBeforeQueueing() async throws {
    let events = EventRecorder()
    let viewModel = makeViewModel(events: events)
    viewModel.perceivedEffort = 6
    viewModel.bodyState = .good
    viewModel.mood = .better
    await viewModel.save()
    #expect(events.values == [.persisted, .queuedUpload])
    #expect(viewModel.phase == .debrief)
}
```

- [ ] **Step 2: Run view-model tests and verify RED**

Expected: build failure because the view model does not exist.

- [ ] **Step 3: Implement the view model**

Expose `Phase` values `.form`, `.saving`, `.debrief`, and `.error(String)`. Persist the reflection with deterministic local debrief, queue only the reflection upload initially, and let successful sync generate the debrief follow-up. The event test should therefore assert `[.persisted, .queuedUpload]`; server debrief queueing belongs to sync tests, not the view model.

- [ ] **Step 4: Implement the post-run sheet**

Use one vertically scrolling sheet with:

- `Run logged` confirmation and `How did it feel?` title.
- Accessible 1-10 effort rail with semantic labels.
- Four body-state buttons and three mood buttons.
- Optional condition chips and collapsed note editor.
- `Save reflection` primary action and `Not now` secondary action.
- In-place transition to local debrief after save.

Use existing `AppTheme` tokens, 44-point minimum controls, Dynamic Type, VoiceOver values, and `accessibilityReduceMotion`.

- [ ] **Step 5: Implement the activity-detail card**

Display effort, body, mood, tags, local/server debrief, quiet sync status, and Edit. When no reflection exists, show `Add reflection` instead of an empty card.

- [ ] **Step 6: Run focused view-model tests and compile the app**

Expected: tests pass and both components compile for the existing minimum iOS target.

### Task 8: Post-Save and Activity-Detail Integration

**Files:**
- Modify: `Runaway iOS/Views/RunRecordingView.swift`
- Modify: `Runaway iOS/Views/ActivityDetailView.swift`
- Create: `Runaway iOS/Runaway iOSTests/PostRunReflectionPresentationTests.swift`

**Interfaces:**
- Consumes: saved `LocalActivity`, current user/athlete identity, reflection repository, sheet, and card.
- Produces: automatic post-save presentation plus add/edit from activity detail.

- [ ] **Step 1: Write failing presentation-policy tests**

Extract and test a pure policy:

```swift
enum PostRunReflectionPresentationPolicy {
    static func shouldPresent(
        activityWasSaved: Bool,
        isAppRecorded: Bool,
        existingReflection: WorkoutReflection?
    ) -> Bool
}
```

Require saved, app-recorded activity with no existing reflection. Imported historical activities do not auto-present but remain editable from activity detail.

- [ ] **Step 2: Run focused tests and verify RED**

Expected: build failure because the policy does not exist.

- [ ] **Step 3: Implement the minimal policy and verify GREEN**

Run only `PostRunReflectionPresentationTests`; expected all pass.

- [ ] **Step 4: Hook the successful save seam**

Capture the final persisted activity ID from the existing save result. Set an optional reflection context only after activity persistence succeeds, then present the sheet. `Not now` clears the context and follows the existing post-save dismissal/navigation behavior.

- [ ] **Step 5: Integrate activity detail**

Load the current user's reflection in the existing task, render `WorkoutReflectionCard`, and present the same sheet in edit mode. Refresh local state after save without refetching the entire activity.

- [ ] **Step 6: Integrate activity deletion cleanup**

When activity deletion succeeds locally, delete its local reflection and remove queued reflection/debrief uploads for that activity. Server activity deletion cascades the production reflection row; a retrying activity deletion must not recreate reflection work.

- [ ] **Step 7: Run focused tests and app compilation**

Expected: automatic presentation occurs only for newly saved app-recorded runs; skipping never affects activity persistence.

### Task 9: Local End-to-End Verification

**Files:**
- Modify only files required by failures attributable to Tasks 1-8.

**Interfaces:**
- Consumes: complete local migration, Edge Functions, and iOS implementation.
- Produces: release evidence without production deployment.

- [ ] **Step 1: Run all Edge Function tests**

Discover the repository's canonical command from its package/config files, then run the full Deno function suite. Expected: zero failures.

- [ ] **Step 2: Apply the migration locally and run database checks**

Verify constraints, unique indexes, RLS ownership, cascade deletion, and advisors. Expected: no new security or performance findings.

- [ ] **Step 3: Run the complete iOS unit suite**

```bash
xcodebuild test -project 'Runaway iOS.xcodeproj' -scheme 'Runaway iOS' -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:'Runaway iOSTests'
```

Expected: exit code 0. Record pre-existing Swift 6 warnings separately; no new warnings should originate from reflection files.

- [ ] **Step 4: Run simulator smoke testing**

Verify save/present, skip, local debrief, edit, offline persistence, reconnect sync, enriched replacement, activity deletion, Dynamic Type, VoiceOver, and Reduce Motion.

- [ ] **Step 5: Stop at the production gate**

Summarize migration, functions, tests, smoke evidence, and any residual warnings. Request explicit user approval before applying the migration or deploying functions.

### Task 10: Production Rollout and Verification

**Files:**
- No new code expected; update only if production verification exposes a release-blocking defect.

**Interfaces:**
- Consumes: explicit deployment approval and fully verified artifacts.
- Produces: compatible production backend followed by TestFlight-ready iOS code.

- [ ] **Step 1: Apply the reviewed migration to `runaway-labs`**

Use the Supabase migration workflow discovered via CLI help. Verify table columns, constraints, grants, policies, indexes, and production advisors immediately afterward.

- [ ] **Step 2: Deploy `workout-reflection` with JWT verification**

Verify the production function inventory reports `verify_jwt = true`. Invoke without authentication and require `401`.

- [ ] **Step 3: Deploy updated `feedback-workout` with JWT verification**

Verify its production inventory, then run an authenticated synthetic request owned by the test athlete. Confirm exactly one `post_run_debrief` row is present after a replay.

- [ ] **Step 4: Verify production ownership and cleanup synthetic data**

Confirm cross-user access is denied, invalid payloads are rejected, no notes appear in logs or insight JSON, and synthetic reflection/insight rows are removed.

- [ ] **Step 5: Run the final iOS suite against release configuration**

Expected: exit code 0 before producing a TestFlight archive.

- [ ] **Step 6: Hand off the TestFlight smoke checklist**

Repeat the simulator smoke sequence on a physical device, including offline save and later reconnection. Do not claim release completion until the enriched debrief replaces the local card on-device.
