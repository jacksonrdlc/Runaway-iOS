# Runner Mindset UI — Phase 2 Design

**Date:** 2026-05-07
**Scope:** Phase 2 of 5 — iOS UI surfaces for runner identity, mindset onboarding, and milestones
**Trigger:** Adlerian Phase 1 shipped the backend; Phase 2 makes it visible to the runner

---

## Naming Convention

The word "Adlerian" does not appear in any iOS file name, UI label, or user-facing string. All naming uses mindset/identity language:

| Internal (backend, DB) | iOS / User-facing |
|---|---|
| `adlerian_profile` key in core_memory | `MindsetProfile` model |
| `/identity-profile` edge function | `RunnerMindsetService` |
| `adlerian_feedback` insight_type | (not surfaced in Phase 2) |
| Adlerian psychology | "running mindset" / "runner identity" |

---

## What Phase 2 Adds

1. A new onboarding step — "Your Running Mindset" — to capture `why_i_run` and `core_values`
2. An identity card section in the Profile tab showing the runner's identity label and summary
3. A milestones list section in the Profile tab
4. An `EditRunnerMindsetView` sheet accessible from both onboarding and the Profile ACCOUNT section
5. Two new models, one new service, and three new view files

---

## New Files

| File | Responsibility |
|---|---|
| `Models/MindsetModels.swift` | `MindsetProfile` and `RunnerIdentityMilestone` structs |
| `Services/RunnerMindsetService.swift` | `fetchProfile`, `saveProfile`, `fetchMilestones` |
| `Views/EditRunnerMindsetView.swift` | Reusable sheet: why_i_run text field + core values chip picker |

### Modified Files

| File | Change |
|---|---|
| `Views/Onboarding/OnboardingStepViews.swift` | Add `RunnerMindsetStepView` |
| `Views/Onboarding/OnboardingContainerView.swift` | Register new step in sequence (Step 6, before Location Permission) |
| `Views/AthleteView.swift` | Add identity card, milestones section, ACCOUNT row |

---

## Models (`MindsetModels.swift`)

```swift
struct MindsetProfile {
    let runnerIdentity: String      // "Consistent Builder" | "Morning Runner" | etc.
    let identitySummary: String     // one sentence, second person
    let whyIRun: String
    let coreValues: [String]        // 1–3 values
}

struct RunnerIdentityMilestone: Identifiable, Decodable {
    let id: UUID
    let milestoneKey: String
    let label: String
    let description: String
    let earned: Bool
    let earnedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case milestoneKey  = "milestone_key"
        case label
        case description
        case earned
        case earnedAt      = "earned_at"
    }
}
```

`MindsetProfile` is not `Decodable` directly — it is assembled by `RunnerMindestService` from the `adlerian_profile` key inside `core_memory` JSONB.

---

## Service (`RunnerMindsetService.swift`)

Three static async methods. All use the global `supabase` singleton.

### `fetchProfile(athleteId: Int) async throws -> MindsetProfile?`

1. Query `athlete_ai_profiles` where `athlete_id = athleteId`, select `core_memory`, use `.maybeSingle()`
2. Extract `core_memory["adlerian_profile"]` as a dictionary
3. Map to `MindsetProfile`. Return `nil` if key is absent or malformed.

### `saveProfile(athleteId: Int, whyIRun: String, coreValues: [String]) async throws -> MindsetProfile`

1. Call `/identity-profile` edge function via `supabase.functions.invoke` with body `{ athlete_id, why_i_run, core_values, mode: "update" }`
2. Decode the response into `MindsetProfile`
3. Throw on network or decode error — caller handles retry UI

### `fetchMilestones(athleteId: Int) async throws -> [RunnerIdentityMilestone]`

1. Query `runner_identity_milestones` where `athlete_id = athleteId`, order by `earned DESC, created_at ASC`
2. Decode as `[RunnerIdentityMilestone]`
3. Return empty array if no rows (not an error)

---

## Onboarding Step (`RunnerMindsetStepView`)

**Position:** Step 6 in `OnboardingContainerView`, inserted before the existing Location Permission step.

**Layout (single screen, two parts):**

**Part 1 — "Why do you run?"**
- Section eyebrow: `WHY I RUN`
- Large `TextEditor` with placeholder "I run to clear my head and feel strong"
- Character limit: 200. Required — Continue button disabled until at least 10 characters entered.

**Part 2 — "What matters most?"**
- Section eyebrow: `WHAT MATTERS MOST`
- Subtitle: "Pick up to 3"
- 10 preset chips in a wrapping `FlowLayout` (or `LazyVGrid` with adaptive columns):
  `consistency` · `mental health` · `stress relief` · `community` · `competition` · `adventure` · `fitness` · `routine` · `solitude` · `speed`
- Tap to select (amber fill + border). Tap again to deselect.
- Selecting a 4th chip deselects the oldest-selected chip automatically.
- At least 1 chip required to enable Continue.

