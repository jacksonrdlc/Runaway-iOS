# Runaway AI Architecture
**Version**: 1.0
**Last Updated**: 2025-12-01
**Status**: Two independent AI services with potential for integration

---

## Executive Summary

The Runaway ecosystem currently has **two AI-powered backend services**, each serving distinct purposes:

1. **strava-data** (Node.js) - Data sync + conversational chat
2. **runaway-coach** (Python) - Structured analysis + multi-agent workflows

This document defines clear boundaries, explains current capabilities, and outlines future integration strategies.

---

## Service Overview

### 1. strava-data (Node.js/Express)

**Primary Purpose**: Strava data synchronization + conversational AI chat

**Technology Stack**:
- **Runtime**: Node.js on Cloud Run
- **Database**: Supabase (PostgreSQL + pgvector)
- **AI**: Claude 3 Opus (Anthropic) + OpenAI embeddings
- **Deployment**: Google Cloud Run
- **Production URL**: https://strava-sync-a2xd4ppmsq-uc.a.run.app

**Current Capabilities**:
- ✅ Strava OAuth integration
- ✅ Activity sync (full history + incremental)
- ✅ Background job processing
- ✅ **Conversational Chat API** (NEW - 2025-12-01)
  - Natural language Q&A about training history
  - Semantic search over 712 activities
  - RAG (Retrieval Augmented Generation)
  - Temporal query detection ("when did I last...")

**Database Schema**:
```sql
-- Core tables
activities (712 rows) - Full Strava activity data
athletes - Athlete profiles
commitments - Daily training commitments
goals - Training goals

-- AI-specific tables (NEW)
activity_embeddings - OpenAI embeddings (1536 dimensions)
chat_conversations - Chat history
athlete_ai_profiles - AI memory/preferences
```

**API Endpoints**:
```
GET  /health                    - Health check
POST /api/oauth/authorize       - Strava OAuth
POST /api/sync                  - Full activity sync
POST /api/sync-beta            - Recent 20 activities
GET  /api/jobs/:jobId          - Job status
POST /api/chat                  - Conversational chat (PUBLIC)
GET  /api/chat/history/:id     - Chat history
```

**Chat Implementation**:
```javascript
// strava-data/src/services/ChatService.js
class ChatService {
    async chat(athleteId, userQuery) {
        // 1. Build context
        const context = {
            profile: await getAthleteProfile(athleteId),
            recentActivities: await getRecentActivities(athleteId, 14),
            relevantActivities: await searchSimilarActivities(userQuery),
            stats: await calculateStats(athleteId)
        };

        // 2. Detect temporal queries
        const isTemporalQuery = /\b(last|recent|latest)\b/i.test(userQuery);
        if (isTemporalQuery) {
            // Sort by date instead of just similarity
        }

        // 3. Call Claude with context
        const prompt = formatPrompt(userQuery, context);
        const answer = await callClaude(prompt);

        // 4. Store conversation
        await storeConversation(athleteId, userQuery, answer);

        return { answer, context };
    }
}
```

**Embedding Strategy**:
- **Model**: OpenAI text-embedding-ada-002 (1536 dimensions)
- **What's Embedded**: Activity summaries (not raw GPS data)
- **Summary Format**: "13.1 mile run at 8:30/mi pace with avg HR 155 on Monday, Nov 18, 2025"
- **Search**: pgvector with HNSW index, cosine similarity
- **Context Window**: Core memory + recent 14 days + top 5 relevant activities

---

### 2. runaway-coach (Python/FastAPI)

**Primary Purpose**: Structured running analysis via multi-agent AI system

**Technology Stack**:
- **Runtime**: Python 3.11 with FastAPI
- **AI Framework**: LangGraph + Claude (Anthropic)
- **Agents**: Custom agent architecture with AsyncAnthropic
- **Deployment**: Google Cloud Run (or Cloud Functions)

**Current Capabilities**:
- ✅ Multi-agent workflow orchestration
- ✅ Specialized analysis agents:
  - **Performance Analysis**: Trends, metrics, consistency
  - **Goal Strategy**: Feasibility, progress, timeline
  - **Pace Optimization**: Zone recommendations, HR mapping
  - **Workout Planning**: Personalized workout creation
- ✅ Supervisor agent for coordination
- ✅ Rule-based fallbacks (when Claude unavailable)

