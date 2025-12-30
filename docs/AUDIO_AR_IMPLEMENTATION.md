# Audio AR Running Companion - Implementation Plan

## Overview

This document captures the implementation plan for adding AI-powered audio coaching to the Runaway iOS app. The feature provides contextual, proactive audio prompts during runs based on real-time data.

---

## Architecture Decisions

### Decision 1: Extend Existing Services (Not Replace)

**Decision:** Extend `RecordingSession` and integrate with `ActivityRecordingService` rather than creating a parallel `RunState` store.

**Rationale:**
- `ActivityRecordingService` already manages run state with `RecordingSession`
- `GPSTrackingService` already provides real-time location, speed, distance
- Avoids state duplication and synchronization issues
- Maintains backward compatibility with existing recording flow

**Implementation:**
```swift
// Extend RecordingSession with coaching-specific fields
extension RecordingSession {
    var splits: [Split]
    var targetPace: TimeInterval?
    var lastPromptTime: Date?
}
```

### Decision 2: AudioCoachingService as Observer

**Decision:** `AudioCoachingService` observes `ActivityRecordingService` rather than owning GPS/recording services.

**Rationale:**
- Single source of truth for recording state
- AudioCoaching is an optional enhancement, not core functionality
- Can be enabled/disabled without affecting recording
- Cleaner separation of concerns

**Architecture:**
```
ActivityRecordingService (owns GPSTrackingService)
        │
        │ publishes @Published properties
        ▼
AudioCoachingService (observes, evaluates triggers)
        │
        ▼
TriggerEngine → TTSService
```

### Decision 3: Apple TTS First (Offline-First)

**Decision:** Use `AVSpeechSynthesizer` as primary TTS, with optional ElevenLabs upgrade path.

**Rationale:**
- Works offline (critical for trail running)
- No API costs during runs
- Lower latency than API calls
- ElevenLabs can be added later as premium feature

### Decision 4: Template-Based Prompts First

**Decision:** Start with template-based prompt generation, add LLM enhancement later.

**Rationale:**
- Faster implementation
- Works offline
- Predictable behavior for testing
- LLM adds latency and cost
- Can A/B test template vs LLM quality

### Decision 5: No Watch Companion Initially

**Decision:** Defer WatchOS companion app and Garmin integration.

**Rationale:**
- Significant development effort (1-2 weeks)
- Core value can be delivered without it
- Voice input can use AirPods or phone microphone
- Can be added in later phase

### Decision 6: Heart Rate Optional

**Decision:** Heart rate features are optional and gracefully degrade.

**Rationale:**
- Not all users have HR monitors
- HealthKit requires explicit permission
- Core features (splits, pace) work without HR
- Zone triggers simply don't fire if HR unavailable

---

## Codebase Integration Points

### Existing Services to Leverage

| Service | Usage |
|---------|-------|
| `GPSTrackingService` | Real-time location, speed, distance, route points |
| `ActivityRecordingService` | Recording state, session management, auto-pause |
| `TimerUpdateManager` | 1Hz update tick for trigger evaluation |
| `RunawayCoachAPIService` | LLM API patterns (for future prompt generation) |
| `WidgetSyncService` | Settings persistence patterns via UserDefaults |

### Key Files Modified

| File | Modification |
|------|--------------|
| `ActiveRecordingView.swift` | Add `@StateObject audioCoaching` |
| `ActivityRecordingService.swift` | Add splits tracking, expose more state |
| `RecordingSession` (in ActivityRecordingService) | Add coaching-related properties |

### New Files Created

```
Runaway iOS/Services/AudioCoaching/
├── AudioCoachingService.swift      # Main coordinator ✅
├── TriggerEngine.swift             # Condition evaluation loop ✅
├── TTSService.swift                # Text-to-speech wrapper ✅
├── VoiceInputService.swift         # Speech recognition ✅
├── VoiceIntentParser.swift         # Intent parsing + ConversationContext ✅
├── VoiceCoachingCoordinator.swift  # Voice flow orchestration ✅
├── PromptGenerator.swift           # Template/LLM prompt creation (Phase 4)
└── Triggers/
    ├── Trigger.swift               # Protocol + base class ✅
    ├── SplitTrigger.swift          # Mile/km completion ✅
    ├── ZoneTransitionTrigger.swift # HR zone changes ✅
    ├── ZoneDurationTrigger.swift   # Extended zone warnings ✅
    ├── PaceDriftTrigger.swift      # Pace deviation alerts ✅
    └── CheckInTrigger.swift        # Periodic check-ins ✅

Runaway iOS/Models/
├── CoachSettings.swift             # User preferences + CoachSettingsStore ✅
├── Split.swift                     # Mile/km split data + SplitTracker ✅
├── QueuedPrompt.swift              # Prompt queue item + PromptQueue ✅
└── HeartRateZone.swift             # Zone definitions + calculator ✅

Runaway iOS/Views/
├── CoachSettingsView.swift         # Settings UI ✅
└── ActiveRecordingView.swift       # Updated with voice UI ✅
```

---

## Implementation Phases

### Phase 1: Core Audio Loop ✅ COMPLETED
**Goal:** Prove the concept with split announcements

**Components:**
- [x] `CoachSettings` model with basic toggles
- [x] `TTSService` using AVSpeechSynthesizer
- [x] `TriggerEngine` with 1Hz evaluation loop
- [x] `SplitTrigger` for mile completion announcements
- [x] `AudioCoachingService` coordinator
- [x] Integration with `ActiveRecordingView`

**Deliverable:** "Mile 1 complete. 8:42 pace." spoken at each mile.

### Phase 2: Enhanced Triggers ✅ COMPLETED
**Goal:** Add pace and zone-based coaching

