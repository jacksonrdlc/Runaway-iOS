# Runaway iOS

Native iOS running coach app with AI-powered analysis, real-time Strava/Garmin sync, Digital Twin, race course reconnaissance, and a home screen widget.

## Features

- **AI Coaching**: Chat with Claude for personalized coaching, weekly summaries, and goal assessment
- **Activity Sync**: Real-time sync from Strava and Garmin via Supabase Edge Functions
- **Digital Twin**: Biometric enrichment and observation tracking across activities
- **Race Reconnaissance**: Course maps with elevation charts and tactical insights
- **Training Plans**: AI-generated weekly training plans with taper awareness
- **Daily Commitments**: Micro-commitment tracking with fulfillment detection
- **Goal Tracking**: Running goal management with progress monitoring
- **Training Zones**: Heart rate and power zone configuration
- **Home Screen Widget**: Activity overview, weekly summary, monthly mileage
- **Silent Push**: Background widget refresh via APNs on new activity sync

## Tech Stack

- **Language**: Swift 5 / SwiftUI
- **Minimum iOS**: 16.0
- **Backend**: Supabase (Auth, PostgreSQL, Realtime)
- **AI**: Runaway Coach API (Claude-powered)
- **Dependencies** (Swift Package Manager): Supabase SDK, Alamofire, Polyline, CoreGPX, SwiftyJSON
- **Widget**: WidgetKit (home screen families only)

## Architecture

```
Singleton managers are the single source of truth:

DataManager.shared          ← central data store, drives widget updates
AuthManager.shared          ← session & auth
UserManager.shared          ← profile & preferences
RealtimeService.shared      ← Supabase real-time subscriptions
LocationManager.shared      ← GPS & location

Data flow:
  Supabase → RealtimeService → DataManager → Views (@EnvironmentObject)
  New activity → APNs silent push → DataManager.refreshActivities() → WidgetCenter.reloadAllTimelines()
```

### Service Layer (`Services/`)

| Service | Purpose |
|---------|---------|
| `ActivityService` | Activity CRUD with Supabase |
| `AthleteService` | Athlete profile management |
| `CommitmentService` | Daily commitment tracking |
| `GoalService` | Running goals & progress |
| `RealtimeService` | Live Supabase subscriptions |
| `RunawayCoachAPIService` | AI coaching API |
| `EnhancedAnalysisService` | API-first with local fallback |
| `GPSTrackingService` | Live activity recording |
| `ActivityRecordingService` | Activity capture & processing |
| `WidgetRefreshService` | Widget data management |

### Widget

Shares data via App Group `group.com.jackrudelic.runawayios` (UserDefaults). Activities encoded as `RAActivity` JSON strings. Widget locks to home screen families only (no standby/lock screen).

## Setup

1. Open the workspace:
   ```bash
   open "Runaway iOS.xcworkspace"
   ```

2. Copy the plist template and add credentials:
   ```bash
   cp Runaway-iOS-Info.plist.template Runaway-iOS-Info.plist
   ```
   Fill in `SUPABASE_URL` and `SUPABASE_KEY` (anon key, not service role).

3. Build and run in Xcode targeting an iPhone 15 simulator or device.

**Credentials priority**: Environment variables → Info.plist → null (will crash on first Supabase call)

## Build & Test

```bash
# Build
xcodebuild -workspace "Runaway iOS.xcworkspace" \
  -scheme "Runaway iOS" \
  -destination "platform=iOS Simulator,name=iPhone 15" build

# Test
xcodebuild -project "Runaway iOS.xcodeproj" \
  -scheme "Runaway iOS" \
  -destination "platform=iOS Simulator,name=iPhone 15" test

# Widget extension
xcodebuild -project "Runaway iOS.xcodeproj" \
  -scheme "RunawayWidgetExtension" \
  -destination "platform=iOS Simulator,name=iPhone 15" build
```

## Database Schema

Always reference the ERD before any database operations:

`Runaway iOS/Documentation/strava_erd.md`

Key tables: `activities` (90+ fields), `athletes`, `daily_commitments`, `activity_types`, `running_goals`, `gear`, `training_zones`, `weekly_training_plans`, `athlete_onboarding`.

**Never assume column names** — verify against the ERD. Always join `activity_types` when querying activities. Use `athlete_id`, not `auth_user_id`, for activity queries.

## Deployment

Distributed via Xcode → App Store Connect. No CI pipeline; manual archive and upload.

## Troubleshooting

**Widget not updating**: Check app group config (`group.com.jackrudelic.runawayios`), verify `WidgetCenter.shared.reloadAllTimelines()` fires after data changes.

**API issues**: Call `APIConfiguration.RunawayCoach.printCurrentConfiguration()` to debug endpoint/auth config.

**Real-time sync**: Call `SupabaseConfiguration.printConfiguration()` to verify credentials are loading. Check RealtimeService subscription is active.

**Simulator-only code**: `HTTP2ForcedURLProtocol` and `UserDefaultsAuthStorage` are scoped to `#if targetEnvironment(simulator)` only.

## License

Proprietary — Runaway App
