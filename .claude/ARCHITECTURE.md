# Runaway Ecosystem Architecture

This document provides a comprehensive overview of how the Runaway projects work together.

**Last Updated**: January 2026

## Projects Overview

### 1. Runaway iOS (Swift/SwiftUI)
**Path**: `/Users/jack.rudelic/projects/labs/Runaway iOS`
**Purpose**: Native iOS app for running analytics and AI coaching
**Key Tech**: SwiftUI, Supabase, Firebase (FCM), WidgetKit, HealthKit

### 2. Runaway Web (Nuxt 3)
**Path**: `~/projects/labs/runaway-web`
**Purpose**: Web application for running analytics
**Key Tech**: Nuxt 3, TypeScript, Pinia, Supabase, TailwindCSS

### 3. Runaway Edge (Supabase Functions)
**Path**: `~/projects/labs/runaway-edge`
**Purpose**: Serverless edge functions for AI analysis, notifications, and background processing
**Key Tech**: Deno, Supabase Edge Functions, Anthropic Claude API

### 4. Strava Webhooks (Express)
**Path**: `~/projects/labs/strava-webhooks`
**Purpose**: Webhook server for Strava activity synchronization
**Key Tech**: Node.js, Express, Supabase Client

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           RUNAWAY ECOSYSTEM                                  │
│                                                                              │
│  ┌──────────────────┐                           ┌──────────────────┐        │
│  │   Runaway iOS    │                           │   Runaway Web    │        │
│  │   (SwiftUI)      │                           │   (Nuxt 3)       │        │
│  └────────┬─────────┘                           └────────┬─────────┘        │
│           │                                              │                   │
│           │              ┌───────────────────┐          │                   │
│           │              │   SUPABASE        │          │                   │
│           └──────────────┤                   ├──────────┘                   │
│                          │  ┌─────────────┐  │                              │
│                          │  │ PostgreSQL  │  │                              │
│                          │  │ + Realtime  │  │                              │
│                          │  └─────────────┘  │                              │
│                          │                   │                              │
│                          │  ┌─────────────┐  │                              │
│                          │  │ Edge        │  │                              │
│                          │  │ Functions   │  │     ┌──────────────────┐    │
│                          │  │             │◄─┼─────┤  Anthropic       │    │
│                          │  │ • analysis  │  │     │  Claude API      │    │
│                          │  │ • chat      │  │     └──────────────────┘    │
│                          │  │ • notify    │  │                              │
│                          │  └─────────────┘  │                              │
│                          │                   │                              │
│                          │  ┌─────────────┐  │                              │
│                          │  │ Auth        │  │                              │
│                          │  │ (JWT)       │  │                              │
│                          │  └─────────────┘  │                              │
│                          └─────────┬─────────┘                              │
│                                    │                                        │
│         ┌──────────────────────────┴──────────────────────┐                │
│         │                                                  │                │
│  ┌──────▼───────┐                                  ┌──────▼───────┐        │
│  │   Strava     │                                  │   Firebase   │        │
│  │   Webhooks   │                                  │   FCM        │        │
│  │   (Express)  │                                  │   (Push)     │        │
│  └──────────────┘                                  └──────────────┘        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Data Flow: Activity Sync Journey

### Step 1: Strava → Supabase
**Service**: Strava Webhooks

```
User completes run on Strava
    ↓
Strava sends webhook POST
    ↓
Strava Webhooks service:
  - Refreshes Strava OAuth token
  - Fetches activity details
  - Transforms to Supabase schema
  - Upserts to activities table
```

### Step 2: Supabase → Clients (Real-time)
**Service**: Runaway Edge Functions

```
Activity inserted into Supabase
    ↓
Database trigger fires
    ↓
Edge Function sends FCM push notification
    ↓
iOS app wakes in background
    ↓
RealtimeService syncs new data
    ↓
DataManager updates cache
    ↓
Widget refreshes automatically
```

### Step 3: Client → AI Analysis
**Service**: Supabase Edge Functions (comprehensive-analysis)

```
User opens Quick Wins / Training view
    ↓
iOS QuickWinsService calls Edge Function
    ↓
Edge Function (comprehensive-analysis):
  - Validates JWT token
  - Fetches activities from database
  - Calculates training load (ACWR)
  - Estimates VO2 max
  - Analyzes weather impact
  - Calls Claude API for insights
    ↓
Returns comprehensive analysis to client
```

