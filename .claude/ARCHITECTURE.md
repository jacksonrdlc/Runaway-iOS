# Runaway Ecosystem Architecture

This document provides a comprehensive overview of how the 5 Runaway projects work together.

## Projects Overview

### 1. Runaway iOS (Swift/SwiftUI)
**Path**: `/Users/jack.rudelic/projects/labs/Runaway iOS`
**Purpose**: Native iOS app for running analytics
**Key Tech**: SwiftUI, Supabase, Firebase (FCM), WidgetKit

### 2. Runaway Web (Nuxt 3)
**Path**: `~/projects/labs/runaway-web`
**Purpose**: Web application for running analytics
**Key Tech**: Nuxt 3, TypeScript, Pinia, Supabase, TailwindCSS

### 3. Runaway Edge (Supabase Functions)
**Path**: `~/projects/labs/runaway-edge`
**Purpose**: Serverless edge functions for real-time notifications
**Key Tech**: Deno, Supabase Functions, Firebase Cloud Messaging

### 4. Strava Webhooks (Express)
**Path**: `~/projects/labs/strava-webhooks`
**Purpose**: Webhook server for Strava activity synchronization
**Key Tech**: Node.js, Express, Supabase Client

### 5. Runaway Coach (FastAPI)
**Path**: `~/projects/labs/runaway/runaway-coach`
**Purpose**: AI-powered coaching and analytics backend
**Key Tech**: Python, FastAPI, LangGraph, Claude 3.5 Sonnet, Google Cloud Run

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         RUNAWAY ECOSYSTEM                                │
│                                                                          │
│  ┌──────────────┐         ┌──────────────┐         ┌──────────────┐   │
│  │   Runaway    │         │   Runaway    │         │   Runaway    │   │
│  │     iOS      │◄────────┤     Web      │◄────────┤    Coach     │   │
│  │   (Swift)    │         │   (Nuxt 3)   │         │  (FastAPI)   │   │
│  └──────┬───────┘         └──────┬───────┘         └──────┬───────┘   │
│         │                        │                         │            │
│         │                        │                         │            │
│         └────────────────────────┼─────────────────────────┘            │
│                                  │                                      │
│                          ┌───────▼────────┐                            │
│                          │   SUPABASE     │                            │
│                          │  (PostgreSQL   │                            │
│                          │   + Realtime)  │                            │
│                          └───────▲────────┘                            │
│                                  │                                      │
│         ┌────────────────────────┴─────────────────────┐               │
│         │                                               │               │
│  ┌──────▼───────┐                             ┌────────▼──────┐       │
│  │    Strava    │                             │    Runaway    │       │
│  │   Webhooks   │                             │     Edge      │       │
│  │  (Express)   │                             │  (Supabase    │       │
│  └──────────────┘                             │   Functions)  │       │
│                                                └───────────────┘       │
└─────────────────────────────────────────────────────────────────────────┘
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
**Service**: Runaway Coach API

```
User opens insights view
    ↓
Client requests AI analysis
    ↓
Runaway Coach API:
  - Validates JWT token
  - Fetches activities from Supabase
  - Executes 8 AI agents (LangGraph)
  - Returns comprehensive analysis
    ↓
Client displays personalized insights
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
Services validate JWT
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

**activity_types**
- `id` (integer)
- `name` (text) - "Run", "Ride", "Walk", etc.

### Row Level Security (RLS)
```sql
-- Users can only access their own data
WHERE athlete_id IN (
  SELECT id FROM athletes
  WHERE auth_user_id = auth.uid()
)
```

## API Integration Points

### Runaway Coach API Endpoints

**Production**: `https://runaway-coach-api-203308554831.us-central1.run.app`

```
GET  /health
GET  /quick-wins/comprehensive-analysis
GET  /quick-wins/weather-impact?limit=30
GET  /quick-wins/vo2max-estimate?limit=50
GET  /quick-wins/training-load?limit=60
POST /analysis/runner
POST /feedback/workout
POST /goals/assess
```

### AI Agent System (LangGraph)

**8 Specialized Agents**:
1. **Supervisor** - Orchestrates workflow
2. **Performance Analysis** - Trends, consistency
3. **Weather Context** - Heat stress, acclimation
4. **VO2 Max Estimation** - Fitness level, race predictions
5. **Training Load** - ACWR, injury risk, recovery
6. **Goal Strategy** - Goal feasibility, progress
7. **Pace Optimization** - Zone recommendations
8. **Workout Planning** - Personalized training

