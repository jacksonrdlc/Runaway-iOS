# Phase 4 — Runner Identity Voice Cues

**Date:** 2026-05-07
**Scope:** Phase 4 of 5 — Personalized identity-based voice cues during live runs
**Trigger:** Phase 2 built MindsetProfile; Phase 3 built milestone detection; Phase 4 uses both to personalize the audio coach

---

## What Phase 4 Adds

1. A `generate-run-cues` edge function that calls Claude with the runner's identity profile and milestone status to produce 12 personalized voice cues
2. A `RunCueService` that fetches the cue batch before the run starts
3. Two new cue trigger paths in `RunCoachScheduler`: distance-based (after each split) and slump-based (when pace drops ≥ 20%)
4. One new `CoachSettings` toggle: `enableIdentityVoiceCues`
5. `RunRecordingView` fetches cues on appear and passes them to the scheduler at run start

---

## Naming Convention

No "Adlerian" in any iOS type name, file name, or user-facing string. User-facing labels use "Running Mindset" / "Runner Identity" language.

---

## New Files

| File | Responsibility |
|---|---|
| `runaway-edge/supabase/functions/generate-run-cues/index.ts` | Calls Claude, returns `{ cues: string[] }` |
| `Runaway iOS/Services/RunCueService.swift` | `fetchCues(athleteId:profile:milestones:)` — invokes edge function |

### Modified Files

| File | Change |
|---|---|
| `Runaway iOS/Services/RunCoachScheduler.swift` | Add `loadIdentityCues`, distance trigger, slump detection, 90s cooldown |
| `Runaway iOS/Models/CoachSettings.swift` | Add `enableIdentityVoiceCues: Bool = true` |
| `Runaway iOS/Views/CoachSettingsView.swift` | Add toggle row for identity cues (hidden when no profile) |
| `Runaway iOS/Views/RunRecordingView.swift` | Fetch cues on `.task`, pass to scheduler at run start |

---

## Edge Function: `generate-run-cues`

### Request

```json
{
  "athlete_id": 123,
  "runner_identity": "Consistent Builder",
  "why_i_run": "I run to clear my head and feel strong",
  "core_values": ["consistency", "mental health", "routine"],
  "earned_milestone_keys": ["first_run", "distance_5k", "streak_7"]
}
```

`athlete_id` is included for logging only. Detection uses the provided profile fields.

### Claude Call

- **Model:** `claude-haiku-4-5-20251001` (short structured task, cost-efficient)
- **System prompt:**

```
You are a running coach who knows this runner deeply. Generate exactly 12 short, punchy motivational voice cues for their run today. Each cue is 1–2 sentences. Make them personal to their identity and milestone status. Vary the emotional arc: early cues are grounding (remind them why they're here), mid-run cues are identity-reinforcing (this is who they are), late-run cues are gritty (they've built this, finish strong). Do not use filler phrases like "You've got this" or "Keep it up" — make every cue specific to this runner. Return a JSON object with a single key "cues" containing an array of 12 strings.
```

- **User message:** Provides the runner's identity, why they run, core values, and earned milestone keys. If `earned_milestone_keys` includes `streak_7`, the cues reference consistency. If it includes `comeback`, cues reference returning after a break.

### Response

```json
{ "cues": ["...", "...", "..."] }
```

Exactly 12 strings. If Claude returns fewer than 5 or JSON parsing fails, the function returns HTTP 500. The iOS caller uses `try?` — the run proceeds without identity cues.

### Notes

- Uses `ANTHROPIC_API_KEY` from env (same as other AI edge functions)
- Does not write to the database — pure generation
- `corsHeaders` from `../_shared/cors.ts` as with other edge functions

---

## `RunCueService.swift`

```swift
struct RunCueService {
    static func fetchCues(
        athleteId: Int,
        profile: MindsetProfile,
        milestones: [RunnerIdentityMilestone]
    ) async throws -> [String] {
        struct Request: Encodable {
            let athleteId: Int
            let runnerIdentity: String
            let whyIRun: String
            let coreValues: [String]
            let earnedMilestoneKeys: [String]
            enum CodingKeys: String, CodingKey {
                case athleteId           = "athlete_id"
                case runnerIdentity      = "runner_identity"
                case whyIRun             = "why_i_run"
                case coreValues          = "core_values"
                case earnedMilestoneKeys = "earned_milestone_keys"
            }
        }
        struct Response: Decodable {
            let cues: [String]
        }

        let earnedKeys = milestones.filter { $0.earned }.map { $0.milestoneKey }

        let response: Response = try await supabase.functions.invoke(
            "generate-run-cues",
            options: .init(body: Request(
                athleteId: athleteId,
                runnerIdentity: profile.runnerIdentity,
                whyIRun: profile.whyIRun,
                coreValues: profile.coreValues,
                earnedMilestoneKeys: earnedKeys
            ))
        )
        return response.cues
    }
}
```

---

## `RunCoachScheduler` Changes

### New state

```swift
private var identityCues: [String] = []
private var nextCueIndex: Int = 0
private var lastCueFiredAt: Date? = nil
private var paceWindow: [(timestamp: Date, paceSecondsPerMeter: Double)] = []
```

### New method

