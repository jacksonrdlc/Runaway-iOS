# Phase 5 — Identity-Aware Coach Chat

**Date:** 2026-05-07
**Scope:** Phase 5 of 5 — Wire MindsetProfile + earned milestones into the on-device Foundation Models chat
**Trigger:** Phase 2 built MindsetProfile; Phase 3 built milestone detection; Phase 5 uses both to personalize the AI coach chat

---

## What Phase 5 Adds

1. `ChatViewModel` loads `MindsetProfile` and earned milestones from Supabase on appear
2. A new `RunnerIdentityContext` struct in `FoundationModelsService` carries identity data into the system prompt
3. `buildRunningCoachSystemPrompt` gains an identity block when a profile is present
4. The proactive greeting references the runner's identity when a profile exists
5. Suggested prompts include one identity-anchored option when a profile exists

No new files. No new edge functions. Behavior is identical to today when no profile is set.

---

## Naming Convention

No "Adlerian" in any iOS type name, file name, or user-facing string. User-facing labels use "Running Mindset" / "Runner Identity" language.

---

## Modified Files Only

| File | Change |
|---|---|
| `Runaway iOS/ViewModels/ChatViewModel.swift` | Add `mindsetProfile` + `earnedMilestones` state; fetch on appear; pass to `generateCoachResponse`; update greeting + suggested prompts |
| `Runaway iOS/Services/FoundationModels/FoundationModelsService.swift` | Add `RunnerIdentityContext` struct; extend `generateCoachResponse` signature; extend `buildRunningCoachSystemPrompt` with identity block |

---

## `FoundationModelsService` Changes

### New struct

```swift
struct RunnerIdentityContext {
    let runnerIdentity: String
    let whyIRun: String
    let coreValues: [String]
    let earnedMilestoneKeys: [String]
}
```

### Extended `generateCoachResponse` signature

```swift
func generateCoachResponse(
    message: String,
    athleteContext: AthleteContext? = nil,
    recentActivities: [ActivitySummary]? = nil,
    identityContext: RunnerIdentityContext? = nil
) async throws -> String {
    let systemPrompt = buildRunningCoachSystemPrompt(
        athleteContext: athleteContext,
        recentActivities: recentActivities,
        identityContext: identityContext
    )
    return try await generateResponse(prompt: message, systemPrompt: systemPrompt, maxTokens: 2048)
}
```

The existing callers pass no `identityContext` argument — the default `nil` means no behaviour change for them.

### Identity block in `buildRunningCoachSystemPrompt`

After the existing athlete and activity sections, append when `identityContext != nil`:

```
Runner Identity:
- They identify as: <runnerIdentity>
- Why they run: <whyIRun>
- Core values: <coreValues joined by ", ">
- Earned milestones: <earnedMilestoneKeys joined by ", ">
Use this identity when they ask about motivation, struggle, or what kind of runner they are. Do not recite these facts back to them unprompted — let them inform the tone and framing of your responses.
```

---

## `ChatViewModel` Changes

### New state

```swift
private var mindsetProfile: MindsetProfile? = nil
private var earnedMilestones: [RunnerIdentityMilestone] = []
```

### Fetch on appear

Inside `generateProactiveGreeting()`, before the greeting is built, add a concurrent fetch (guarded by athlete ID):

```swift
if let athleteId = DataManager.shared.athlete?.id {
    async let profileFetch = RunnerMindsetService.fetchProfile(athleteId: athleteId)
    async let milestonesFetch = RunnerMindsetService.fetchMilestones(athleteId: athleteId)
    mindsetProfile = try? await profileFetch
    earnedMilestones = ((try? await milestonesFetch) ?? []).filter { $0.earned }
}
```

Both fetches are `try?` — if either fails the session continues without identity context.

### Pass identity into `generateCoachResponse`

In `ChatViewModel.sendMessage(_:)`, build the identity context and pass it:

```swift
let identityContext: RunnerIdentityContext? = mindsetProfile.map { profile in
    RunnerIdentityContext(
        runnerIdentity: profile.runnerIdentity,
        whyIRun: profile.whyIRun,
        coreValues: profile.coreValues,
        earnedMilestoneKeys: earnedMilestones.map { $0.milestoneKey }
    )
}

let response = try await foundationModelsService.generateCoachResponse(
    message: text,
    athleteContext: athleteContext,
    recentActivities: recentActivities,
    identityContext: identityContext
)
```

### Identity-aware greeting

In `buildFallbackGreeting()`, when `mindsetProfile != nil`, prefix the greeting with an identity line:

**With profile (example — Consistent Builder, 3 runs this week):**
```
You're a Consistent Builder — and the data backs that up.

3 runs this week. You're showing up, which is exactly how that identity gets built.

What's on your mind?
```

**With profile, no runs this week:**
```
You're a Consistent Builder — and rest is part of that.

It's been quiet this week. Sometimes that's intentional, sometimes life just happens. Either way, you're still here.

What's going on?
```

**No profile:** unchanged from today.

Implementation: replace the `if thisWeekCount > 0` branch with a check for `mindsetProfile` first. If profile exists, use identity-prefixed variants. If no profile, fall through to existing generic greeting.

### Identity-aware suggested prompts

`suggestedPrompts` currently returns hardcoded arrays. When `mindsetProfile != nil`, replace one generic prompt with an identity-anchored prompt:

```swift
var suggestedPrompts: [String] {
    if messages.isEmpty {
        var prompts = [
            "How am I doing with my training?",
            "What should my easy run pace be?",
            "Can you analyze my recent runs?",
            "Create a training plan for me"
        ]
        if let profile = mindsetProfile {
            prompts[3] = "What does being a \(profile.runnerIdentity) actually mean for my training?"
        }
        return prompts
    } else {
        return [
            "Tell me more",
            "What else should I focus on?",
            "How can I improve?"
        ]
    }
}
```

---

## Data Flow

```
ChatView.task
  → ChatViewModel.generateProactiveGreeting()
      → RunnerMindsetService.fetchProfile + fetchMilestones (concurrent, try?)
      → mindsetProfile, earnedMilestones stored on ChatViewModel
      → buildFallbackGreeting() uses identity if profile present

User sends message
  → ChatViewModel.sendMessage(_:)
      → build RunnerIdentityContext from mindsetProfile (nil if no profile)
      → FoundationModelsService.generateCoachResponse(..., identityContext: context)
          → buildRunningCoachSystemPrompt includes identity block if context non-nil
          → LanguageModelSession responds with identity-informed tone
```

---

## Empty States & Error Handling

| Scenario | Behavior |
|---|---|
| No `MindsetProfile` set | Fetch skipped; identity context nil; chat identical to today |
| `fetchProfile` throws | `try?` → nil → no identity context; chat continues normally |
| `fetchMilestones` throws | `try?` → empty array; identity context uses empty milestone keys |
| Foundation Models unavailable (< iOS 26) | Upgrade banner shown as before; identity fetch never attempted |
| `mindsetProfile` present but `earnedMilestones` empty | Identity block still included; milestone line omitted or shows "none yet" |

---

## Out of Scope

| Item | Notes |
|---|---|
| Persisting chat history to Supabase | Not in scope; sessions are ephemeral |
| Mid-conversation profile refresh | Profile fetched once per session; stale if user updates profile during chat |
| Cloud fallback for chat (non-iOS 26 devices) | Deferred by design |
| Milestone-specific suggested prompts (e.g., "You just hit streak_7") | Future iteration |

---

## Success Criteria

- Runner with a `MindsetProfile` opens chat → greeting names their runner identity
- Runner sends a message → system prompt includes identity block; coach tone reflects identity without reciting facts unprompted
- Runner without a profile → chat behavior identical to today
- `fetchProfile` throws → chat continues without error, no identity context
- `xcodebuild` clean build — no compile errors
