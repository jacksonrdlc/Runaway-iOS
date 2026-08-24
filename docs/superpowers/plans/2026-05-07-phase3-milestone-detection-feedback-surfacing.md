# Phase 3 — Milestone Detection & Feedback Surfacing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Surface AI-generated workout encouragement in Activity Detail and automatically mark runner identity milestones earned when activities are saved.

**Architecture:** A new `check-milestones` Deno edge function detects and marks earned milestones server-side; two new iOS services (`ActivityInsightService`, `MilestoneService`) read from Supabase and invoke the function fire-and-forget; `ActivityDetailView` shows stored feedback with a local computed fallback; `AthleteView` refreshes milestones via `NotificationCenter` when new ones are earned.

**Tech Stack:** Swift 5.9, SwiftUI, Supabase iOS SDK (global `supabase` singleton), Deno/TypeScript edge functions, Supabase service role key for admin DB access in the edge function.

---

## File Map

| Action | File |
|--------|------|
| Create | `runaway-edge/supabase/functions/check-milestones/index.ts` |
| Create | `Runaway iOS/Runaway iOS/Services/ActivityInsightService.swift` |
| Create | `Runaway iOS/Runaway iOS/Services/MilestoneService.swift` |
| Modify | `Runaway iOS/Runaway iOS/Views/ActivityDetailView.swift` |
| Modify | `Runaway iOS/Runaway iOS/Services/ActivityService.swift` |
| Modify | `Runaway iOS/Runaway iOS/Views/AthleteView.swift` |

---

## Task 1: `check-milestones` edge function

**Files:**
- Create: `runaway-edge/supabase/functions/check-milestones/index.ts`

**Working directory for this task:** `/Users/jack.rudelic/projects/labs/runaway/runaway-edge`

This edge function accepts `{ athlete_id, activity_id }`, fetches the athlete's running activity history, evaluates which of the 6 milestones are newly earned, marks them in `runner_identity_milestones`, and returns `{ newly_earned: string[] }`.

- [ ] **Step 1: Create the edge function file**