```swift
func loadIdentityCues(_ cues: [String]) {
    identityCues = cues
    nextCueIndex = 0
    lastCueFiredAt = nil
}
```

### Distance trigger (in `announceSplit`)

After the existing split announcement, queue an identity cue 3 seconds later:

```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
    self?.fireNextIdentityCue()
}
```

### Slump detection (in `update(distance:elapsedTime:)`)

Append current pace to `paceWindow`. Trim entries older than 2 minutes. When the window covers ≥ 2 minutes:

```swift
let recent = paceWindow.filter { $0.timestamp > Date().addingTimeInterval(-30) }
let prior  = paceWindow.filter { $0.timestamp <= Date().addingTimeInterval(-30) }
guard !recent.isEmpty, !prior.isEmpty else { return }
let recentAvg = recent.map(\.paceSecondsPerMeter).reduce(0, +) / Double(recent.count)
let priorAvg  = prior.map(\.paceSecondsPerMeter).reduce(0, +)  / Double(prior.count)
if recentAvg > priorAvg * 1.20 {
    fireNextIdentityCue()
}
```

### `fireNextIdentityCue()`

```swift
private func fireNextIdentityCue() {
    guard !identityCues.isEmpty else { return }
    guard nextCueIndex < identityCues.count else { return }
    if let last = lastCueFiredAt, Date().timeIntervalSince(last) < 90 { return }
    announcer.speakCue(identityCues[nextCueIndex])
    lastCueFiredAt = Date()
    nextCueIndex += 1
}
```

---

## `CoachSettings` Change

Add one stored property:

```swift
@AppStorage("enableIdentityVoiceCues") var enableIdentityVoiceCues: Bool = true
```

---

## `CoachSettingsView` Change

In the existing settings list, add a toggle row (only when a `MindsetProfile` is available):

```swift
if mindsetProfile != nil {
    Toggle(isOn: $settings.enableIdentityVoiceCues) {
        VStack(alignment: .leading, spacing: 2) {
            Text("Runner Identity Cues")
            Text("Personalized cues based on your running mindset")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
```

`CoachSettingsView` needs a `mindsetProfile: MindsetProfile?` prop passed from its caller.

---

## `RunRecordingView` Changes

On `.task`:

```swift
async let profileResult   = RunnerMindsetService.fetchProfile(athleteId: athleteId)
async let milestonesResult = RunnerMindsetService.fetchMilestones(athleteId: athleteId)

let profile    = try? await profileResult
let milestones = (try? await milestonesResult) ?? []

if let profile, coachSettings.isEnabled, coachSettings.enableIdentityVoiceCues {
    identityCues = (try? await RunCueService.fetchCues(
        athleteId: athleteId,
        profile: profile,
        milestones: milestones
    )) ?? []
}
```

When the runner taps Start (wherever `RunCoachScheduler.start()` is called):

```swift
scheduler.loadIdentityCues(identityCues)
```

New state var: `@State private var identityCues: [String] = []`

---

## Data Flow

```
RunRecordingView.task
  → RunnerMindsetService.fetchProfile + fetchMilestones (concurrent)
  → RunCueService.fetchCues (if profile set + cues enabled)
      → generate-run-cues edge function
          → Claude (claude-haiku-4-5): 12 personalized cues
          → returns { cues: [...] }
  → identityCues stored in @State

Runner taps Start
  → RunCoachScheduler.start()
  → scheduler.loadIdentityCues(identityCues)

During run (distance boundary):
  → announceSplit fires split announcement
  → 3s later: fireNextIdentityCue() if cooldown clear

During run (pace slump):
  → update() detects recent pace ≥ 20% slower than prior 90s
  → fireNextIdentityCue() if cooldown clear

fireNextIdentityCue():
  → guard: cues non-empty, index in bounds, cooldown > 90s
  → AudioCueService.speakCue(identityCues[nextCueIndex])
  → advance index, record timestamp
```

---

## Empty States & Error Handling

| Scenario | Behavior |
|---|---|
| No `MindsetProfile` set | Fetch skipped; no identity cues; splits unaffected |
| `enableIdentityVoiceCues = false` | Fetch skipped |
| `fetchCues` throws | `identityCues = []`; run proceeds normally |
| Claude returns < 5 cues or malformed JSON | Edge function returns 500; iOS `try?` → empty array |
| Cue array exhausted mid-run | No more identity cues; splits continue unaffected |
| Slump fires within 90s of last cue | Cooldown guard suppresses it |
| Run starts before fetch completes | `identityCues = []` at start; no cues for that run |

---

## Out of Scope (Phase 5)

| Item | Deferred to |
|---|---|
| Adlerian-aware coach chat UI | Phase 5 |
| Dynamic mid-run cue regeneration | Future |
| Heart-rate-zone-based cue triggers | Future |

---

## Success Criteria

- Runner with a `MindsetProfile` starts a run → identity cues play after each split, personalized to their identity and milestone status
- Runner without a profile → no identity cues, splits work exactly as before
- Pace drops 20% → next identity cue fires (subject to 90s cooldown)
- `enableIdentityVoiceCues = false` → no cues fetched, no cues played
- `xcodebuild` clean build — no compile errors
