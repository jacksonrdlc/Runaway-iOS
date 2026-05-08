# Phase 4 — Runner Identity Voice Cues Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate 12 personalized voice cues from the runner's identity profile before each run, then play them during the run at mile/km split boundaries and when pace slumps by ≥ 20%.

**Architecture:** A new `generate-run-cues` Deno edge function calls Claude (Haiku) with the runner's MindsetProfile and earned milestone keys to produce 12 cues. `RunCueService` invokes the edge function before the run. `RunCoachScheduler` gains identity cue state, a distance trigger (3s after each split), a slump detector (rolling 2-min pace window), and a 90-second cooldown guard. `RunRecordingView` fetches the cue batch on `.task` and passes it to the scheduler at run start.

**Tech Stack:** Swift 5.9, SwiftUI, Deno/TypeScript edge functions, Anthropic Haiku API (`claude-haiku-4-5-20251001`), Supabase iOS SDK (global `supabase` singleton), `AVSpeechSynthesizer` (via existing `AudioCueService`).

---

## File Map

| Action | File |
|--------|------|
| Create | `runaway-edge/supabase/functions/generate-run-cues/index.ts` |
| Create | `Runaway iOS/Runaway iOS/Services/RunCueService.swift` |
| Modify | `Runaway iOS/Runaway iOS/Models/CoachSettings.swift` |
| Modify | `Runaway iOS/Runaway iOS/Views/CoachSettingsView.swift` |
| Modify | `Runaway iOS/Runaway iOS/Services/RunCoachScheduler.swift` |
| Modify | `Runaway iOS/Runaway iOS/Views/RunRecordingView.swift` |

---

## Task 1: `generate-run-cues` edge function

**Files:**
- Create: `runaway-edge/supabase/functions/generate-run-cues/index.ts`

**Working directory:** `/Users/jack.rudelic/projects/labs/runaway/runaway-edge`

This edge function accepts the runner's identity profile and earned milestone keys, calls Claude Haiku to generate 12 personalized cues, and returns `{ cues: string[] }`. Uses the same `ANTHROPIC_API_KEY` and `corsHeaders` pattern as existing edge functions (`feedback-workout`, `identity-profile`).

- [ ] **Step 1: Create the function file**

```typescript
// runaway-edge/supabase/functions/generate-run-cues/index.ts
import Anthropic from 'npm:@anthropic-ai/sdk'
import { corsHeaders } from '../_shared/cors.ts'

const NUM_CUES = 12
const MIN_CUES = 5

const anthropic = new Anthropic({
  apiKey: Deno.env.get('ANTHROPIC_API_KEY') ?? '',
})

const SYSTEM_PROMPT = `You are a running coach who knows this runner deeply. Generate exactly ${NUM_CUES} short, punchy motivational voice cues for their run today. Each cue is 1–2 sentences. Make them personal to their identity and milestone status. Vary the emotional arc: early cues are grounding (remind them why they are here), mid-run cues are identity-reinforcing (this is who they are), late-run cues are gritty (they have built this, finish strong). Do not use filler phrases like "You've got this" or "Keep it up" — make every cue specific to this runner. Return a JSON object with a single key "cues" containing an array of ${NUM_CUES} strings.`

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders })
  }

  try {
    const { athlete_id, runner_identity, why_i_run, core_values, earned_milestone_keys } = await req.json()

    if (!runner_identity || !why_i_run) {
      return new Response(
        JSON.stringify({ error: { code: 'INVALID_REQUEST', message: 'runner_identity and why_i_run are required' } }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const milestoneText = Array.isArray(earned_milestone_keys) && earned_milestone_keys.length > 0
      ? `Earned milestones: ${(earned_milestone_keys as string[]).join(', ')}`
      : 'No milestones earned yet — this may be an early run.'

    const userMessage = [
      `Runner identity: ${runner_identity}`,
      `Why they run: ${why_i_run}`,
      `Core values: ${Array.isArray(core_values) ? (core_values as string[]).join(', ') : 'not specified'}`,
      milestoneText,
    ].join('\n')

    const message = await anthropic.messages.create({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 1024,
      system: SYSTEM_PROMPT,
      messages: [{ role: 'user', content: userMessage }],
    })

    const responseText = message.content[0].type === 'text' ? message.content[0].text : ''

    let cues: string[]
    try {
      const parsed = JSON.parse(responseText)
      cues = parsed.cues
      if (!Array.isArray(cues) || cues.length < MIN_CUES) {
        throw new Error('Invalid cues array')
      }
    } catch {
      console.error('Failed to parse Claude response:', responseText)
      return new Response(
        JSON.stringify({ error: { code: 'PARSE_ERROR', message: 'Failed to parse cues from Claude' } }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log('generate-run-cues complete:', { athlete_id, cue_count: cues.length })

    return new Response(
      JSON.stringify({ cues }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error in generate-run-cues:', error)
    return new Response(
      JSON.stringify({ error: { code: 'INTERNAL_ERROR', message: 'Internal server error' } }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
```