```typescript
// runaway-edge/supabase/functions/check-milestones/index.ts
import { createClient } from 'jsr:@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

const RUNNING_SPORT_TYPES = ['Run', 'TrailRun', 'VirtualRun']

type Activity = {
  distance: number | null
  activity_date: string | null
}

function toCalendarDay(dateStr: string): string {
  // Returns 'YYYY-MM-DD' in UTC
  return dateStr.slice(0, 10)
}

function isoWeekKey(dateStr: string): string {
  // Returns 'YYYY-Www' e.g. '2026-W18' — Monday-anchored ISO week
  const d = new Date(dateStr)
  const thursday = new Date(d)
  thursday.setUTCDate(d.getUTCDate() - ((d.getUTCDay() + 6) % 7) + 3)
  const year = thursday.getUTCFullYear()
  const startOfYear = new Date(Date.UTC(year, 0, 4))
  const weekNum = Math.round(
    ((thursday.getTime() - startOfYear.getTime()) / 86400000 -
      3 + ((startOfYear.getUTCDay() + 6) % 7)) / 7
  ) + 1
  return `${year}-W${String(weekNum).padStart(2, '0')}`
}

function evaluateMilestones(
  activities: Activity[],
  unearnedKeys: Set<string>
): string[] {
  const newlyEarned: string[] = []

  // Sort by date ascending, filter out null dates
  const sorted = activities
    .filter((a): a is Activity & { activity_date: string } => a.activity_date != null)
    .sort((a, b) => a.activity_date.localeCompare(b.activity_date))

  if (sorted.length === 0) return newlyEarned

  // first_run
  if (unearnedKeys.has('first_run')) {
    newlyEarned.push('first_run')
  }

  // distance_5k
  if (unearnedKeys.has('distance_5k')) {
    if (sorted.some((a) => (a.distance ?? 0) >= 5000)) {
      newlyEarned.push('distance_5k')
    }
  }

  // distance_half
  if (unearnedKeys.has('distance_half')) {
    if (sorted.some((a) => (a.distance ?? 0) >= 21097)) {
      newlyEarned.push('distance_half')
    }
  }

  // streak_7: any 7 consecutive calendar days each with >= 1 run
  if (unearnedKeys.has('streak_7')) {
    const daySet = new Set(sorted.map((a) => toCalendarDay(a.activity_date)))
    const days = Array.from(daySet).sort()
    let streak = 1
    for (let i = 1; i < days.length; i++) {
      const prev = new Date(days[i - 1])
      const curr = new Date(days[i])
      const diffDays = Math.round((curr.getTime() - prev.getTime()) / 86400000)
      if (diffDays === 1) {
        streak++
        if (streak >= 7) { newlyEarned.push('streak_7'); break }
      } else {
        streak = 1
      }
    }
  }

  // consistency_4weeks: any 4 consecutive ISO weeks each with >= 1 run
  if (unearnedKeys.has('consistency_4weeks')) {
    const weekSet = new Set(sorted.map((a) => isoWeekKey(a.activity_date)))
    const weeks = Array.from(weekSet).sort()
    // Build a map of weekKey -> true for quick lookup
    const weekMap: Record<string, boolean> = {}
    for (const w of weeks) weekMap[w] = true

    // For each week, check if the next 3 consecutive weeks also exist
    outer: for (let i = 0; i < weeks.length; i++) {
      // Parse year and week number
      const [yearStr, wStr] = weeks[i].split('-W')
      let year = parseInt(yearStr)
      let week = parseInt(wStr)
      let consecutive = 1
      for (let j = 1; j < 4; j++) {
        week++
        if (week > 52) { week = 1; year++ }
        const key = `${year}-W${String(week).padStart(2, '0')}`
        if (!weekMap[key]) continue outer
        consecutive++
      }
      if (consecutive >= 4) { newlyEarned.push('consistency_4weeks'); break }
    }
  }

  // comeback: any consecutive pair of activities with gap >= 14 days
  if (unearnedKeys.has('comeback') && sorted.length >= 2) {
    for (let i = 1; i < sorted.length; i++) {
      const prev = new Date(sorted[i - 1].activity_date)
      const curr = new Date(sorted[i].activity_date)
      const gapDays = (curr.getTime() - prev.getTime()) / 86400000
      if (gapDays >= 14) {
        newlyEarned.push('comeback')
        break
      }
    }
  }

  return newlyEarned
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders })
  }

  try {
    const { athlete_id, activity_id } = await req.json()

    if (!athlete_id) {
      return new Response(
        JSON.stringify({ error: { code: 'INVALID_REQUEST', message: 'athlete_id is required' } }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Fetch unearned milestone keys
    const { data: unearnedRows, error: milestoneError } = await supabaseAdmin
      .from('runner_identity_milestones')
      .select('milestone_key')
      .eq('athlete_id', athlete_id)
      .eq('earned', false)

    if (milestoneError) {
      console.error('Error fetching milestones:', milestoneError)
      return new Response(
        JSON.stringify({ error: { code: 'DB_ERROR', message: 'Failed to fetch milestones' } }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // If all milestones already earned, short-circuit
    if (!unearnedRows || unearnedRows.length === 0) {
      return new Response(
        JSON.stringify({ newly_earned: [] }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const unearnedKeys = new Set(unearnedRows.map((r) => r.milestone_key as string))

    // Fetch running activities
    const { data: activities, error: activitiesError } = await supabaseAdmin
      .from('activities')
      .select('distance, activity_date')
      .eq('athlete_id', athlete_id)
      .in('sport_type', RUNNING_SPORT_TYPES)
      .order('activity_date', { ascending: true })

    if (activitiesError) {
      console.error('Error fetching activities:', activitiesError)
      return new Response(
        JSON.stringify({ error: { code: 'DB_ERROR', message: 'Failed to fetch activities' } }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const newlyEarned = evaluateMilestones(activities ?? [], unearnedKeys)

    // Mark newly earned milestones
    if (newlyEarned.length > 0) {
      const now = new Date().toISOString()
      for (const key of newlyEarned) {
        const { error: updateError } = await supabaseAdmin
          .from('runner_identity_milestones')
          .update({ earned: true, earned_at: now })
          .eq('athlete_id', athlete_id)
          .eq('milestone_key', key)
          .eq('earned', false) // guard against race conditions
        if (updateError) {
          console.error(`Error marking milestone ${key}:`, updateError)
        }
      }
    }

    console.log('check-milestones complete:', { athlete_id, activity_id, newly_earned: newlyEarned })

    return new Response(
      JSON.stringify({ newly_earned: newlyEarned }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error in check-milestones:', error)
    return new Response(
      JSON.stringify({ error: 'Internal error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
```

- [ ] **Step 2: Verify the file exists**

```bash
ls supabase/functions/check-milestones/index.ts
```

Expected: file listed.

- [ ] **Step 3: Deploy to Supabase**

```bash
supabase functions deploy check-milestones
```

Expected output ends with: `check-milestones: deployed`

If deploy fails with auth error, run `supabase login` first.

