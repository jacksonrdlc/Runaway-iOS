# Phase 3 — Milestone Detection & Feedback Surfacing

**Date:** 2026-05-07
**Scope:** Phase 3 of 5 — Surface AI workout feedback in Activity Detail; auto-detect and mark runner identity milestones earned
**Trigger:** Phase 1 wrote feedback to `activity_insights` and seeded milestones as unearned; Phase 3 closes both loops

---

## What Phase 3 Adds

1. `ActivityInsightService` reads stored workout feedback and surfaces it in the Activity Detail AI COACH card
2. A new `check-milestones` edge function evaluates all 6 milestones against the athlete's full activity history and marks newly-earned ones
3. `MilestoneService` invokes `check-milestones` fire-and-forget after every activity save and notifies `AthleteView` to refresh
4. `AthleteView` listens for the notification and re-fetches milestones

---

## Naming Convention

No "adlerian" in any iOS type name, file name, or user-facing string. The string `"adlerian_feedback"` appears only as a database filter literal inside `ActivityInsightService`.

---

## New Files

| File | Responsibility |
|---|---|
| `Services/ActivityInsightService.swift` | `fetchFeedback(activityId:)` — reads `activity_insights` |
| `Services/MilestoneService.swift` | `checkMilestones(athleteId:activityId:)` — invokes edge function, posts notification |
| `runaway-edge/supabase/functions/check-milestones/index.ts` | Detects and marks earned milestones server-side |

### Modified Files

| File | Change |
|---|---|
| `Views/ActivityDetailView.swift` | Load feedback on `.task`; show in AI COACH card with local fallback |
| `Services/ActivityService.swift` | Fire-and-forget `MilestoneService.checkMilestones` after activity create |
| `Views/AthleteView.swift` | `.onReceive` notification to re-fetch milestones |

---

## Edge Function: `check-milestones`

### Request

```json
{ "athlete_id": 123, "activity_id": 456 }
```

`activity_id` is included for audit/logging but detection uses full activity history, not just the triggering activity.

### Logic

1. Fetch athlete running activities: `SELECT distance, start_date FROM activities WHERE athlete_id = X AND sport_type IN ('Run', 'TrailRun', 'VirtualRun') ORDER BY start_date ASC`. Filters to running types only — milestone descriptions say "run" explicitly; cycling or gym activities do not count toward streaks or distance milestones.
2. Fetch currently-unearned milestones: `SELECT milestone_key FROM runner_identity_milestones WHERE athlete_id = X AND earned = false`.
3. For each unearned milestone, evaluate against activity history:

| Milestone key | Condition |
|---|---|
| `first_run` | `activities.length >= 1` |
| `distance_5k` | Any activity with `distance >= 5000` |
| `distance_half` | Any activity with `distance >= 21097` |
| `streak_7` | Any 7 consecutive calendar days (UTC date, no time) each with ≥1 activity |
| `consistency_4weeks` | Any 4 consecutive ISO weeks (Mon–Sun) each with ≥1 activity |
| `comeback` | Any consecutive pair of activities where the gap between them is ≥ 14 days |

4. For each newly-earned milestone: `UPDATE runner_identity_milestones SET earned = true, earned_at = now() WHERE athlete_id = X AND milestone_key = Y AND earned = false`.
5. Return `{ newly_earned: string[] }` — the list of milestone keys just marked earned. Empty array if none.

### Notes

- `streak_7` and `consistency_4weeks` deduplicate by date/week before checking (multiple runs on one day count as one day).
- `comeback` requires at least 2 activities total. The gap is between any consecutive pair in the sorted list — the milestone is earned once and stays earned even if the athlete has another gap later.
- Already-earned milestones are never re-evaluated (fetched with `earned = false` filter, updated with `AND earned = false` guard).
- Function uses `supabaseAdmin` (service role key from env) for DB access, same as `identity-profile`.

### Response

```json
{ "newly_earned": ["first_run", "distance_5k"] }
```

Empty `newly_earned` is a valid success response.

---

## `ActivityInsightService.swift`

```swift
struct ActivityInsightService {
    static func fetchFeedback(activityId: Int) async throws -> String? {
        struct Row: Decodable {
            let insightData: InsightData
            enum CodingKeys: String, CodingKey { case insightData = "insight_data" }
        }
        struct InsightData: Decodable {
            let feedback: String
        }

        let rows: [Row] = try await supabase
            .from("activity_insights")
            .select("insight_data")
            .eq("activity_id", value: activityId)
            .eq("insight_type", value: "adlerian_feedback")
            .limit(1)
            .execute()
            .value

        return rows.first?.insightData.feedback
    }
}
```