- [ ] **Step 2: Verify file created**

```bash
ls supabase/functions/generate-run-cues/index.ts
```

Expected: file listed.

- [ ] **Step 3: Deploy**

```bash
supabase functions deploy generate-run-cues
```

Expected: output ends with `generate-run-cues: deployed`. If auth error, run `supabase login` first.

- [ ] **Step 4: Commit**

```bash
cd /Users/jack.rudelic/projects/labs/runaway/runaway-edge
git add supabase/functions/generate-run-cues/index.ts
git commit -m "feat: add generate-run-cues edge function for runner identity voice cues"
```

---

## Task 2: `RunCueService.swift`

**Files:**
- Create: `Runaway iOS/Runaway iOS/Services/RunCueService.swift`

**Working directory:** `/Users/jack.rudelic/projects/labs/runaway/Runaway iOS`

Thin wrapper that invokes `generate-run-cues` with the runner's profile and earned milestones and returns `[String]`. Follows the same pattern as `MilestoneService.swift` and `ActivityInsightService.swift` already in `Services/`.

- [ ] **Step 1: Create the file**

```swift
// Runaway iOS/Services/RunCueService.swift
import Foundation

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

- [ ] **Step 2: Commit**

```bash
git add "Runaway iOS/Services/RunCueService.swift"
git commit -m "feat: add RunCueService to fetch personalized run cues before a run"
```

---

## Task 3: Add `enableIdentityVoiceCues` to `CoachSettings` and `CoachSettingsView`

**Files:**
- Modify: `Runaway iOS/Runaway iOS/Models/CoachSettings.swift`
- Modify: `Runaway iOS/Runaway iOS/Views/CoachSettingsView.swift`

`CoachSettings` is a `Codable` struct stored as JSON in `UserDefaults` via `CoachSettingsStore`. Adding a new `Bool` property with a default value is not automatically backward-compatible with Swift's synthesized `Decodable` — if the JSON on disk is missing the key, decoding will fail and `CoachSettingsStore` will fall back to `CoachSettings()` (all defaults). This is acceptable for a dev-stage app with no external users; the runner's settings reset to defaults on the first launch after this update.

- [ ] **Step 1: Read `CoachSettings.swift` to find the Voice Settings section**

Open `Runaway iOS/Models/CoachSettings.swift`. The Voice Settings section begins with `// MARK: - Voice Settings`.

- [ ] **Step 2: Add `enableIdentityVoiceCues` property**

In `CoachSettings`, after the `// MARK: - Voice Settings` comment (before `speechRate`), add:

```swift
    // MARK: - Identity Voice Cues

    /// Play personalized identity cues during runs (requires MindsetProfile to be set)
    var enableIdentityVoiceCues: Bool = true
```

- [ ] **Step 3: Read `CoachSettingsView.swift` to find the Form's sections**

Open `Runaway iOS/Views/CoachSettingsView.swift`. The `Form { }` contains sections for splits, pace alerts, heart rate zones, check-ins, voice, voice input, target pace, and distance units.

- [ ] **Step 4: Add state var to `CoachSettingsView`**

After `@Environment(\.dismiss) private var dismiss`, add:

```swift
    @State private var hasMindsetProfile: Bool = false
```

- [ ] **Step 5: Add the toggle section to the Form**

After the `Section("Split Announcements") { ... }` closing brace and before the pace alerts section, add:

```swift
                if hasMindsetProfile {
                    Section {
                        Toggle("Runner Identity Cues", isOn: $store.settings.enableIdentityVoiceCues)
                    } footer: {
                        Text("Personalized voice cues based on your running mindset, generated before each run.")
                    }
                }
```

- [ ] **Step 6: Add `.task` to load the profile check**

After the closing brace of the `Form { }` block (before `.navigationTitle`), add:

```swift
            .task {
                if let athleteId = DataManager.shared.athlete?.id {
                    hasMindsetProfile = (try? await RunnerMindsetService.fetchProfile(athleteId: athleteId)) != nil
                }
            }
```

- [ ] **Step 7: Commit**

```bash
git add "Runaway iOS/Models/CoachSettings.swift"
git add "Runaway iOS/Views/CoachSettingsView.swift"
git commit -m "feat: add enableIdentityVoiceCues setting with toggle in Coach Settings"
```

---

## Task 4: Extend `RunCoachScheduler` with identity cue state, slump detection, and distance trigger

**Files:**
- Modify: `Runaway iOS/Runaway iOS/Services/RunCoachScheduler.swift`

**Depends on:** Task 3 (references `settings.enableIdentityVoiceCues` which is added there).

`RunCoachScheduler` is a `@MainActor final class` with `private` state. All additions are private except `loadIdentityCues(_:)`. The existing `update(distance:elapsedTime:)` and `announceSplit` methods are modified in-place.

- [ ] **Step 1: Read `RunCoachScheduler.swift` in full**

Open `Runaway iOS/Services/RunCoachScheduler.swift`. Locate:
1. The `// MARK: - Private State` block (contains `isActive`, `lastAnnouncedUnit`, `elapsedAtLastUnit`)
2. The `start()` method
3. The `stop()` method
4. The `update(distance:elapsedTime:)` method
5. The `announceSplit(unit:splitDuration:)` method

- [ ] **Step 2: Add new private state**

After the existing private state variables (`private var elapsedAtLastUnit: TimeInterval = 0`), add:

```swift
    // Identity cue state
    private var identityCues: [String] = []
    private var nextCueIndex: Int = 0
    private var lastCueFiredAt: Date? = nil

    // Slump detection
    private var paceWindow: [(timestamp: Date, paceSecondsPerMeter: Double)] = []
    private var lastUpdateDistance: Double = 0
    private var lastUpdateTime: TimeInterval = 0
```

- [ ] **Step 3: Add `loadIdentityCues(_:)` method**

After the `stop()` method (before `// MARK: - Distance Updates`), add:

```swift
    // MARK: - Identity Cues

    /// Load a pre-generated cue batch before the run starts. Call after `start()`.
    func loadIdentityCues(_ cues: [String]) {
        identityCues = cues
        nextCueIndex = 0
        lastCueFiredAt = nil
    }
```

- [ ] **Step 4: Update `start()` to reset slump state**

In `start()`, after `elapsedAtLastUnit = 0`, add:

```swift
        nextCueIndex = 0
        lastCueFiredAt = nil
        paceWindow = []
        lastUpdateDistance = 0
        lastUpdateTime = 0
```

Do NOT reset `identityCues` in `start()` — the caller loads cues after `start()` via `loadIdentityCues`.

- [ ] **Step 5: Update `stop()` to reset all identity cue state**

In `stop()`, after `elapsedAtLastUnit = 0`, add:

```swift
        identityCues = []
        nextCueIndex = 0
        lastCueFiredAt = nil
        paceWindow = []
        lastUpdateDistance = 0
        lastUpdateTime = 0
```

- [ ] **Step 6: Update `update(distance:elapsedTime:)` to accumulate pace samples**

The current method body begins with two `guard` statements. Add pace window accumulation between the first guard and the existing split-announcement guard. Replace the entire method body with:

```swift
    func update(distance: Double, elapsedTime: TimeInterval) {
        guard isActive, settings.isEnabled else { return }

        // Accumulate pace samples for slump detection (independent of split setting)
        updatePaceWindow(distance: distance, elapsedTime: elapsedTime)

        guard settings.announceSplits, settings.splitDetail != .off else { return }

        let unitMeters = settings.distanceUnit.metersPerUnit
        let currentUnit = Int(distance / unitMeters)

        while currentUnit > lastAnnouncedUnit {
            let completedUnit = lastAnnouncedUnit + 1
            let splitDuration = elapsedTime - elapsedAtLastUnit
            announceSplit(unit: completedUnit, splitDuration: splitDuration)
            lastAnnouncedUnit = completedUnit
            elapsedAtLastUnit = elapsedTime
        }
    }
```

- [ ] **Step 7: Add `updatePaceWindow` and `detectSlump` private methods**

After `announceSplit` (before `formatPace`), add:

```swift
    private func updatePaceWindow(distance: Double, elapsedTime: TimeInterval) {
        let deltaDistance = distance - lastUpdateDistance
        let deltaTime = elapsedTime - lastUpdateTime
        lastUpdateDistance = distance
        lastUpdateTime = elapsedTime

        guard deltaDistance > 2.0, deltaTime > 0 else { return }

        let pace = deltaTime / deltaDistance
        paceWindow.append((timestamp: Date(), paceSecondsPerMeter: pace))
        let cutoff = Date().addingTimeInterval(-120)
        paceWindow.removeAll { $0.timestamp < cutoff }

        if settings.enableIdentityVoiceCues {
            detectSlump()
        }
    }

    private func detectSlump() {
        let recentCutoff = Date().addingTimeInterval(-30)
        let recent = paceWindow.filter { $0.timestamp >= recentCutoff }
        let prior  = paceWindow.filter { $0.timestamp <  recentCutoff }
        guard !recent.isEmpty, !prior.isEmpty else { return }

        let recentAvg = recent.map(\.paceSecondsPerMeter).reduce(0, +) / Double(recent.count)
        let priorAvg  = prior.map(\.paceSecondsPerMeter).reduce(0,  +) / Double(prior.count)

        if recentAvg > priorAvg * 1.20 {
            fireNextIdentityCue()
        }
    }

    private func fireNextIdentityCue() {
        guard !identityCues.isEmpty else { return }
        guard nextCueIndex < identityCues.count else { return }
        if let last = lastCueFiredAt, Date().timeIntervalSince(last) < 90 { return }
        announcer.speakCue(identityCues[nextCueIndex])
        lastCueFiredAt = Date()
        nextCueIndex += 1
    }
```

- [ ] **Step 8: Update `announceSplit` to queue an identity cue 3 seconds later**

In `announceSplit(unit:splitDuration:)`, after `announcer.speakCue(message)` and before the `AnalyticsService` call, add:

```swift
        if settings.enableIdentityVoiceCues {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.fireNextIdentityCue()
            }
        }
```

- [ ] **Step 9: Commit**

```bash
git add "Runaway iOS/Services/RunCoachScheduler.swift"
git commit -m "feat: add identity cue scheduling and slump detection to RunCoachScheduler"
```

---

## Task 5: Integrate cue fetch into `RunRecordingView`

**Files:**
- Modify: `Runaway iOS/Runaway iOS/Views/RunRecordingView.swift`

`RunRecordingView` has no `.task` modifier today. This task adds one that fetches the cue batch before the run starts, and passes the cues to `RunCoachScheduler.shared` when the Start button is tapped.

- [ ] **Step 1: Read `RunRecordingView.swift` in full**

Open `Runaway iOS/Views/RunRecordingView.swift`. Locate:
1. The `@State private var showingCancelAlert` declaration
2. The `ZStack { }` that forms the view body
3. The Start button (`Button { Task { await recorder.start() } }`)

- [ ] **Step 2: Add `identityCues` state var**

After `@State private var showingCancelAlert = false`, add:

```swift
    @State private var identityCues: [String] = []
```

- [ ] **Step 3: Add `.task` modifier to the `ZStack`**

After the `.alert("Discard this run?", ...)` modifier (the last modifier on the `ZStack`), add:

```swift
        .task {
            guard let athleteId = DataManager.shared.athlete?.id else { return }
            let settings = CoachSettingsStore.shared.settings
            guard settings.isEnabled, settings.enableIdentityVoiceCues else { return }

            async let profileFetch    = RunnerMindsetService.fetchProfile(athleteId: athleteId)
            async let milestonesFetch = RunnerMindsetService.fetchMilestones(athleteId: athleteId)

            let profile    = try? await profileFetch
            let milestones = (try? await milestonesFetch) ?? []

            if let profile {
                identityCues = (try? await RunCueService.fetchCues(
                    athleteId: athleteId,
                    profile: profile,
                    milestones: milestones
                )) ?? []
            }
        }
```

- [ ] **Step 4: Update the Start button to pass cues to the scheduler**

Find the Start button in `startScreen`:

```swift
            Button {
                Task { await recorder.start() }
            } label: {
```

Replace the `Task` body with:

```swift
            Button {
                Task {
                    await recorder.start()
                    RunCoachScheduler.shared.loadIdentityCues(identityCues)
                }
            } label: {
```

`loadIdentityCues` is called after `recorder.start()` because `recorder.start()` internally calls `RunCoachScheduler.shared.start()` which resets the cue index. Loading cues after ensures the index starts at 0 with the correct batch. The first split fires after a full mile — well after the millisecond gap between these two calls.

- [ ] **Step 5: Commit**

```bash
git add "Runaway iOS/Views/RunRecordingView.swift"
git commit -m "feat: fetch identity cue batch before run and pass to RunCoachScheduler at start"
```

---

## Task 6: Build verification

**Files:** (no changes — verification only)

- [ ] **Step 1: Build the iOS app**

```bash
cd "/Users/jack.rudelic/projects/labs/runaway/Runaway iOS"
xcodebuild -project "Runaway iOS.xcodeproj" \
    -scheme "Runaway iOS" \
    -destination "id=9989C246-EED8-4A64-A9D3-7E9915AD12F0" \
    build 2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED|RunCueService|generate-run-cues)" | head -30
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 2: If build fails, diagnose**

**`RunCueService` not found / `enableIdentityVoiceCues` not found**: New file not added to Xcode target. Add it via Xcode (drag into project navigator, check target membership) or verify file is in the correct directory.

**`settings.enableIdentityVoiceCues` not found in `RunCoachScheduler`**: Task 3 must complete before Task 4. Confirm `CoachSettings.swift` has the new property.

**`DataManager.shared.athlete` not found**: `DataManager` may expose the athlete differently. Read `Runaway iOS/Managers/DataManager.swift` and find the correct property name for the current athlete.

**`RunCoachScheduler.shared.loadIdentityCues` not found**: Confirm Task 4 completed and the method was added as non-private (no `private` modifier).

- [ ] **Step 3: Commit any build fixes**

```bash
git add -u
git commit -m "fix: resolve Phase 4 build errors"
```

---

## Self-Review

**Spec coverage:**
- ✅ `generate-run-cues` edge function with Claude Haiku, 12 cues, identity + milestones input (Task 1)
- ✅ `RunCueService.fetchCues` invokes edge function, maps MindsetProfile + milestones to request (Task 2)
- ✅ `enableIdentityVoiceCues: Bool = true` in CoachSettings (Task 3)
- ✅ CoachSettingsView toggle hidden when no MindsetProfile (Task 3)
- ✅ `loadIdentityCues`, `fireNextIdentityCue`, distance trigger (3s after split), slump detection (Task 4)
- ✅ 90-second cooldown guard in `fireNextIdentityCue` (Task 4)
- ✅ `RunRecordingView` fetches cues on `.task`, passes to scheduler at Start (Task 5)
- ✅ Cue fetch skipped when `isEnabled = false` or `enableIdentityVoiceCues = false` (Task 5)
- ✅ All error paths use `try?` → silent fallback, run proceeds without identity cues

**No placeholders found.**

**Type consistency:**
- `loadIdentityCues(_ cues: [String])` defined in Task 4, called in Task 5 ✅
- `RunCueService.fetchCues(athleteId:profile:milestones:)` defined in Task 2, called in Task 5 ✅
- `settings.enableIdentityVoiceCues` defined in Task 3, referenced in Tasks 4 and 5 ✅
- `MindsetProfile` and `RunnerIdentityMilestone` defined in Phase 2 (`MindsetModels.swift`) ✅
- `RunnerMindsetService.fetchProfile` and `fetchMilestones` defined in Phase 2 ✅
