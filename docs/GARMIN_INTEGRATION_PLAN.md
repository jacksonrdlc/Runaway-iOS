# Garmin Connect IQ Integration Plan

## Goal
Trigger Runaway iOS voice coaching from Garmin watch when starting a run.

## Architecture

```
┌─────────────────┐     Bluetooth      ┌─────────────────┐
│  Garmin Watch   │◄──────────────────►│   Runaway iOS   │
│  (Monkey C App) │    Connect IQ SDK  │   (Swift App)   │
└─────────────────┘                    └─────────────────┘
        │                                      │
        │ Start Run                            │ Start Voice Coach
        │ Pause/Resume                         │ Announce Splits
        │ Stop Run                             │ Check-ins
        │ Send HR Data ──────────────────────► │ HR Zone Alerts
        └──────────────────────────────────────┘
```

## Components Needed

### 1. Garmin Watch App (Monkey C)
- **Type**: Data Field or Background App
- **Features**:
  - Detects run start/stop/pause events
  - Sends messages to iOS companion app
  - Optionally receives voice coach status
  - Streams real-time HR data to iOS

### 2. iOS SDK Integration
- **SDK**: [connectiq-companion-app-sdk-ios](https://github.com/garmin/connectiq-companion-app-sdk-ios)
- **Installation**: Swift Package Manager
- **Features**:
  - Listen for Garmin device connections
  - Receive run start/stop messages
  - Trigger AudioCoachingService
  - Receive HR data for zone alerts

## Implementation Phases

### Phase 1: Basic Integration (MVP)
- [ ] Add Connect IQ iOS SDK via SPM
- [ ] Create `GarminService.swift` to handle connections
- [ ] Build simple Monkey C data field that sends "START" message
- [ ] Connect message receipt to `AudioCoachingService.start()`

### Phase 2: Full Run Control
- [ ] Handle pause/resume/stop from Garmin
- [ ] Sync run state between devices
- [ ] Add Garmin connection indicator in UI

### Phase 3: HR Streaming
- [ ] Stream HR data from Garmin to iOS
- [ ] Feed HR to voice coach for zone alerts
- [ ] More accurate than phone-based HR estimation

### Phase 4: Two-Way Communication
- [ ] Send voice coach status to watch (current pace, etc.)
- [ ] Display minimal stats on Garmin data field
- [ ] "Coach says slow down" indicator on watch

## Technical Requirements

### iOS Side
```swift
// GarminService.swift (conceptual)
import ConnectIQ

class GarminService: ObservableObject {
    private var deviceManager: IQDeviceManager?

    func handleMessage(_ message: [String: Any]) {
        switch message["action"] as? String {
        case "START_RUN":
            AudioCoachingService.shared.start()
        case "PAUSE_RUN":
            AudioCoachingService.shared.pause()
        case "STOP_RUN":
            AudioCoachingService.shared.stop()
        case "HR_UPDATE":
            let hr = message["hr"] as? Int
            // Feed to voice coach
        default:
            break
        }
    }
}
```

### Garmin Side (Monkey C)
```javascript
// RunawayDataField.mc (conceptual)
using Toybox.Application;
using Toybox.Communications;

class RunawayApp extends Application.AppBase {
    function onStart() {
        Communications.transmit({
            "action" => "START_RUN",
            "timestamp" => Time.now().value()
        }, null, listener);
    }
}
```

## Resources

- [Connect IQ iOS SDK](https://github.com/garmin/connectiq-companion-app-sdk-ios)
- [iOS Example App](https://github.com/garmin/connectiq-companion-app-example-ios)
- [Connect IQ Developer Portal](https://developer.garmin.com/connect-iq/)
- [Mobile SDK Docs](https://developer.garmin.com/connect-iq/core-topics/mobile-sdk-for-ios/)

## Considerations

1. **User must have Garmin Connect app installed** - SDK requires it
2. **Watch must support Connect IQ** - Most modern Garmin watches do
3. **Bluetooth connection required** - Watch must be paired
4. **App Store approval** - May need Garmin partnership for distribution

## Estimated Effort

| Phase | Effort | Priority |
|-------|--------|----------|
| Phase 1 (MVP) | 2-3 days | High |
| Phase 2 | 1-2 days | Medium |
| Phase 3 | 2-3 days | Medium |
| Phase 4 | 3-4 days | Low |

## Next Steps

1. Register as Garmin Connect IQ developer
2. Download Connect IQ SDK and simulator
3. Build proof-of-concept data field
4. Test iOS SDK integration