Returns `nil` if no insight exists (pre-Phase 1 activities or generation failure). Callers use `??` to fall back to the local computed string.

---

## `MilestoneService.swift`

```swift
struct MilestoneService {
    static let didUpdateNotification = Notification.Name("milestonesDidUpdate")

    static func checkMilestones(athleteId: Int, activityId: Int) async throws {
        struct Request: Encodable {
            let athleteId: Int
            let activityId: Int
            enum CodingKeys: String, CodingKey {
                case athleteId  = "athlete_id"
                case activityId = "activity_id"
            }
        }
        struct Response: Decodable {
            let newlyEarned: [String]
            enum CodingKeys: String, CodingKey { case newlyEarned = "newly_earned" }
        }

        let response: Response = try await supabase.functions.invoke(
            "check-milestones",
            options: .init(body: Request(athleteId: athleteId, activityId: activityId))
        )

        if !response.newlyEarned.isEmpty {
            NotificationCenter.default.post(name: didUpdateNotification, object: nil)
        }
    }
}
```

---

## `ActivityDetailView.swift` Changes

Add state and load:

```swift
@State private var fetchedFeedback: String? = nil
```

In `.task` (or add a new `.task(id: activity.id)`):

```swift
fetchedFeedback = try? await ActivityInsightService.fetchFeedback(activityId: activity.id)
```

In the AI COACH card, replace the hardcoded `coachInsight` reference:

```swift
Text(fetchedFeedback ?? coachInsight)
```

`coachInsight` (the existing computed pace string) remains as the fallback. No layout changes.

---

## `ActivityService.swift` Changes

In both `createActivity` overloads, add a second fire-and-forget Task alongside the existing `FeedbackWorkoutService` one:

```swift
Task {
    guard let athleteId = createdActivity.athlete_id else { return }
    try? await MilestoneService.checkMilestones(
        athleteId: athleteId,
        activityId: createdActivity.id
    )
}
```

---

## `AthleteView.swift` Changes

Add to the view's modifier chain (after `.task`, before or alongside `.sheet`):

```swift
.onReceive(NotificationCenter.default.publisher(for: MilestoneService.didUpdateNotification)) { _ in
    guard let athleteId = athlete.id else { return }
    Task {
        milestones = (try? await RunnerMindsetService.fetchMilestones(athleteId: athleteId)) ?? []
    }
}
```

Only `milestones` is refreshed — `mindsetProfile` is unaffected by milestone detection.

---

## Data Flow

```
User saves activity
  → ActivityService.createActivity
      ├── Task: FeedbackWorkoutService.generateFeedback (fire-and-forget)  [Phase 1]
      └── Task: MilestoneService.checkMilestones (fire-and-forget)         [Phase 3 NEW]
              → check-milestones edge function
                  → evaluates 6 milestones against activity history
                  → updates runner_identity_milestones (earned=true)
                  → returns { newly_earned: [...] }
              → if newly_earned non-empty: post milestonesDidUpdate notification
                  → AthleteView.onReceive → re-fetch milestones from DB
                      → milestone rows update from dimmed → amber in UI

User opens Activity Detail
  → ActivityDetailView.task
      → ActivityInsightService.fetchFeedback(activityId)
          → reads activity_insights WHERE insight_type = "adlerian_feedback"
          → returns feedback string (or nil for pre-Phase-1 activities)
      → AI COACH card shows: fetchedFeedback ?? coachInsight (local fallback)
```

---

## Empty States & Error Handling

| Scenario | Behavior |
|---|---|
| No `activity_insights` row for this activity | `fetchedFeedback = nil` → local pace fallback shown |
| `fetchFeedback` throws | `try?` → nil → fallback shown |
| `checkMilestones` throws | `try?` → silently ignored, milestones remain as-is |
| No milestones newly earned | `newly_earned = []` → no notification posted → no refresh |
| `AthleteView` not on screen when notification fires | `onReceive` still fires when view reappears (SwiftUI lifecycle) — milestones will be stale until next foreground, acceptable |

---

## Out of Scope (Phase 4+)

| Item | Deferred to |
|---|---|
| In-app milestone earn celebration / toast | Phase 4 or standalone |
| Audio coach runner identity voice cues during runs | Phase 4 |
| Adlerian-aware coach chat UI | Phase 5 |

---

## Success Criteria

- New activity saved → within a few seconds, any newly-earned milestone rows flip from dimmed to amber in Profile without requiring a manual refresh
- Opening an activity that has a stored `adlerian_feedback` insight → AI COACH card shows the Claude-generated encouragement, not the local formula
- Opening an older activity with no insight row → AI COACH card shows the local computed pace string (no empty state, no error)
- `xcodebuild` clean build — no compile errors