**Continue button behavior:**
1. Show loading spinner, disable button
2. Call `RunnerMindsetService.saveProfile(athleteId:whyIRun:coreValues:)`
3. On success: advance to next onboarding step
4. On failure: show inline error "Couldn't save — tap to retry", re-enable button

**Skip link:** small text link below Continue. Advances without saving. Identity remains unset.

**Visual style:** matches existing onboarding step views — dark background, amber Continue button, step indicator at top.

---

## Profile Tab Changes (`AthleteView.swift`)

New state loaded on `.task`:
```swift
@State private var mindsetProfile: MindsetProfile? = nil
@State private var milestones: [RunnerIdentityMilestone] = []
@State private var mindsetLoadError: Bool = false
@State private var showingEditMindset: Bool = false
```

On `.task`:
```swift
async let profileResult = RunnerMindsetService.fetchProfile(athleteId: athlete.id)
async let milestonesResult = RunnerMindsetService.fetchMilestones(athleteId: athlete.id)
mindsetProfile = try? await profileResult
milestones = (try? await milestonesResult) ?? []
```

### 1. Identity Card (new section, after profile header)

Eyebrow: `MINDSET`

**When `mindsetProfile` is set:**
- Amber-tinted card (`warmAmber` at 8% opacity, amber border at 20% opacity)
- Identity label: bold, 17pt, white (`Consistent Builder`)
- Summary: 13pt, secondary text color, italic (`"You run because it gives you structure and mental clarity."`)
- Tapping the card opens `EditRunnerMindsetView` sheet

**When `mindsetProfile` is nil and no load error:**
- Single prompt row: amber chevron + "Set your running mindset" → opens `EditRunnerMindsetView`

**When load error:**
- Subtle gray row: "Couldn't load · tap to retry" — retry calls `fetchProfile` again

### 2. Milestones Section (after identity card, before LIFETIME)

Eyebrow: `MILESTONES`

Hidden entirely when `milestones.isEmpty` (i.e. `/identity-profile` has never been called for this athlete).

When visible: list of all 6 milestone rows in the order returned (earned first, then unearned).

**Each row:**
- Amber disc icon (32px) filled amber when earned, dark gray when not earned
- Label: 15pt semibold, white when earned, secondary when not
- Description: 12pt, tertiary color
- Trailing: earned date formatted as "MMM d" when earned; "Not yet" (tertiary) when not

Pattern matches `PersonalBestRow` in the existing Profile view.

### 3. ACCOUNT Section Row (existing section)

New row added to the existing ACCOUNT section:
- Icon: `figure.run` (SF Symbol)
- Label: "Running Mindset"
- Subtitle: current identity label if set ("Consistent Builder"), otherwise "Not set"
- Chevron trailing
- Tap → opens `EditRunnerMindsetView` sheet as `.sheet`

---

## `EditRunnerMindsetView` (reusable sheet)

Used from:
- Tapping the identity card in Profile
- Tapping the ACCOUNT row
- "Set your running mindset →" prompt in Profile (when not set)

**Props:** `athleteId: Int`, `existing: MindsetProfile?`, `onSave: (MindsetProfile) -> Void`

**Layout:** same as onboarding step — `WHY I RUN` text field + `WHAT MATTERS MOST` chip picker, pre-populated from `existing` when provided.

**Save behavior:**
1. Loading spinner, Save button disabled
2. Call `RunnerMindsetService.saveProfile`
3. On success: call `onSave(newProfile)`, dismiss sheet
4. On failure: error banner at top of sheet ("Couldn't save — try again"), Save button re-enabled. Sheet stays open.

**Cancel:** dismisses without saving.

---

## Empty States Summary

| Scenario | Behavior |
|---|---|
| No mindset set (new or existing user) | Identity card shows "Set your running mindset →" prompt |
| Milestones table empty (identity-profile never called) | Milestones section hidden |
| Milestones present but none earned | All 6 rows shown, all dimmed, all "Not yet" |
| `fetchProfile` fails | Identity card shows "Couldn't load · tap to retry" |
| `saveProfile` fails in onboarding | Inline error + retry, skip still available |
| `saveProfile` fails in sheet | Error banner, sheet stays open |

---

## Out of Scope (Phase 3+)

| Item | Deferred to |
|---|---|
| Milestone earn detection logic (automatic) | Phase 3 or backend job |
| Adlerian feedback shown in Activity Detail | Phase 3 |
| Audio coach Adlerian voice | Phase 4 |
| Adlerian-aware coach chat UI | Phase 5 |

---

## Success Criteria

- New user completes onboarding → identity card populated in Profile immediately
- Existing user opens Profile → sees "Set your running mindset →" prompt → fills it in → identity card appears
- ACCOUNT row shows current identity label or "Not set"
- Milestones section shows after identity set, hidden before
- `EditRunnerMindsetView` pre-populates existing values on reopen
- `xcodebuild` clean build — no compile errors
