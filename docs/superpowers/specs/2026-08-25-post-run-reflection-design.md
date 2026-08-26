# Post-Run Reflection and Automatic Debrief Design

Date: 2026-08-25
Status: Proposed

## Purpose

Add a fast, offline-first reflection immediately after a runner saves a workout. The reflection captures subjective context that activity metrics cannot provide and uses it to produce immediate local guidance plus a richer server-generated debrief after synchronization.

The feature must remain useful without connectivity, preserve user ownership and privacy, and reuse the app's durable synchronization architecture.

## Goals

- Present a skippable reflection sheet after a successfully saved run.
- Let a runner complete the core reflection in about 15 seconds.
- Save locally before making any network request.
- Generate an immediate, deterministic, non-diagnostic local debrief.
- Reliably synchronize reflections through the existing durable queue.
- Generate a personalized server debrief after synchronization.
- Let runners add or edit reflections from activity detail.
- Prevent duplicate reflections, queue work, and generated insights.

## Non-Goals

- A conversational assistant or free-form coaching chat.
- Medical diagnosis, injury classification, or treatment advice.
- Automatic training-plan mutation in the first release.
- Historical reflection backfill.
- Analytics collection from reflection notes or sensitive health-like responses.

## User Experience

### Post-Save Sheet

After an app-recorded run is saved successfully, present a medium-height, skippable sheet. Saving the activity is never conditional on completing the reflection.

The sheet contains:

1. A confirmation header: `Run logged`.
2. A prompt: `How did it feel?`
3. A perceived-effort control from 1 through 10, anchored by plain-language labels from `Easy` to `Max`.
4. A body-state choice: `Good`, `Tight`, `Sore`, or `Pain`.
5. A mood choice: `Better`, `Same`, or `Lower`.
6. Optional condition tags: `Heat`, `Hills`, `Wind`, `Poor sleep`, and `Stress`.
7. An optional note field, collapsed by default.
8. A primary `Save reflection` action and secondary `Not now` action.

Effort, body state, and mood are required to save. Conditions and notes are optional. `Not now` dismisses the sheet without creating a placeholder record.

### Immediate Debrief

After local save, the input area transitions into a concise debrief card. The initial debrief is generated locally and is available offline. The transition respects Reduce Motion.

The local debrief follows these priorities:

1. `Pain` always produces conservative stop-and-recover guidance and recommends professional evaluation when appropriate. It never diagnoses a condition.
2. `Sore` or `Tight` combined with high effort emphasizes recovery and monitoring.
3. High effort without concerning body feedback acknowledges load and recommends recovery basics.
4. Moderate or low effort provides reinforcement consistent with the runner's reported mood and conditions.

The local debrief remains visible until a server debrief is available. Server enrichment replaces the content in the same card instead of adding a second insight.

### Activity Detail

Completed activities display a `Your Reflection` card when a reflection exists. The card includes effort, body state, mood, condition tags, sync status, debrief, and an Edit action.

Activities without a reflection display a compact `Add reflection` action. Editing updates the existing reflection rather than creating another record.

### Visual Direction

The feature extends the existing Runaway dark athletic design rather than introducing a medical-form aesthetic.

- Strong numeric hierarchy for effort.
- Restrained semantic color progression across the effort rail.
- Large tap targets and SF Symbols for body and mood states.
- Existing theme tokens for surfaces, spacing, typography, and accent color.
- Dynamic Type, VoiceOver descriptions, sufficient contrast, and Reduce Motion support.
- Sync state is quiet supporting information, not a dominant warning.

## Client Architecture

### Domain Model

Introduce `WorkoutReflection`, independent from provider-owned activity models.

Required fields:

- `id: UUID`
- `activityId: Int`
- `userId: UUID`
- `athleteId: Int`
- `perceivedEffort: Int`
- `bodyState: BodyState`
- `mood: ReflectionMood`
- `conditionTags: [ReflectionCondition]`
- `note: String?`
- `localDebrief: String`
- `serverDebrief: String?`
- `createdAt: Date`
- `updatedAt: Date`
- `syncMetadata: SyncMetadata`

Validation rules:

- Perceived effort is between 1 and 10 inclusive.
- Notes are trimmed and limited to 1,000 characters.
- Condition tags are selected from the supported enum and contain no duplicates.
- One reflection exists per activity and user.

### Local Persistence

Persist reflections as a separate SwiftData entity, `SDWorkoutReflection`. Do not add subjective reflection fields to `SDActivity` or remote-provider activity payloads.

The local repository provides:

- Fetch by activity ID and current user ID.
- Upsert with validation.
- Delete by activity ID and current user ID.
- Apply a server debrief without replacing locally entered reflection fields.
- Fetch pending records by local UUID for synchronization.

Saving or editing increments local version metadata and marks the record `pendingUpload`.

### Local Debrief Policy

Implement a pure `WorkoutDebriefPolicy` with no network or persistence dependencies. It accepts validated reflection values and a small activity summary, then returns a short debrief.

The policy must:

- Prioritize body-state safety over performance encouragement.
- Avoid diagnoses and certainty about injury.
- Avoid comparing the run to goals, personal records, or prior workouts.
- Mention relevant reported conditions without inventing context.
- Produce deterministic output suitable for unit testing.

### Sync Integration

Extend `SyncEntityType` with `workoutReflection` and `workoutDebrief`. Reflection queue operations use the local reflection UUID as `localRecordID` and the activity ID as `entityId`.

The existing queue behavior applies:

- Repeated pending updates for one reflection coalesce.
- Failed work remains durable across launches.
- Connectivity restoration triggers retry.
- A successful reflection upload marks the reflection synced, removes its upload operation, and queues a separate idempotent debrief operation.
- A failed debrief remains queued without changing the reflection's synced status.
- Deletion is processed before upload and cannot be overtaken by an older pending update.
- Deleting a reflection or activity removes obsolete pending debrief work for that activity.

Reflection processing delegates to a focused repository/service rather than placing request construction directly in `SyncEngine`.

## Server Architecture

### Database Table

Create `public.activity_reflections` with:

- `id uuid primary key`
- `user_id uuid not null references auth.users(id) on delete cascade`
- `athlete_id bigint not null`
- `activity_id bigint not null references public.activities(id) on delete cascade`
- `perceived_effort smallint not null check (perceived_effort between 1 and 10)`
- `body_state text not null` with an allowed-value check
- `mood text not null` with an allowed-value check
- `condition_tags text[] not null default '{}'`
- `note text null` with a 1,000-character check
- `created_at timestamptz not null default now()`
- `updated_at timestamptz not null default now()`
- `client_updated_at timestamptz not null`
- unique constraint on `(user_id, activity_id)`

Add indexes for `user_id`, `activity_id`, and pending activity ownership lookups where query plans require them.

Enable RLS. Authenticated policies permit select, insert, update, and delete only when `(select auth.uid()) = user_id`. Update policies include both `USING` and `WITH CHECK` ownership predicates.

The server validates that `activity_id` belongs to the resolved athlete for the authenticated user. Client-provided `athlete_id` is not trusted for authorization.

### Reflection Upload

Add a JWT-verified `workout-reflection` Edge Function for upsert and delete operations. It resolves the authenticated user and athlete with the shared user-endpoint guard, verifies that the activity belongs to that athlete, and performs an idempotent upsert keyed by `(user_id, activity_id)`.

The server owns `user_id` and `athlete_id`; both are derived from the authenticated session rather than trusted from authorization claims in the request body. Client reads use the RLS-protected table.

Conflict behavior is last accepted client edit wins using `client_updated_at`. A stale retry cannot overwrite a newer accepted reflection.

### Enriched Debrief

Extend `feedback-workout` to fetch the authenticated runner's reflection for the requested activity. The generated prompt may use:

- Activity distance, duration, sport, and heart-rate summary.
- Perceived effort.
- Body state.
- Mood.
- Selected conditions.
- Optional note.
- Existing runner identity context.

The prompt must prohibit diagnosis, goal comparison, and unsupported claims. If `body_state` is `pain`, safety guidance takes precedence over motivational language.

Change the `activity_insights` write for this debrief from duplicate insert behavior to an idempotent upsert. Use one stable insight row per activity and insight type. Store reflection/debrief provenance and generation timestamp in `insight_data` without duplicating the private note.

