# Adlerian Psychology Integration — Phase 1: Data & Backend

**Date:** 2026-05-06
**Scope:** Phase 1 of 5 — Schema, Edge Functions, Prompt Updates, minimal iOS hooks
**Trigger:** Adlerian Psychology PRD — integrate encouragement-first coaching into Runaway

---

## Context

The Runaway coach currently evaluates performance against goals. The PRD asks for a shift to Adlerian psychology: runners are encouraged for showing up, not judged against targets. Each runner gets an identity label, a "why I run" statement, and post-workout encouragement that names who they are as a runner — not what they achieved.

Phase 1 is backend-only. No new UI screens. The iOS app gets two minimal changes so the data lands in the right place. UI surfaces (onboarding, audio coach, coach chat Adlerian-aware responses) are Phases 2–5.

---

## Schema Changes

### 1. `runner_identity_milestones` table (new)

```sql
CREATE TABLE runner_identity_milestones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  athlete_id bigint NOT NULL REFERENCES athletes(id) ON DELETE CASCADE,
  milestone_key text NOT NULL,
  label text NOT NULL,
  description text NOT NULL,
  earned boolean NOT NULL DEFAULT false,
  earned_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(athlete_id, milestone_key)
);
CREATE INDEX idx_milestones_athlete ON runner_identity_milestones(athlete_id);
ALTER TABLE runner_identity_milestones ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Athletes see own milestones" ON runner_identity_milestones
  FOR ALL USING (athlete_id = (SELECT id FROM athletes WHERE auth_user_id = auth.uid()));
```

Six seed milestones are inserted by `/identity-profile` at profile creation time using `INSERT ... ON CONFLICT DO NOTHING`:

| milestone_key | label | description |
|---|---|---|
| first_run | First Step | Completed your first run with Runaway |
| streak_7 | Seven-Day Streak | Ran 7 days in a row |
| distance_5k | 5K Club | Completed a run of at least 5K |
| distance_half | Half Marathon Club | Completed a half marathon or longer |
| consistency_4weeks | Consistent Builder | Ran at least once a week for 4 consecutive weeks |
| comeback | Comeback Runner | Returned to running after a gap of 2+ weeks |

### 2. `goal_framing` column on `running_goals` (new)

```sql
ALTER TABLE running_goals ADD COLUMN goal_framing text;
```

Populated by `/identity-profile` when a goal exists, stores one sentence describing the goal in identity terms ("Your goal fits who you already are — a runner who shows up consistently").

### 3. `athlete_ai_profiles.core_memory` (no migration needed)

`core_memory JSONB` already exists in production. The `/identity-profile` function writes a new key `adlerian_profile` into this column:

```json
{
  "adlerian_profile": {
    "runner_identity": "Consistent Builder",
    "identity_summary": "You run because it gives you structure and mental clarity.",
    "why_i_run": "I run to clear my head and feel like myself.",
    "core_values": ["consistency", "mental health", "routine"],
    "updated_at": "2026-05-06T10:00:00Z"
  }
}
```

---

## Edge Functions

### `/identity-profile` (new)

**Location:** `runaway-edge/supabase/functions/identity-profile/index.ts`

**Input:**
```typescript
{
  athlete_id: number,
  why_i_run: string,
  core_values: string[],          // 1–3 values
  mode: "onboarding" | "update"
}
```

**Flow:**
1. Fetch last 90 days of activities for the athlete (distance, duration, frequency)
2. Fetch current `adlerian_profile` from `athlete_ai_profiles.core_memory` (may be null)
3. Call Claude with the activity summary + why_i_run + core_values. Prompt instructs Claude to pick one identity label from the canonical five and write a one-sentence identity_summary in second person.
4. Upsert the `adlerian_profile` key in `core_memory` (merge with existing keys, not replace)
5. Seed 6 milestone rows via `INSERT INTO runner_identity_milestones ... ON CONFLICT DO NOTHING`
6. If athlete has an active running goal, write a `goal_framing` sentence and update `running_goals.goal_framing`

**Output:**
```typescript
{
  runner_identity: string,        // e.g. "Consistent Builder"
  identity_summary: string,       // one sentence, second person
  why_i_run: string,              // echoed back
  core_values: string[]
}
```

**Identity labels (canonical five):**
- Morning Runner — high frequency, usually AM timestamps
- Trail Explorer — elevation gain dominant, varied terrain
- Consistent Builder — steady weekly cadence, no long gaps
- Weekend Warrior — activity clusters on Sat/Sun
- Comeback Runner — recent return after 2+ week gap

Claude picks from exactly these five. If data is insufficient, default to "Consistent Builder".

**Prompt rules:**
- Never reference pace, distance goals, or PRs in the identity summary
- Write identity_summary in second person ("You run because…")
- Keep identity_summary under 20 words

---

### `/feedback-workout` (new)

**Location:** `runaway-edge/supabase/functions/feedback-workout/index.ts`