- [ ] **Step 4: Commit**

```bash
cd /Users/jack.rudelic/projects/labs/runaway/runaway-edge
git add supabase/functions/check-milestones/index.ts
git commit -m "feat: add check-milestones edge function for runner identity milestone detection"
```

---

## Task 2: `ActivityInsightService.swift`

**Files:**
- Create: `Runaway iOS/Runaway iOS/Services/ActivityInsightService.swift`

**Working directory for this task:** `/Users/jack.rudelic/projects/labs/runaway/Runaway iOS`

Reads stored AI workout feedback from `activity_insights` for a given activity. The string `"adlerian_feedback"` is used only as a DB filter literal — it does not appear in any type name or user-facing string.

- [ ] **Step 1: Create `ActivityInsightService.swift`**

```swift
// Runaway iOS/Services/ActivityInsightService.swift
import Foundation

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

- [ ] **Step 2: Confirm file created at the right path**

```bash
ls "Runaway iOS/Services/ActivityInsightService.swift"
```

Expected: file listed.

- [ ] **Step 3: Commit**

```bash
git add "Runaway iOS/Services/ActivityInsightService.swift"
git commit -m "feat: add ActivityInsightService to fetch stored workout feedback"
```

---

## Task 3: `MilestoneService.swift`

**Files:**
- Create: `Runaway iOS/Runaway iOS/Services/MilestoneService.swift`

Invokes `check-milestones`, decodes the response, and posts a `NotificationCenter` notification when milestones are newly earned.

- [ ] **Step 1: Create `MilestoneService.swift`**

```swift
// Runaway iOS/Services/MilestoneService.swift
import Foundation

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

- [ ] **Step 2: Commit**

```bash
git add "Runaway iOS/Services/MilestoneService.swift"
git commit -m "feat: add MilestoneService to invoke check-milestones and notify AthleteView"
```

---

## Task 4: `ActivityDetailView.swift` — surface stored feedback

**Files:**
- Modify: `Runaway iOS/Runaway iOS/Views/ActivityDetailView.swift`

The view already has an "AI COACH" card that displays `coachInsight` (a locally-computed pace string). This task adds a `fetchedFeedback` state var that loads the stored AI feedback on appear, and updates the card to show it with `coachInsight` as the fallback.

- [ ] **Step 1: Read the current file to find insertion points**

Read `Runaway iOS/Views/ActivityDetailView.swift`. Locate:
1. The `@State` block (around line 18–20) where `showDeleteConfirmation`, `isDeleting`, `showContent` are declared
2. The `.navigationBarTitleDisplayMode(.inline)` modifier or `.task` block (if one exists already)
3. The `Text(coachInsight)` line inside the AI COACH card (around line 159)

- [ ] **Step 2: Add `fetchedFeedback` state var**

After the existing `@State private var showContent = false` line, add:

```swift
@State private var fetchedFeedback: String? = nil
```

- [ ] **Step 3: Add `.task` to load feedback**

After the closing brace of the `ScrollView { ... }` block (before `.navigationBarTitleDisplayMode(.inline)`), add:

```swift
.task(id: activity.id) {
    fetchedFeedback = try? await ActivityInsightService.fetchFeedback(activityId: activity.id)
}
```

Using `.task(id: activity.id)` ensures the fetch re-runs if the view is reused for a different activity.

- [ ] **Step 4: Update the AI COACH card text**

Find the line:
```swift
Text(coachInsight)
```
inside the AI COACH `VStack`. Replace with:
```swift
Text(fetchedFeedback ?? coachInsight)
```

No other changes to the card layout.

- [ ] **Step 5: Commit**

```bash
git add "Runaway iOS/Views/ActivityDetailView.swift"
git commit -m "feat: surface stored AI workout feedback in Activity Detail coach card"
```

---

## Task 5: `ActivityService.swift` — fire milestone check after activity create

**Files:**
- Modify: `Runaway iOS/Runaway iOS/Services/ActivityService.swift`

The file already has two `createActivity` overloads, each with a fire-and-forget `Task` calling `FeedbackWorkoutService.generateFeedback`. This task adds a parallel fire-and-forget `Task` calling `MilestoneService.checkMilestones` in the same two places.

- [ ] **Step 1: Read the current file to find both insertion points**

Read `Runaway iOS/Services/ActivityService.swift`. Search for the two occurrences of:
```swift
// Fire-and-forget runner identity feedback generation
Task {
    guard let athleteId = createdActivity.athlete_id else { return }
    try? await FeedbackWorkoutService.generateFeedback(
```