If external generation fails, return a retryable error for the separate debrief operation while preserving the uploaded reflection and its synced state.

## Privacy and Security

- Reflection notes and body-state responses are sensitive user data.
- Do not include note text, body state, or mood in analytics events or diagnostic logs.
- Do not log generated prompts or debrief bodies.
- Do not expose service-role credentials to the app.
- Require authenticated ownership at the database and Edge Function layers.
- Keep note retention tied to account and activity deletion behavior.
- Use neutral wellness language and avoid medical conclusions.

## Failure Handling

- Local persistence failure: keep the sheet open and show an actionable retry message.
- Offline state: save locally, show `Pending sync`, and allow normal dismissal.
- Authentication expiry: retain queued work and retry after session recovery.
- Reflection upload failure: retain the reflection upload operation and local record.
- Debrief generation failure: retain the local debrief and only the debrief queue operation; do not mark the uploaded reflection pending again.
- Server debrief fetch failure: continue showing local debrief and retry during a later sync/refresh.
- Activity deletion: delete the local reflection and queue server deletion; database cascade is defense in depth.

## Testing Strategy

### iOS Unit Tests

- Validation accepts effort 1 and 10 and rejects values outside the range.
- Note trimming and length enforcement.
- Condition tags remain unique and Codable.
- Local debrief prioritizes pain-safe language.
- Local debrief responds to effort, body state, mood, and conditions without inventing context.
- Local repository creates, edits, fetches, and deletes one reflection per activity.
- Editing marks a synced record pending and increments its local version.
- Queue coalesces repeated reflection updates.
- Failed uploads survive retry and app relaunch persistence.
- Failed debrief generation retries independently after reflection upload succeeds.
- Deletion ordering prevents an older upload from recreating deleted data.
- Successful sync applies server debrief without replacing user-entered fields.

### Edge Function Tests

- Missing or invalid JWT is rejected.
- A user cannot write a reflection for another user's activity.
- Invalid effort, enum values, tags, and oversized notes are rejected.
- Repeated upload is idempotent.
- Stale client updates do not overwrite newer data.
- Enriched debrief prompt includes allowed reflection context.
- Pain responses enforce safety-focused prompt rules.
- External model failure returns retryable behavior without losing reflection data.
- Repeated debrief requests update one insight row rather than inserting duplicates.

### Database Verification

- RLS blocks cross-user select, insert, update, and delete.
- Update ownership cannot be reassigned.
- Check constraints reject invalid values.
- Unique constraint prevents multiple reflections per user and activity.
- Activity and account deletion remove associated reflections.
- Relevant indexes are used for ownership and activity lookups.

### Smoke Test

On the simulator:

1. Save a run and confirm the reflection sheet appears.
2. Skip and confirm the activity remains saved.
3. Save a reflection and confirm immediate local debrief.
4. Edit the reflection from activity detail.
5. Save while offline and confirm pending state.
6. Restore connectivity and confirm synchronization and enriched debrief replacement.
7. Delete the activity and confirm its reflection disappears.
8. Verify Dynamic Type, VoiceOver, and Reduce Motion behavior.

## Rollout Plan

1. Add and verify the database migration, constraints, indexes, and RLS.
2. Update and deploy the authenticated reflection/debrief backend behavior.
3. Implement the iOS domain model, persistence, policy, and queue integration with test-first development.
4. Implement the post-save sheet and activity-detail reflection card.
5. Run full iOS, Edge Function, database, and simulator verification.
6. Release through TestFlight after production backend verification.

The backend is deployed before the client so every shipped client version has compatible server behavior. Existing clients remain unaffected because the new table and request fields are additive.

## Acceptance Criteria

- A saved run never depends on reflection completion or connectivity.
- A completed reflection is visible immediately after local save.
- The reflection remains available after app restart while offline.
- Pending reflections synchronize automatically when connectivity returns.
- Exactly one reflection and one enriched debrief exist per user and activity.
- Users cannot access or alter another runner's reflection.
- Pain feedback produces conservative, non-diagnostic guidance.
- Reflection edits are available from activity detail.
- No sensitive reflection content appears in analytics or logs.
- All automated tests and the documented smoke flow pass before release.