**Execution Flow**:
```
Performance Analysis
    ↓
[Weather, VO2 Max, Training Load, Goals] (Parallel)
    ↓
Pace Optimization
    ↓
Workout Planning
    ↓
Final Synthesis
```

## Deployment

### Strava Webhooks
- Platform: Self-hosted (Cloud Run)
- Port: 8080
- Runtime: Node.js 16+

### Runaway Edge
- Platform: Supabase Edge Functions
- Runtime: Deno
- Trigger: Database events

### Runaway Coach
- Platform: Google Cloud Run
- Memory: 2Gi, CPU: 2
- Scaling: 0-10 instances
- Secrets: Google Secret Manager

### Runaway iOS
- Platform: iOS 15+
- Distribution: App Store (TestFlight)
- Dependencies: Swift Package Manager

### Runaway Web
- Platform: Nuxt 3 (SSR)
- Hosting: Vercel/Netlify
- Runtime: Node.js

## Key Features

### Weather-Adjusted Training ⭐ (Unique)
- Analyzes temperature/humidity impact
- Tracks heat acclimation
- Recommends optimal training times
- **Competitive advantage**: No other platform has this

### Free VO2 Max & Race Predictions
- Alternative to Strava Summit ($12/mo)
- Multi-method VO2 max estimation
- Race predictions: 5K, 10K, Half, Marathon
- vVO2 max pace calculations

### ACWR Injury Prevention
- Alternative to WHOOP ($30/mo)
- Acute:Chronic Workload Ratio
- Training Stress Score (TSS)
- Injury risk classification
- 7-day personalized workout plans

### AI-Powered Coaching
- Claude 3.5 Sonnet powered
- LangGraph multi-agent orchestration
- Personalized recommendations
- Real-time analysis

## Quick Start Commands

### Load Full Ecosystem in Claude Code
```bash
claude --add-dir ~/projects/labs/Runaway\ iOS \
       --add-dir ~/projects/labs/runaway-web \
       --add-dir ~/projects/labs/runaway-edge \
       --add-dir ~/projects/labs/strava-webhooks \
       --add-dir ~/projects/labs/runaway/runaway-coach
```

### iOS Build
```bash
cd "/Users/jack.rudelic/projects/labs/Runaway iOS"
xcodebuild -workspace "Runaway iOS.xcworkspace" \
  -scheme "Runaway iOS" \
  -destination "platform=iOS Simulator,name=iPhone 15" \
  build
```

### Web Dev Server
```bash
cd ~/projects/labs/runaway-web
npm run dev
```

### Coach API Local
```bash
cd ~/projects/labs/runaway/runaway-coach
source .venv/bin/activate
uvicorn api.main:app --reload
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

### Use Templates
- `Runaway-iOS-Info.plist.template`
- `.env.example`
- Always update `.gitignore`

## Troubleshooting

### Widget Not Updating
- Check app group: `group.com.jackrudelic.runawayios`
- Verify `WidgetCenter.shared.reloadAllTimelines()` is called
- Check UserDefaults suite accessibility

### Supabase Connection Issues
- Verify credentials with `SupabaseConfiguration.printConfiguration()`
- Check environment variables: `SUPABASE_URL`, `SUPABASE_KEY`
- Ensure using anon key (not service role) in clients

### API Authentication Errors
- Confirm JWT token is valid and not expired
- Check Authorization header format: `Bearer {token}`
- Verify user_id → athlete_id mapping exists

### Real-time Sync Not Working
- Check RealtimeService subscription is active
- Verify FCM token is registered
- Test Edge Function manually with database insert

## References

- iOS CLAUDE.md: `/Users/jack.rudelic/projects/labs/Runaway iOS/CLAUDE.md`
- Web CLAUDE.md: `~/projects/labs/runaway-web/CLAUDE.md`
- Coach CLAUDE.md: `~/projects/labs/runaway/runaway-coach/CLAUDE.md`
- Strava CLAUDE.md: `~/projects/labs/strava-webhooks/CLAUDE.md`

---

**Last Updated**: October 2025
**Ecosystem Version**: 1.0
**Total Projects**: 5
