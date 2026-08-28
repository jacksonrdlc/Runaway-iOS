# Training Profile and Complementary Scheduling Design

**Date:** August 27, 2026  
**Status:** Proposed for implementation review

## Purpose

Runaway currently builds a running-first weekly plan. It can display strength, mobility, yoga, and cross-training workouts already present in a plan, but it does not know which activities a person wants to train, how important each activity is, or how those activities should complement one another.

This feature introduces a persistent Fitness Profile and a deterministic complementary scheduler. The app will use the profile to build balanced weekly plans and choose useful Next Up recommendations without diluting its running intelligence.

## Product Principles

1. Running remains the plan's anchor when the user selects it as a primary activity.
2. Supporting activities protect and improve the primary goal instead of competing with it.
3. Every recommendation explains why it appears on that day.
4. Readiness changes intensity and workout selection, not the user's long-term goals.
5. The scheduling rules are local, deterministic, testable, and do not require an external LLM.
6. Existing users keep a valid plan and are invited to personalize it without being blocked.

## Fitness Profile

### Activity Selection

The profile supports these activities:

- Running
- Strength training
- Cycling
- Swimming
- Walking or hiking
- Mobility or yoga

Each selected activity has one role:

- **Primary:** the activity whose progression and events drive the plan.
- **Supporting:** scheduled regularly to improve or protect primary training.
- **Optional:** offered as an alternative when it fits recovery, readiness, and available time.

Version one allows one primary activity. This keeps race-plan progression understandable while still supporting mixed training. Additional primary sports and true multisport periodization are outside this version.

### Preferences

The profile records:

- Total training days per week
- Selected activities and their roles
- Desired sessions per week for each selected activity
- Strength equipment: bodyweight, dumbbells, full gym, or unspecified
- Strength experience: beginner, intermediate, or advanced
- Preferred long-run day
- Days unavailable for training

The existing distance unit preference remains the source of truth for miles or kilometers. The Fitness Profile does not create a second unit setting.

### Persistence and Migration

The profile is stored locally using a versioned Codable model. A version field allows future migrations without invalidating saved plans.

Existing users receive a conservative default profile:

- Running is primary.
- Strength is supporting when their current plan already contains strength sessions.
- Mobility is optional.
- Existing weekly frequency and preferred long-run day are preserved when available.

The app shows a dismissible personalization prompt on Today and in Training Preferences. Dismissing it keeps the migrated default and does not interrupt the current plan.

## User Experience

### Onboarding

Onboarding adds a focused "How do you want to train?" step after the user's primary goal is established.

The step uses compact selectable activity rows rather than a dense settings form. Selecting an activity reveals a role control and a weekly frequency control. Running is preselected as primary for race and running-goal onboarding paths.

A second lightweight step collects schedule constraints:

- Training days per week
- Preferred long-run day
- Unavailable days
- Strength equipment, only when strength is selected

The summary states the intended mix in plain language, for example: "4 runs + 2 strength sessions, with your long run on Sunday."

### Settings

`You > Training preferences` gains a Fitness Profile section. It uses the same activity and schedule controls as onboarding so behavior cannot drift between the two entry points.

Saving a material profile change presents two clear choices:

- **Update next week:** preserve the current week and regenerate from the following week.
- **Rebalance this week:** preserve completed workouts and safely rebuild only remaining days.

The recommended default is Update next week. The app never silently replaces completed workouts or the current day's completed activity.

### Today and Next Up

Next Up continues to show the workout scheduled for today. Its fallback and readiness alternatives become profile-aware.

Examples:

- After a long run, a strength user may see upper-body strength or mobility.
- After intervals or hills, heavy lower-body strength is avoided.
- Before a long run, demanding lower-body work is avoided.
- With low readiness, a cyclist may receive an easy spin and a runner may receive mobility or recovery instead of another run.
- When no selected supporting activity is appropriate, the app recommends rest or mobility rather than inventing an unsupported workout.

Every non-obvious recommendation includes a short reason, such as "Placed after yesterday's long run to preserve leg recovery."

The workout-type badge uses the workout's display name, never its raw storage value, so labels such as `Easy_Run` cannot appear in the interface.

## Scheduling Architecture

### Components

#### TrainingProfile

A versioned value model containing activity roles, frequencies, equipment, experience, and schedule constraints. It owns validation such as preventing zero primary activities and impossible weekly totals.

#### TrainingProfileStore

A single observable local store responsible for loading, migrating, validating, and saving the profile. Onboarding, Settings, plan generation, and Today consume the same store.

#### ComplementarySchedulingPolicy

A pure deterministic policy that scores candidate workout types for a date. Inputs include:

- Fitness Profile
- Current weekly plan
- Completed recent workouts
- Race phase and race date
- Readiness recommendation
- Day availability

The policy returns a ranked candidate list with machine-readable reasons. It does not mutate plans or access persistence.

#### TrainingPlanService Integration

The local plan generator requests candidates from the scheduling policy, then creates the final daily workouts. Running progression continues to control weekly mileage, long runs, quality days, and taper timing. Supporting activities are placed around that structure.

#### TodayRecommendationPolicy Integration

Today uses the same candidate and recovery rules when a planned workout is missing or readiness calls for an alternative. This prevents the plan generator and Today card from recommending contradictory sessions.

### Workout Types