**Agent Architecture**:
```python
# core/workflows/runner_analysis_workflow.py
class RunnerAnalysisWorkflow:
    """
    Sequential workflow:
    Performance → Goal → Pace → Workout → Synthesis
    """

    def build_graph(self):
        workflow = StateGraph(RunnerAnalysisState)

        # Add nodes (agents)
        workflow.add_node("performance", self.analyze_performance)
        workflow.add_node("goal", self.analyze_goal)
        workflow.add_node("pace", self.optimize_pace)
        workflow.add_node("workout", self.plan_workout)
        workflow.add_node("synthesize", self.synthesize_recommendations)

        # Define edges (flow)
        workflow.set_entry_point("performance")
        workflow.add_edge("performance", "goal")
        workflow.add_edge("goal", "pace")
        workflow.add_edge("pace", "workout")
        workflow.add_edge("workout", "synthesize")
        workflow.add_edge("synthesize", END)

        return workflow.compile()
```

**API Endpoints** (Python FastAPI):
```
GET  /                          - Health check
POST /analyze                   - Full analysis workflow
POST /analyze/performance       - Performance analysis only
POST /analyze/goal              - Goal strategy only
POST /analyze/pace              - Pace optimization only
POST /analyze/workout           - Workout planning only
```

**Analysis Output Structure**:
```json
{
    "performance_metrics": {
        "weekly_mileage": 35.2,
        "avg_pace": "8:30",
        "consistency_score": 0.85,
        "trends": { "mileage": "increasing", "pace": "stable" }
    },
    "goal_assessment": {
        "current_goal": "Marathon under 4:00",
        "feasibility": "achievable",
        "progress": 0.65,
        "recommendations": [...]
    },
    "pace_zones": {
        "easy": "9:00-9:30",
        "tempo": "8:00-8:20",
        "interval": "7:00-7:30"
    },
    "workout_plan": {
        "this_week": [...],
        "next_week": [...],
        "reasoning": "..."
    },
    "synthesis": {
        "overall_assessment": "...",
        "priorities": [...],
        "action_items": [...]
    }
}
```

---

## Current Integration Points

### iOS App → Services

```
┌─────────────────────────────┐
│ Runaway iOS App             │
│ (Swift/SwiftUI)             │
└───────┬────────────┬────────┘
        │            │
        │            └──────────────────┐
        │                               │
        ▼                               ▼
┌───────────────────┐         ┌─────────────────┐
│ strava-data       │         │ runaway-coach   │
│ (Node.js)         │         │ (Python)        │
│                   │         │                 │
│ Chat via:         │         │ Analysis via:   │
│ ChatService.swift │         │ (Not integrated │
│                   │         │  yet)           │
└───────────────────┘         └─────────────────┘
        │
        ▼
┌───────────────────┐
│ Supabase          │
│ - PostgreSQL      │
│ - pgvector        │
│ - Real-time       │
└───────────────────┘
```

### Current Data Flow

**Chat Request Flow**:
```
1. User asks: "When did I last run over 10 miles?"
   ↓
2. iOS ChatService.swift
   POST https://strava-sync-a2xd4ppmsq-uc.a.run.app/api/chat
   { athlete_id: 94451852, message: "..." }
   ↓
3. strava-data ChatService.js
   - Fetch recent activities (14 days)
   - Semantic search for relevant activities
   - Build context (stats, profile)
   ↓
4. Claude 3 Opus (via Anthropic API)
   - Receives context + query
   - Generates natural language response
   ↓
5. Response to iOS
   {
     "answer": "Your last 10+ mile run...",
     "context": { recentActivitiesCount: 8, ... },
     "timestamp": "..."
   }
```

**Analysis Request Flow (Conceptual - not yet implemented)**:
```
1. User requests: "Analyze my performance"
   ↓
2. iOS → runaway-coach
   POST /analyze
   { athlete_id, timeframe, focus_area }
   ↓
3. runaway-coach workflow
   - Performance Agent analyzes trends
   - Goal Agent assesses progress
   - Pace Agent recommends zones
   - Workout Agent creates plan
   - Supervisor synthesizes
   ↓
4. Structured response to iOS
   { performance_metrics, goal_assessment, ... }
```

---

## Service Boundaries & Responsibilities

### What Each Service Should Do

#### strava-data (Data + Chat)
**DO**:
- ✅ Strava OAuth and data synchronization
- ✅ Activity storage and management
- ✅ Conversational Q&A about training history
- ✅ Semantic search over activities
- ✅ Simple insights ("how many miles this week?")
- ✅ Chat history and conversation memory

**DON'T**:
- ❌ Complex multi-agent workflows
- ❌ Structured analysis reports
- ❌ Workout plan generation (let agents do this)
- ❌ Goal feasibility calculations (let agents do this)

