# Runaway AI Architecture

**Version**: 2.0
**Last Updated**: January 2026
**Status**: Consolidated on Supabase Edge Functions

---

## Executive Summary

The Runaway AI system has been consolidated into **Supabase Edge Functions**, providing:

1. **Comprehensive Analysis** - Training load, VO2max, weather impact
2. **AI Coaching Chat** - Conversational coaching powered by Claude
3. **Real-time Insights** - Live analysis during and after workouts

This architecture replaces the previous multi-service approach (strava-data + runaway-coach) with a unified, serverless solution.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     RUNAWAY AI ARCHITECTURE                      │
│                                                                  │
│  ┌──────────────────┐                                           │
│  │   iOS App        │                                           │
│  │                  │                                           │
│  │  QuickWinsService├─────┐                                     │
│  │  ChatService     │     │                                     │
│  └──────────────────┘     │                                     │
│                           │                                     │
│                           ▼                                     │
│  ┌────────────────────────────────────────────────────────┐    │
│  │                   SUPABASE                              │    │
│  │                                                         │    │
│  │  ┌─────────────────────────────────────────────────┐   │    │
│  │  │           Edge Functions (Deno)                  │   │    │
│  │  │                                                  │   │    │
│  │  │  ┌────────────────────┐  ┌──────────────────┐  │   │    │
│  │  │  │ comprehensive-     │  │ chat             │  │   │    │
│  │  │  │ analysis           │  │                  │  │   │    │
│  │  │  │                    │  │ • Conversation   │  │   │    │
│  │  │  │ • Training Load    │  │ • Context        │  │   │    │
│  │  │  │ • VO2 Max          │  │ • Memory         │  │   │    │
│  │  │  │ • Weather Impact   │  │                  │  │   │    │
│  │  │  │ • AI Insights      │  │                  │  │   │    │
│  │  │  └─────────┬──────────┘  └────────┬─────────┘  │   │    │
│  │  │            │                      │             │   │    │
│  │  └────────────┼──────────────────────┼─────────────┘   │    │
│  │               │                      │                  │    │
│  │               └──────────┬───────────┘                  │    │
│  │                          │                              │    │
│  │  ┌───────────────────────▼─────────────────────────┐   │    │
│  │  │              PostgreSQL                          │   │    │
│  │  │                                                  │   │    │
│  │  │  • activities (training data)                   │   │    │
│  │  │  • athletes (profiles)                          │   │    │
│  │  │  • chat_messages (conversation history)         │   │    │
│  │  │  • daily_readiness (recovery scores)            │   │    │
│  │  └──────────────────────────────────────────────────┘   │    │
│  │                                                         │    │
│  └─────────────────────────────────────────────────────────┘    │
│                           │                                     │
│                           ▼                                     │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                   Anthropic Claude API                   │   │
│  │                                                          │   │
│  │  • claude-3-5-sonnet (analysis & insights)              │   │
│  │  • Streaming responses                                   │   │
│  │  • Context-aware coaching                                │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Edge Functions

### 1. comprehensive-analysis

**Purpose**: Provide detailed training analysis with AI-powered insights

**Endpoint**: `{SUPABASE_URL}/functions/v1/comprehensive-analysis`
**Method**: GET
**Auth**: Bearer token (Supabase JWT)

**Calculations Performed**:

```typescript
// Training Load (ACWR)
const acuteLoad = calculateWeeklyLoad(activities, 7);   // Last 7 days
const chronicLoad = calculateWeeklyLoad(activities, 28); // Last 28 days
const acwr = acuteLoad / chronicLoad;

// Risk Classification
const riskLevel = classifyRisk(acwr);
// < 0.8  → "low" (undertrained)
// 0.8-1.3 → "optimal" (sweet spot)
// 1.3-1.5 → "moderate" (caution)
// > 1.5  → "high" (injury risk)

// VO2 Max Estimation
const vo2max = estimateVO2Max(recentActivities);
// Uses pace + heart rate data
// Multiple estimation methods averaged

// Weather Impact
const weatherImpact = analyzeWeatherEffects(activities);
// Temperature adjustment factors
// Humidity impact on performance
// Heat acclimation tracking
```

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
    "trend": "increasing",
    "recommendation": "Your training load is in the optimal zone..."
  },
  "vo2max": {
    "estimated": 48.5,
    "confidence": 0.85,
    "fitnessLevel": "good",
    "trend": "improving",
    "racePredictions": {
      "5k": "22:30",
      "10k": "47:00",
      "halfMarathon": "1:45:00",
      "marathon": "3:45:00"
    }
  },
  "weatherImpact": {
    "averageTemp": 72,
    "averageHumidity": 65,
    "heatAcclimation": 0.7,
    "performanceAdjustment": -0.03,
    "recommendation": "Consider early morning runs..."
  },
  "aiInsights": "Based on your recent training..."
}
```

### 2. chat

**Purpose**: AI-powered conversational coaching

**Endpoint**: `{SUPABASE_URL}/functions/v1/chat`
**Method**: POST
**Auth**: Bearer token (Supabase JWT)

**Request**:
```json
{
  "message": "How should I prepare for my half marathon?",
  "conversationId": "optional-uuid"
}
```

**Context Building**:
```typescript
// Build context for Claude
const context = {
  athleteProfile: await getAthleteProfile(athleteId),
  recentActivities: await getRecentActivities(athleteId, 30),
  currentGoals: await getActiveGoals(athleteId),
  readinessScore: await getTodaysReadiness(athleteId),
  trainingLoad: await calculateTrainingLoad(athleteId),
  conversationHistory: await getConversationHistory(conversationId)
};
```

**Response**:
```json
{
  "message": "Based on your current fitness level...",
  "conversationId": "uuid",
  "context": {
    "activitiesReferenced": 5,
    "goalsReferenced": 1
  }
}
```

---

## iOS Integration

### QuickWinsService

```swift
// Services/QuickWinsService.swift

class QuickWinsService: ObservableObject {
    private var edgeFunctionURL: String {
        let baseURL = SupabaseConfiguration.supabaseURL ?? ""
        return "\(baseURL)/functions/v1/comprehensive-analysis"
    }

    func fetchComprehensiveAnalysis() async throws -> QuickWinsResponse {
        var request = URLRequest(url: URL(string: edgeFunctionURL)!)
        request.httpMethod = "GET"

        // Add JWT token
        if let token = await getJWTToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(QuickWinsResponse.self, from: data)
    }

    private func getJWTToken() async -> String? {
        let session = try? await supabase.auth.session
        return session?.accessToken
    }
}
```

### ChatService

```swift
// Services/ChatService.swift

class ChatService: ObservableObject {
    func sendMessage(_ message: String) async throws -> ChatResponse {
        let url = "\(SupabaseConfiguration.supabaseURL!)/functions/v1/chat"

        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = await getJWTToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body = ["message": message, "conversationId": currentConversationId]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(ChatResponse.self, from: data)
    }
}
```

---

## AI Analysis Features

### Training Load Analysis

**ACWR (Acute:Chronic Workload Ratio)**:
- Monitors training stress over time
- Identifies injury risk zones
- Provides load management recommendations

```
Risk Zones:
├── < 0.8   → Undertrained (increase load)
├── 0.8-1.3 → Optimal (maintain)
├── 1.3-1.5 → Moderate risk (caution)
└── > 1.5   → High risk (reduce load)
```

### VO2 Max Estimation

**Methods Used**:
1. **Pace-based**: Using best recent efforts
2. **HR-based**: Using heart rate reserve
3. **Combined**: Weighted average for confidence

**Race Predictions**:
- Uses Riegel formula with adjustments
- Accounts for training history
- Considers recent performance trends

### Weather Impact Analysis

**Factors Tracked**:
- Temperature (performance degrades above 60°F)
- Humidity (affects cooling efficiency)
- Heat index (combined effect)
- Acclimation level (improves over 10-14 days)

**Adjustment Formula**:
```
Performance Adjustment = -0.5% per degree above 60°F
                        -0.2% per 10% humidity above 50%
                        +1% per week of heat acclimation (up to 8%)
```

---

## Data Flow

### Analysis Request Flow

```
1. User opens Training View
   ↓