The workout model adds explicit cycling, swimming, walking, and hiking types. Existing run, strength, yoga, mobility, rest, and cross-training values remain unchanged for saved-plan compatibility.

Each workout type exposes semantic traits rather than relying on string comparisons:

- Running
- Strength
- Endurance cross-training
- Mobility
- Recovery-compatible
- Lower-body demanding
- High intensity

These traits drive scheduling and allow future workout types without rewriting every rule.

## Scheduling Rules

The scheduler first anchors required running sessions, then places supporting work in remaining valid slots.

### Hard Constraints

- Never schedule on an unavailable day.
- Never overwrite a completed workout.
- Do not place heavy lower-body strength immediately before a long run, intervals, hills, or a race.
- Do not place heavy lower-body strength immediately after a long run, intervals, or hills.
- Do not exceed the user's total weekly training-day limit.
- Do not schedule an activity the user did not select, except rest.
- Preserve race taper reductions.

### Preferred Placement

- Upper-body strength is preferred after a long run or hard run.
- Lower-body or full-body strength is preferred before an easy or recovery day, with sufficient distance from the long run.
- Mobility is preferred after hard efforts, during low readiness, or on otherwise unavailable high-load slots.
- Easy cycling and swimming can replace low-intensity aerobic volume when selected as supporting activities.
- Walking or hiking is treated as low-intensity load and is not counted as running mileage.

### Load Accounting

The weekly distance goal counts running workouts and qualifying running activities only. Strength, cycling, swimming, walking, and hiking contribute to training load and completion, but not running mileage or run count.

The scheduler uses category load rather than pretending every sport has an equivalent mileage. Version one uses low, moderate, and high load classes. Sport-specific load conversion and multisport periodization remain future work.

## Regeneration and Failure Handling

- Invalid profiles are repaired to the safest valid default and surfaced with a non-blocking explanation.
- If constraints make the requested weekly mix impossible, primary sessions win, supporting frequency is reduced, and the summary explains the compromise.
- If plan regeneration fails, the previous plan remains active and the user sees a retry action.
- Profile saving and plan regeneration are separate operations. A saved profile is not lost if regeneration fails.
- Cached plans include the profile version and a profile fingerprint so stale plans can be identified without unnecessary regeneration.

## Styling Direction

The feature follows Runaway's existing dark, layered interface while reducing amber saturation:

- Activity categories use restrained semantic accents: blue for aerobic cross-training, green for recovery and mobility, and amber only for primary action or running emphasis.
- Selection is communicated through surface elevation, checkmarks, and typography instead of filling every selected control with color.
- Controls use native SwiftUI semantics, 44-point minimum hit targets, existing spacing tokens, and existing card radii.
- The activity mix summary is the focal element; advanced schedule controls remain visually secondary.
- Profile rows provide selected, unselected, disabled, loading, validation, and save-failure states.

## Local Intelligence Boundary

All scheduling decisions are deterministic and on-device. Apple Foundation Models may phrase a short explanation from structured scheduling reasons, but the model is optional and cannot choose or alter the workout. A deterministic explanation is always available, preserving behavior on devices where the local model is unavailable.

No external LLM API or Edge Function is introduced.

## Testing Strategy

### Model and Migration Tests

- New users receive a valid running-first default.
- Existing settings migrate without losing frequency or long-run preference.
- Unsupported or corrupted stored values repair safely.
- Profile validation rejects impossible roles and normalizes excessive frequencies.

### Scheduling Policy Tests

- Upper-body strength can follow a long run.
- Heavy lower-body strength cannot border a long run or hard run.
- Mobility and easy cross-training are preferred under low readiness.
- Only selected activities are scheduled.
- Supporting activities do not increase running mileage or run count.
- Unavailable days and completed workouts remain untouched.
- Impossible schedules preserve primary workouts and reduce supporting work predictably.

### Integration Tests

- Onboarding and Settings save the same profile shape.
- Updating next week preserves the current plan.
- Rebalancing this week preserves completed workouts.
- Today and the weekly plan use consistent recommendation reasons.
- A profile fingerprint change marks a cached plan stale.

### UI Tests

- Activity selection, role selection, and conditional strength controls are reachable and accessible.
- Existing users can dismiss the personalization prompt.
- Regeneration choices and failure states are understandable.
- Next Up displays human-readable workout labels and placement reasons.

## Rollout Sequence

1. Add the versioned profile model, storage, migration, and unit tests.
2. Add explicit workout types and semantic load traits.
3. Add the complementary scheduling policy with exhaustive rule tests.
4. Integrate the policy into local plan generation and Today alternatives.
5. Add shared Fitness Profile controls to Settings.
6. Add the onboarding activity and schedule steps.
7. Add existing-user personalization and safe regeneration flows.
8. Run model, policy, integration, UI, and archive validation.

## Success Criteria

- A running-and-strength user receives strength sessions placed safely around run intensity and long-run recovery.
- Cycling, swimming, walking, hiking, and mobility appear only when selected.
- Next Up can recommend an appropriate non-running session and explain why.
- Running mileage and run counts exclude every non-running activity.
- Profile changes never erase completed workouts.
- The complete feature works without network access or an external language model.

## Explicitly Out of Scope

- Multiple simultaneous primary sports
- Triathlon-specific periodization
- Sport-to-sport mileage equivalence
- Automatic gym exercise programming with sets, reps, and progression
- Social comparison or shared profiles
- Server-side profile synchronization