#### runaway-coach (Analysis + Recommendations)
**DO**:
- ✅ Performance trend analysis
- ✅ Goal strategy and progress tracking
- ✅ Pace zone optimization
- ✅ Workout plan generation
- ✅ Structured recommendations
- ✅ Multi-agent workflows

**DON'T**:
- ❌ Strava data sync (let strava-data handle this)
- ❌ Activity storage (query strava-data instead)
- ❌ Conversational chat (let strava-data handle this)
- ❌ OAuth flows

---

## Future Integration Strategies

### Strategy 1: Tool Calling (Short-term, Easy)

**How it works**:
```javascript
// In strava-data ChatService.js

const tools = [
    {
        name: "analyze_performance",
        description: "Get detailed performance analysis with trends and metrics",
        input_schema: {
            type: "object",
            properties: {
                athlete_id: { type: "number" },
                timeframe_days: { type: "number", default: 30 }
            }
        }
    },
    {
        name: "create_workout_plan",
        description: "Generate a personalized workout plan",
        input_schema: {
            type: "object",
            properties: {
                athlete_id: { type: "number" },
                goal: { type: "string" },
                weeks: { type: "number", default: 4 }
            }
        }
    }
];

// When Claude wants analysis
const response = await anthropic.messages.create({
    model: "claude-3-opus-20240229",
    max_tokens: 4096,
    tools: tools,
    messages: [{ role: "user", content: prompt }]
});

// If Claude calls a tool
if (response.stop_reason === "tool_use") {
    const toolCall = response.content.find(c => c.type === "tool_use");

    if (toolCall.name === "analyze_performance") {
        // Call runaway-coach
        const analysis = await fetch('runaway-coach-url/analyze/performance', {
            method: 'POST',
            body: JSON.stringify(toolCall.input)
        });

        // Feed result back to Claude
        const finalResponse = await anthropic.messages.create({
            model: "claude-3-opus-20240229",
            messages: [
                { role: "user", content: prompt },
                { role: "assistant", content: response.content },
                { role: "user", content: [
                    {
                        type: "tool_result",
                        tool_use_id: toolCall.id,
                        content: JSON.stringify(analysis)
                    }
                ]}
            ]
        });

        return finalResponse.content[0].text;
    }
}
```

**Benefits**:
- ✅ Seamless integration from user perspective
- ✅ Claude decides when to use structured analysis
- ✅ Leverages both services' strengths
- ✅ No iOS changes needed

**When to use**:
- User asks: "How am I doing?" → Claude calls `analyze_performance`
- User asks: "Create a plan for marathon" → Claude calls `create_workout_plan`
- User asks: "When did I last run 10 miles?" → Just RAG, no tool call

---

### Strategy 2: Shared Embedding Store (Medium-term)

**How it works**:
```python
# In runaway-coach agents
from supabase import create_client

class PerformanceAnalysisAgent:
    def __init__(self):
        # Connect to strava-data's Supabase
        self.supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

    async def get_relevant_activities(self, query: str):
        # Use strava-data's embeddings
        embedding = await openai.embeddings.create(
            input=query,
            model="text-embedding-ada-002"
        )

        # Search using match_activities function
        result = await self.supabase.rpc(
            'match_activities',
            {
                'query_embedding': embedding.data[0].embedding,
                'match_threshold': 0.7,
                'match_count': 10
            }
        ).execute()

        return result.data
```

**Benefits**:
- ✅ Agents can use semantic search
- ✅ Single source of truth for embeddings
- ✅ No duplicate embedding costs
- ✅ Consistent activity retrieval

---

### Strategy 3: Event-Driven Updates (Long-term)

**Architecture**:
```
Strava Webhook → strava-data → Pub/Sub → runaway-coach
                      ↓
                  Supabase
                      ↓
                  (triggers)
                      ↓
              Update embeddings
              Update agent memory
```

**Benefits**:
- ✅ Real-time updates
- ✅ Loosely coupled services
- ✅ Scalable architecture
- ✅ Event sourcing for debugging

---

## API Keys & Costs

### Current API Usage

**Anthropic (Claude)**:
- **strava-data**: Chat responses (~$0.015 per chat)
- **runaway-coach**: Multi-agent analysis (~$0.10 per full analysis)
- **Monthly estimate**: $50-200 depending on usage

**OpenAI (Embeddings)**:
- **strava-data**: Activity embeddings
- **Cost**: ~$0.10 per 1000 activities (one-time)
- **Ongoing**: ~$0.01 per new activity

**Infrastructure**:
- **Cloud Run (both services)**: ~$10-30/month
- **Supabase**: Free tier (currently sufficient)