2. TrainingViewModel.loadQuickWins()
   ↓
3. QuickWinsService.fetchComprehensiveAnalysis()
   ↓
4. HTTP GET → Supabase Edge Function
   Authorization: Bearer {JWT}
   ↓
5. Edge Function:
   a. Validate JWT, extract user_id
   b. Query athlete_id from athletes table
   c. Fetch last 60 days of activities
   d. Calculate training load (ACWR)
   e. Estimate VO2 max
   f. Analyze weather impact
   g. Generate AI insights via Claude
   ↓
6. Return JSON response
   ↓
7. iOS decodes to QuickWinsResponse
   ↓
8. UI updates with analysis
```

### Chat Request Flow

```
1. User sends message in ChatView
   ↓
2. ChatViewModel.sendMessage()
   ↓
3. ChatService.sendMessage()
   ↓
4. HTTP POST → Supabase Edge Function
   Body: { message, conversationId }
   ↓
5. Edge Function:
   a. Validate JWT
   b. Load conversation history
   c. Build athlete context
   d. Call Claude API with context
   e. Store message in chat_messages
   ↓
6. Return response
   ↓
7. UI displays coach response
```

---

## Deployment

### Setting Up Edge Functions

```bash
# Navigate to edge functions project
cd ~/projects/labs/runaway-edge

# Deploy a function
supabase functions deploy comprehensive-analysis

# Set secrets (via Supabase Dashboard or CLI)
supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
```

### Required Secrets

| Secret | Purpose |
|--------|---------|
| `ANTHROPIC_API_KEY` | Claude API access |
| `SUPABASE_SERVICE_ROLE_KEY` | Admin database access |

### Monitoring

```bash
# View function logs
supabase functions logs comprehensive-analysis --follow

# Check function status
supabase functions list
```

---

## Cost Optimization

### Current Costs (Estimated)

| Service | Cost/Month |
|---------|------------|
| Claude API (analysis) | $30-50 |
| Supabase (Pro plan) | $25 |
| Edge Function invocations | Included |
| **Total** | **~$55-75** |

### Optimization Strategies

1. **Response Caching**:
   - Cache analysis results for 1 hour
   - Invalidate on new activity sync

2. **Model Selection**:
   - Use claude-3-5-sonnet for most analysis
   - Reserve claude-3-opus for complex coaching

3. **Batch Processing**:
   - Pre-generate weekly summaries
   - Background processing for non-urgent analysis

---

## Migration History

### January 2026: Consolidation

**Before**:
```
iOS App → RunawayCoachAPIService → Runaway Coach API (FastAPI/Python)
                                        ↓
                                   Claude API
```

**After**:
```
iOS App → QuickWinsService → Supabase Edge Function
                                   ↓
                              Claude API
```

**Benefits**:
- Eliminated Python service maintenance
- Reduced infrastructure complexity
- Lower latency (edge deployment)
- Unified authentication (Supabase JWT)
- Simplified deployment pipeline

**Removed Components**:
- `runaway-coach` Python service
- `RunawayCoachAPIService.swift`
- `EnhancedAnalysisService.swift`
- `APIConfiguration.swift`
- Multi-agent LangGraph workflows

---

## Future Enhancements

### Planned Features

1. **Apple Foundation Models (iOS 26+)**
   - On-device AI for basic insights
   - Privacy-preserving analysis
   - Offline capability

2. **Streaming Responses**
   - Real-time chat streaming
   - Progressive analysis loading

3. **Proactive Coaching**
   - Morning readiness notifications
   - Post-run analysis push
   - Weekly summary generation

4. **Multi-modal Analysis**
   - Voice input for chat
   - Image analysis (form feedback)
   - Route analysis from maps

---

## References

- [ARCHITECTURE.md](../.claude/ARCHITECTURE.md) - System architecture
- [CLAUDE.md](../CLAUDE.md) - Development guidelines
- [QuickWinsService.swift](../Runaway%20iOS/Services/QuickWinsService.swift) - iOS implementation
- [comprehensive-analysis](../../runaway-edge/supabase/functions/comprehensive-analysis) - Edge function code