**Input:**
```typescript
{
  athlete_id: number,
  activity_id: number
}
```

**Flow:**
1. Fetch activity row (distance, elapsed_time, average_heartrate, sport_type)
2. Fetch `adlerian_profile` from `athlete_ai_profiles.core_memory`
3. Derive `effort_label` locally:
   - pace > 7:00/km → Easy
   - pace 6:00–7:00/km → Moderate
   - pace < 6:00/km and duration < 40min → Tempo
   - duration ≥ 70min → Long
4. Call Claude with: runner_identity, why_i_run, effort_label, distance, duration
5. Return feedback string + effort_label

**Output:**
```typescript
{
  feedback: string,       // 2–3 sentences
  effort_label: string    // Easy | Moderate | Tempo | Long
}
```

**Prompt rules:**
- Open with showing-up acknowledgment ("You got out there…", "Today you ran…")
- Name the identity label naturally in the message ("That's what a Consistent Builder does")
- Never compare to a goal, PR, or previous run
- Never use "but", "however", or pivot language
- 2–3 sentences maximum

**iOS stores result in `activity_insights`:**
```json
{
  "activity_id": 12345,
  "athlete_id": 67890,
  "insight_type": "adlerian_feedback",
  "content": "You got out there on a busy Wednesday — that's exactly what a Consistent Builder does. An easy 5K to stay in your rhythm.",
  "metadata": { "effort_label": "Easy" }
}
```

---

## Prompt Updates (existing edge functions)

### `chat/index.ts`

Inject `adlerian_profile` into the system prompt when available:

```
[COACHING VOICE]
This athlete's identity: {runner_identity}. Why they run: {why_i_run}.
Lead with encouragement. Name their identity when relevant.
Never open with performance critique or goal comparison.
```

Fetch `adlerian_profile` from `athlete_ai_profiles.core_memory` at the start of the function. If not present, the existing prompt runs unchanged (no failure mode).

### `goal-assessment/index.ts`

Add to system prompt:
```
This athlete's goal framing: {goal_framing}.
Frame assessment in identity terms, not deficit terms.
```

Read `running_goals.goal_framing` for the athlete's active goal. If null, omit the block.

### `generate-training-plan/index.ts`

Add to system prompt:
```
Runner identity: {runner_identity}. Core values: {core_values}.
Plan description and weekly summaries should reinforce identity, not just list mileage.
```

Fetch `adlerian_profile` from `core_memory`. If absent, no change to existing behavior.

---

## iOS Integration

### `Models/GoalModels.swift`

Add `goalFraming: String?` to the `RunningGoal` model with CodingKey `"goal_framing"`. No other changes — existing goal UI is untouched in Phase 1.

```swift
let goalFraming: String?

enum CodingKeys: String, CodingKey {
    // ... existing keys ...
    case goalFraming = "goal_framing"
}
```

### `Services/ActivityService.swift`

After a successful Strava sync saves a new activity, fire `/feedback-workout` as a background task (fire-and-forget — do not await, do not surface errors to user):

```swift
Task {
    try? await FeedbackWorkoutService.generateFeedback(
        athleteId: athleteId,
        activityId: newActivity.id
    )
}
```

`FeedbackWorkoutService` is a thin wrapper that POSTs to the edge function URL and calls the Supabase `activity_insights` upsert with the result. Errors are swallowed — a missing insight is not user-facing.

---

## What Phase 1 Does Not Include

| Item | Deferred to |
|---|---|
| Onboarding screen for why_i_run + core_values | Phase 2 (UI) |
| Identity label displayed in Profile tab | Phase 2 (UI) |
| Milestone badges visible in app | Phase 2 (UI) |
| Adlerian feedback shown after a run | Phase 3 (Activity Detail) |
| Audio coach Adlerian voice | Phase 4 |
| Adlerian-aware coach chat UI | Phase 5 |

Phase 1 ships the data layer. The app behaves identically to before — but the data is present for Phase 2 to surface.

---

## Verification

- Run migration SQL against local Supabase; confirm `runner_identity_milestones` appears in `supabase db dump`
- Deploy `/identity-profile` and POST test payload; confirm `athlete_ai_profiles.core_memory` contains `adlerian_profile` key
- Deploy `/feedback-workout` and POST with a real activity_id; confirm row appears in `activity_insights` with `insight_type: "adlerian_feedback"`
- Run `xcodebuild` on iOS; confirm no compile errors from GoalModels change
- In `chat` function, confirm existing behavior unchanged when `adlerian_profile` is absent

---

## Success Criteria

- `runner_identity_milestones` table exists with RLS in production
- `running_goals.goal_framing` column exists in production
- `/identity-profile` function deployed and callable
- `/feedback-workout` function deployed and callable
- `chat`, `goal-assessment`, `generate-training-plan` inject Adlerian context when available, degrade gracefully when absent
- `GoalModels.swift` compiles with `goalFraming` field
- `ActivityService.swift` fires background feedback call after sync