There are two — one per `createActivity` overload.

- [ ] **Step 2: Add milestone check fire-and-forget after each feedback Task**

For **each** of the two existing feedback `Task` blocks, add a new `Task` block immediately after it:

```swift
Task {
    guard let athleteId = createdActivity.athlete_id else { return }
    try? await MilestoneService.checkMilestones(
        athleteId: athleteId,
        activityId: createdActivity.id
    )
}
```

The result is that each `createActivity` overload has two consecutive fire-and-forget Tasks: one for feedback, one for milestones.

- [ ] **Step 3: Commit**

```bash
git add "Runaway iOS/Services/ActivityService.swift"
git commit -m "feat: fire-and-forget milestone check after activity creation"
```

---

## Task 6: `AthleteView.swift` — refresh milestones on notification

**Files:**
- Modify: `Runaway iOS/Runaway iOS/Views/AthleteView.swift`

When `MilestoneService` posts `milestonesDidUpdate`, `AthleteView` re-fetches the milestone rows from Supabase. No other state is affected.

- [ ] **Step 1: Read the file to find the modifier chain**

Read `Runaway iOS/Views/AthleteView.swift`. Locate the `.task { ... }` and `.sheet(isPresented: $showingEditMindset) { ... }` modifiers at the bottom of the `body`.

- [ ] **Step 2: Add `.onReceive` after the `.sheet` modifier**

After the `.sheet(isPresented: $showingEditMindset) { ... }` block, add:

```swift
.onReceive(NotificationCenter.default.publisher(for: MilestoneService.didUpdateNotification)) { _ in
    guard let athleteId = athlete.id else { return }
    Task {
        milestones = (try? await RunnerMindsetService.fetchMilestones(athleteId: athleteId)) ?? []
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add "Runaway iOS/Views/AthleteView.swift"
git commit -m "feat: refresh milestones in Profile when milestonesDidUpdate notification fires"
```

---

## Task 7: Build verification

**Files:** (no changes — verification only)

- [ ] **Step 1: Build the iOS app target**

```bash
cd "/Users/jack.rudelic/projects/labs/runaway/Runaway iOS"
xcodebuild -project "Runaway iOS.xcodeproj" \
    -scheme "Runaway iOS" \
    -destination "platform=iOS Simulator,name=iPhone 16" \
    build 2>&1 | tail -30
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 2: If build fails, diagnose and fix**

Common issues:

**`ActivityInsightService` not found**: Confirm the file was added to the Xcode project target. If Xcode doesn't auto-include new files (depends on project setup), you may need to add it via Xcode UI or check that the file is in the right directory.

**`MilestoneService` not found**: Same — confirm target membership.

**`.task(id:)` not available**: Requires iOS 15+. The project targets iOS 16+ so this is safe.

**`supabase` not in scope**: The global singleton is in `Runaway iOS/Utils/Supabase.swift` — new service files in `Runaway iOS/Services/` are in the same module and can access it directly.

- [ ] **Step 3: Commit any build fixes**

```bash
git add -u
git commit -m "fix: resolve build errors from Phase 3 integration"
```

---

## Self-Review

**Spec coverage:**
- ✅ `ActivityInsightService.fetchFeedback` reads `activity_insights` with `insight_type = "adlerian_feedback"` filter (Task 2)
- ✅ `ActivityDetailView` shows `fetchedFeedback ?? coachInsight` (Task 4)
- ✅ `check-milestones` edge function evaluates all 6 milestones, filters to `Run/TrailRun/VirtualRun` sport types (Task 1)
- ✅ Milestone detection short-circuits when all already earned (Task 1)
- ✅ `earned = false` guard in UPDATE prevents race condition double-marking (Task 1)
- ✅ `MilestoneService.checkMilestones` invokes edge function, posts notification when `newly_earned` non-empty (Task 3)
- ✅ `ActivityService` fires milestone check fire-and-forget in both `createActivity` overloads (Task 5)
- ✅ `AthleteView.onReceive` re-fetches only `milestones` (not `mindsetProfile`) (Task 6)
- ✅ Build verification (Task 7)

**No Adlerian in iOS type names or user-facing strings:** `"adlerian_feedback"` appears only as a DB filter string inside `ActivityInsightService.fetchFeedback`.

**Type consistency:** `MilestoneService.didUpdateNotification` defined in Task 3, referenced in Task 6. `RunnerMindsetService.fetchMilestones` defined in Phase 2, called in Task 6. `ActivityInsightService.fetchFeedback` defined in Task 2, called in Task 4. All consistent.