### Optimization Opportunities

1. **Caching**:
   - Cache frequently asked questions
   - Cache analysis results (24 hour TTL)
   - Reduce duplicate Claude calls

2. **Model Selection**:
   - Use Claude Haiku for simple queries (~10x cheaper)
   - Reserve Opus for complex analysis
   - Use Claude Sonnet for medium complexity

3. **Batch Processing**:
   - Batch embed new activities weekly instead of real-time
   - Pre-generate common analyses during off-peak hours

---

## Deployment Architecture

### Current State

```
┌────────────────────────────────────────────────┐
│ Google Cloud Project: hermes-2024              │
│                                                 │
│  ┌──────────────────┐  ┌────────────────────┐ │
│  │ strava-sync      │  │ runaway-coach      │ │
│  │ (Cloud Run)      │  │ (Not deployed yet) │ │
│  │                  │  │                    │ │
│  │ • Node.js        │  │ • Python/FastAPI  │ │
│  │ • 2Gi RAM        │  │ • TBD             │ │
│  │ • 2 CPU          │  │                   │ │
│  │ • Public access  │  │                   │ │
│  └──────────────────┘  └────────────────────┘ │
│                                                 │
│  ┌──────────────────────────────────────────┐  │
│  │ Secret Manager                            │  │
│  │ • ANTHROPIC_API_KEY                       │  │
│  │ • OPENAI_API_KEY                          │  │
│  │ • SUPABASE_SERVICE_KEY                    │  │
│  │ • STRAVA_CLIENT_ID/SECRET                 │  │
│  └──────────────────────────────────────────┘  │
└────────────────────────────────────────────────┘

┌────────────────────────────────────────────────┐
│ Supabase (External)                             │
│                                                  │
│ • PostgreSQL + pgvector                         │
│ • Real-time subscriptions                       │
│ • Row-level security                            │
│ • 712 activities + embeddings                   │
└────────────────────────────────────────────────┘
```

### Recommended Deployment

```
Both services on Cloud Run:

strava-data:
  - Current setup ✅
  - Public /api/chat endpoint
  - IAM auth for /api/sync endpoints

runaway-coach:
  - Deploy as Cloud Run service
  - Private (only accessible from strava-data)
  - OR: Deploy as Cloud Function (for cost optimization)
  - Use service-to-service authentication
```

---

## Decision Log

### 2025-12-01: Keep Services Separate

**Decision**: Maintain two independent services with clear boundaries

**Rationale**:
1. **Different tech stacks optimized for different tasks**:
   - Node.js excellent for I/O-heavy operations (sync, API)
   - Python better for ML/agent workflows (LangGraph, scikit-learn)

2. **Already working well**:
   - strava-data handles sync + chat successfully
   - runaway-coach has mature agent system

3. **Future flexibility**:
   - Can integrate via tool calling when needed
   - Can deploy/scale independently
   - Can migrate gradually if needed

**Trade-offs**:
- ❌ Two services to maintain
- ❌ Slightly more complex architecture
- ✅ Clean separation of concerns
- ✅ Best tool for each job
- ✅ Independent deployment

---

## Next Steps

### Immediate (No Integration Required)
1. ✅ Document architecture (this document)
2. Deploy runaway-coach to Cloud Run
3. Test both services independently
4. Monitor costs and performance

### Short-term (Basic Integration)
1. Add tool calling to strava-data chat
2. Enable Claude to invoke runaway-coach agents
3. Test end-to-end flow:
   - "How am I doing?" triggers performance analysis
   - "Create a plan" triggers workout agent

### Medium-term (Shared Resources)
1. Have runaway-coach query strava-data's embeddings
2. Implement shared caching layer
3. Add event-driven updates

### Long-term (Advanced Features)
1. Multi-modal analysis (combine chat + structured)
2. Proactive coaching (agents suggest workouts)
3. Real-time feedback during runs

---

## Summary

**Current State**: Two complementary AI services
- **strava-data**: Chat + data sync ✅ Production
- **runaway-coach**: Analysis + agents ⏳ Ready to deploy

**Integration Strategy**: Tool calling (Claude decides when to use agents)

**Philosophy**: Best tool for each job, integrated when needed

**Next Action**: Keep as-is, document clearly, integrate gradually

---

## References

- [AI_COACHING_ROADMAP.md](./AI_COACHING_ROADMAP.md) - Overall AI features roadmap
- [strava-data README](../strava-data/README.md) - Data sync service docs
- [runaway-coach CLAUDE.md](../runaway-coach/CLAUDE.md) - Agent system docs