## Authentication Flow

```
User Signs In (iOS/Web)
    ↓
Supabase Auth creates session
    ↓
JWT Token Generated (1hr expiration)
    ↓
Client stores token
    ↓
──────────────────────────────────────
All API Requests:
    ↓
Authorization: Bearer {JWT_TOKEN}
    ↓
Edge Functions validate JWT
    ↓
Extract user_id → map to athlete_id
    ↓
Query data with RLS enforcement
```

## Database Schema (Supabase)

### Key Tables

**athletes**
- `id` (integer) - Strava athlete ID
- `auth_user_id` (UUID) - Links to Supabase auth.users
- `access_token`, `refresh_token` - Strava OAuth
- `fcm_token` - Push notifications

**activities**
- `id` (integer) - Strava activity ID
- `athlete_id` (integer) → athletes.id
- `activity_type_id` (integer) → activity_types.id
- `distance`, `moving_time`, `average_speed`
- `map_polyline`, `start_latitude`, `start_longitude`
- `average_heart_rate`, `max_heart_rate`

**rest_days**
- `id` (UUID)
- `athlete_id` (integer) → athletes.id
- `date` (date)
- `rest_type` (text) - active_recovery, full_rest, injury, etc.
- `notes` (text)

**daily_readiness**
- `id` (UUID)
- `athlete_id` (integer) → athletes.id
- `date` (date)
- `score` (integer) - 0-100
- `sleep_score`, `hrv_score`, `resting_hr_score`, `training_load_score`

### Row Level Security (RLS)
```sql
-- Users can only access their own data
WHERE athlete_id IN (
  SELECT id FROM athletes
  WHERE auth_user_id = auth.uid()
)
```

## Supabase Edge Functions

### Available Functions

| Function | Purpose | Authentication |
|----------|---------|----------------|
| `comprehensive-analysis` | Training load, VO2max, weather analysis | JWT (Bearer token) |
| `chat` | AI-powered conversational coaching | JWT (Bearer token) |
| `send-notification` | FCM push notifications | Service role |
| `daily-commitment-check` | Scheduled commitment reminders | Service role |

### comprehensive-analysis Function

**Endpoint**: `{SUPABASE_URL}/functions/v1/comprehensive-analysis`
**Method**: GET
**Auth**: Bearer token (Supabase JWT)

**Response Structure**:
```json
{
  "trainingLoad": {
    "acuteLoad": 45.2,
    "chronicLoad": 38.5,
    "acwr": 1.17,
    "riskLevel": "optimal",
    "weeklyMileage": 35.2,
    "weeklyDuration": 320,
    "recommendation": "..."
  },
  "vo2max": {
    "estimated": 48.5,
    "fitnessLevel": "good",
    "racePredictions": {
      "5k": "22:30",
      "10k": "47:00",
      "halfMarathon": "1:45:00",
      "marathon": "3:45:00"
    }
  },
  "weatherImpact": {
    "recentConditions": [...],
    "heatAcclimation": 0.7,
    "recommendation": "..."
  },
  "aiInsights": "..."
}
```

## iOS App Architecture

### Service Layer