**Components:**
- [x] `PaceDriftTrigger` - alerts when pace deviates from target/average
- [x] `ZoneTransitionTrigger` - alerts on HR zone changes
- [x] `ZoneDurationTrigger` - warns after extended time in high zones
- [x] `CheckInTrigger` - periodic "How are you feeling?" prompts
- [x] `HeartRateZone` model - zone definitions and calculations
- [x] Settings UI (`CoachSettingsView`) for configuring triggers

**Note:** Heart rate data integration (HealthKit streaming) deferred to later phase.
Triggers will activate when HR data becomes available via `RunStateSnapshot.currentHeartRate`.

### Phase 3: Voice Interaction ✅ COMPLETED
**Goal:** Allow voice responses to check-ins

**Components:**
- [x] `VoiceInputService` using Speech framework (on-device recognition)
- [x] `VoiceIntentParser` for common responses (feelings, stats requests, commands)
- [x] `ConversationContext` tracking for contextual understanding
- [x] `VoiceCoachingCoordinator` to orchestrate voice flow
- [x] Shake gesture activation via `ShakeGestureDetector`
- [x] Microphone button in `ActiveRecordingView`
- [x] Voice commands: pause, resume, stop, mute, unmute
- [x] Stats requests: pace, distance, time, full stats

**Activation Methods:**
- Tap microphone button on recording screen
- Shake device to activate voice input
- Auto-listen after check-in prompts (when enabled)

### Phase 4: LLM Enhancement
**Goal:** More natural, contextual prompts

**Components:**
- [ ] LLM prompt generation via existing API service
- [ ] Response caching for common scenarios
- [ ] A/B testing framework for template vs LLM

### Phase 5: Advanced Features
**Goal:** Rich contextual awareness

**Components:**
- [ ] `LandmarkService` for POI announcements
- [ ] Route navigation with turn-by-turn
- [ ] Negative split coaching
- [ ] Post-run summary generation

### Phase 6: Watch Integration (Optional)
**Goal:** Native watch experience

**Components:**
- [ ] WatchOS companion app
- [ ] WatchConnectivity framework integration
- [ ] Garmin Connect IQ integration

---

## Technical Specifications

### Trigger Evaluation

```swift
// TriggerEngine runs every 1 second
func evaluate() {
    for trigger in enabledTriggers {
        if trigger.cooldownElapsed && trigger.shouldFire(state: runState) {
            let prompt = trigger.generatePrompt(state: runState)
            promptQueue.enqueue(prompt, priority: trigger.priority)
            trigger.lastFired = Date()
        }
    }

    if !ttsService.isSpeaking, let next = promptQueue.dequeue() {
        ttsService.speak(next.message)
    }
}
```

### Priority Levels

| Priority | Use Case | Interrupts? |
|----------|----------|-------------|
| `.low` | Landmarks, trivia | No |
| `.medium` | Splits, zone changes | No |
| `.high` | Pace drift, check-ins | No |
| `.critical` | Safety (HR too high), navigation | Yes |

### Cooldown Defaults

| Trigger | Default Cooldown |
|---------|-----------------|
| Split | 60 seconds |
| Zone Transition | 30 seconds |
| Pace Drift | 120 seconds |
| Check-in | 300 seconds |
| Zone Duration | 180 seconds |

### Audio Session Configuration

```swift
let audioSession = AVAudioSession.sharedInstance()
try audioSession.setCategory(.playback, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
try audioSession.setActive(true)
```

---

## Settings Structure

```swift
struct CoachSettings: Codable {
    // Master toggle
    var isEnabled: Bool = true

    // Split announcements
    var announceSplits: Bool = true
    var splitDetail: SplitDetail = .detailed // .off, .basic, .detailed

    // Pace coaching
    var paceAlerts: Bool = true
    var paceDriftThreshold: Double = 0.10 // 10%
    var targetPace: TimeInterval? = nil

    // Zone coaching (requires HR)
    var zoneAlerts: Bool = true
    var alertOnZones: Set<Int> = [4, 5]

    // Check-ins
    var enableCheckIns: Bool = true
    var checkInInterval: TimeInterval = 300 // 5 minutes

    // Voice
    var speechRate: Float = 0.52 // AVSpeechUtterance rate
    var voiceIdentifier: String? = nil // nil = system default
}
```

---

## Testing Strategy

### Unit Tests
- Trigger condition evaluation
- Cooldown timing
- Priority queue ordering
- Prompt template generation

### Integration Tests
- TTS audio output
- Trigger engine with mock run state
- Settings persistence

### Manual Testing
- Treadmill runs with controlled pace
- Outdoor runs with GPS
- Background audio (music) interaction
- AirPods/speaker output

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| TTS interrupts music | Use `.duckOthers` to lower music volume temporarily |
| Prompt spam | Per-trigger cooldowns + max queue size of 3 |
| Battery drain | Triggers evaluated on existing 1Hz timer, no additional GPS polling |
| Offline runs | Template-based prompts work offline, LLM gracefully degrades |
| No HR monitor | Zone triggers simply disabled, pace/split still work |

---

## Success Metrics

- User enables coaching for >50% of runs
- Average prompts per run: 5-15 (not annoying)
- Battery impact: <5% additional drain
- Crash rate: 0 (audio should never crash recording)

---

## Document History

| Date | Author | Changes |
|------|--------|---------|
| 2024-12-23 | Claude | Initial plan based on spec review |
| 2024-12-23 | Claude | Phase 1 complete: Core audio loop with split announcements |
| 2024-12-23 | Claude | Phase 2 complete: Enhanced triggers (pace, zone, check-in) + settings UI |
| 2024-12-23 | Claude | Phase 3 complete: Voice interaction (speech recognition, intent parsing, shake activation) |