```
┌─────────────────────────────────────────────────────────────┐
│                     iOS Services                             │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────────┐  ┌─────────────────┐                   │
│  │ QuickWinsService│  │ ChatService     │                   │
│  │                 │  │                 │                   │
│  │ • Comprehensive │  │ • AI coaching   │                   │
│  │   analysis      │  │ • Conversation  │                   │
│  │ • Training load │  │   history       │                   │
│  │ • VO2 max       │  │                 │                   │
│  └────────┬────────┘  └────────┬────────┘                   │
│           │                    │                             │
│           └────────┬───────────┘                             │
│                    │                                         │
│           ┌────────▼────────┐                               │
│           │ Supabase Edge   │                               │
│           │ Functions       │                               │
│           └─────────────────┘                               │
│                                                              │
│  ┌─────────────────┐  ┌─────────────────┐                   │
│  │ ActivityService │  │ RealtimeService │                   │
│  │                 │  │                 │                   │
│  │ • CRUD ops      │  │ • Live sync     │                   │
│  │ • Supabase DB   │  │ • Subscriptions │                   │
│  └─────────────────┘  └─────────────────┘                   │
│                                                              │
│  ┌─────────────────┐  ┌─────────────────┐                   │
│  │ HealthKitManager│  │ GPSTrackingServ │                   │
│  │                 │  │                 │                   │
│  │ • Sleep data    │  │ • Live tracking │                   │
│  │ • HRV, HR       │  │ • Route builder │                   │
│  │ • Workout sync  │  │                 │                   │
│  └─────────────────┘  └─────────────────┘                   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Manager Layer (Singletons)

- `DataManager.shared` - Central data store
- `AuthManager.shared` - Authentication state
- `UserManager.shared` - User preferences
- `RealtimeService.shared` - Live data sync
- `LocationManager.shared` - GPS services

## Key Features

### Training Load (ACWR)
- Acute:Chronic Workload Ratio calculation
- Injury risk classification (low/optimal/moderate/high)
- 7-day vs 28-day load comparison
- Personalized training recommendations

### VO2 Max Estimation
- Multi-method estimation from running data
- Race predictions: 5K, 10K, Half, Marathon
- Fitness level classification
- vVO2max pace calculations

### Weather-Adjusted Training
- Temperature/humidity impact analysis
- Heat acclimation tracking
- Performance adjustment factors
- Optimal training time recommendations

### Readiness Score (HealthKit Integration)
- Daily recovery score (0-100)
- Sleep quality analysis
- HRV trend tracking
- Training load integration

## Deployment

### Supabase Edge Functions
- Platform: Supabase Edge Functions (Deno)
- Deploy: `supabase functions deploy <function-name>`
- Secrets: Supabase Dashboard > Edge Functions > Secrets

### Strava Webhooks
- Platform: Google Cloud Run
- Port: 8080
- Runtime: Node.js 18+

### Runaway iOS
- Platform: iOS 15+
- Distribution: App Store (TestFlight)
- Dependencies: Swift Package Manager

### Runaway Web
- Platform: Nuxt 3 (SSR)
- Hosting: Vercel/Netlify
- Runtime: Node.js

## Quick Start Commands

### iOS Build
```bash
cd "/Users/jack.rudelic/projects/labs/Runaway iOS"
xcodebuild -project "Runaway iOS.xcodeproj" \
  -scheme "Runaway iOS" \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  build
```

### Deploy Edge Function
```bash
cd ~/projects/labs/runaway-edge
supabase functions deploy comprehensive-analysis
```

### Web Dev Server
```bash
cd ~/projects/labs/runaway-web
npm run dev
```

### Strava Webhooks
```bash
cd ~/projects/labs/strava-webhooks
npm start
```

## Security Notes

### Environment Variables Priority
1. Environment variables (highest)
2. Info.plist / .env files
3. Hardcoded fallbacks (should be null)

### Never Commit
- `Runaway-iOS-Info.plist`
- `.env` files
- API keys or secrets
- OAuth tokens

### Edge Function Secrets
Set via Supabase Dashboard:
- `ANTHROPIC_API_KEY` - Claude API access
- `SUPABASE_SERVICE_ROLE_KEY` - Admin database access

## Troubleshooting

### Widget Not Updating
- Check app group: `group.com.jackrudelic.runawayios`
- Verify `WidgetCenter.shared.reloadAllTimelines()` is called
- Check UserDefaults suite accessibility

### Supabase Connection Issues
- Verify credentials with `SupabaseConfiguration.printConfiguration()`
- Check environment variables: `SUPABASE_URL`, `SUPABASE_KEY`
- Ensure using anon key (not service role) in clients

### Edge Function Errors
- Check function logs: `supabase functions logs comprehensive-analysis`
- Verify JWT token is valid
- Check secrets are set in Supabase Dashboard

### Real-time Sync Not Working
- Check RealtimeService subscription is active
- Verify FCM token is registered
- Test Edge Function manually with database insert

## Migration History

### January 2026: API Consolidation
- **Removed**: Runaway Coach API (Python/FastAPI)
- **Added**: `comprehensive-analysis` Supabase Edge Function
- **Rationale**: Simplified architecture, reduced infrastructure costs, unified on Supabase platform

### Deleted Services
- `RunawayCoachAPIService.swift` - Replaced by edge functions
- `EnhancedAnalysisService.swift` - Logic moved to edge functions
- `APIConfiguration.swift` - No longer needed
- `APIDebugUtils.swift` - No longer needed

---

**Ecosystem Version**: 2.0
**Total Active Projects**: 4 (iOS, Web, Edge, Strava Webhooks)
