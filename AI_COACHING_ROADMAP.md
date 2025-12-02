# Runaway AI Coaching Roadmap
**Living Document - Updated as Features are Implemented**

---

## Executive Summary

We're building the first truly conversational running coach - an AI companion that understands each athlete's complete history, adapts to life's unpredictability, and answers questions in natural language. While competitors offer dashboards with AI-generated summaries, we're creating an intelligent system that acts as a persistent coach.

**Market Gap**: No major platform offers "ask anything about my running history" capability. Strava's Athlete Intelligence and WHOOP Coach are shallow implementations that don't leverage the full potential of modern LLMs.

**Our Advantage**: Existing infrastructure (Strava integration, Supabase database, weather/HR data, multi-agent system) + Claude API = unprecedented coaching capability.

---

## Current State (As of 2025-12-01)

### Infrastructure ✅
- **iOS App**: SwiftUI-based with widget extension
- **Backend**: Supabase (PostgreSQL) for data storage with RLS
- **Strava Integration**: OAuth flow + data sync via strava-data service
- **Data Sync Service**: Node.js service on Cloud Run (strava-data)
- **Recent Features**:
  - ✅ Sync-beta endpoint (limits to 20 newest activities)
  - ✅ Job-based background processing with checkpointing
  - ✅ Activity, athlete, commitment, and goal data models

### Data Assets ✅
- Complete Strava activity history (GPS, HR, pace, cadence, elevation)
- Athlete profiles and performance metrics
- Daily commitments and goal tracking
- Real-time sync via RealtimeService

### Technical Capabilities ✅
- Multi-agent system architecture (mentioned in analysis)
- Runaway Coach API for enhanced analysis
- Widget data sharing via app groups
- Background job processing

---

## Strategic Vision

### Core Differentiation
**"What should I do today, given everything you know about me?"**

We're building:
1. **Conversational AI Coach**: Natural language interaction, not dashboards
2. **Persistent Athlete Memory**: Understanding that grows over weeks/months
3. **Life-Aware Training**: Integration with calendar, stress, travel, family
4. **Underserved Segments**: Masters athletes, injury recovery, busy parents

### What Competitors Don't Offer
- ❌ True "ask anything" about running history
- ❌ Automated training journal/narrative generation
- ❌ Cross-platform data unification (critical as Strava locks down API)
- ❌ Conversational training adjustment ("I'm traveling next week")
- ❌ Personalized explanation for every recommendation
- ❌ Age-specific coaching (40+, 50+, 60+)

---

## Technical Architecture

### Memory System Design
**Approach**: MemGPT-style architecture with 4-tier memory

```
┌─────────────────────────────────────────┐
│ CORE MEMORY (always in context)        │
│ - Athlete profile & preferences         │
│ - Current training phase                │
│ - Recent injury history                 │
│ - Communication style preferences       │
└─────────────────────────────────────────┘
           ↓
┌─────────────────────────────────────────┐
│ RECENT HISTORY (summarized)             │
│ - Last 14 days of workouts              │
│ - Key metrics & trends                  │
└─────────────────────────────────────────┘
           ↓
┌─────────────────────────────────────────┐
│ VECTOR-EMBEDDED ARCHIVAL                │
│ - Full workout history                  │
│ - Searchable by similarity (pgvector)   │
│ - Hierarchical summarization            │
└─────────────────────────────────────────┘
           ↓
┌─────────────────────────────────────────┐
│ PERFORMANCE TIME-SERIES                 │
│ - CTL/ATL/TSB calculations              │
│ - Rolling fitness indicators            │
│ - Trend analysis                        │
└─────────────────────────────────────────┘
```

### Hybrid ML + LLM Architecture
- **ML Models**: Time-series analysis, anomaly detection, forecasting
  - Lag-Llama for performance predictions with uncertainty
  - Custom models for form degradation detection
- **Claude API**: Natural language interface, narrative generation, coaching
  - Transforms ML insights into conversational recommendations
  - Explains the "why" behind every suggestion

### Summarization Pipeline
```
Daily Workouts → Daily Summaries (embeddings)
     ↓
Weekly Summaries → Training Block Overviews
     ↓
Training Blocks → Seasonal Narratives
```

**Why**: Prevents context window overflow while preserving patterns

### Multi-Agent Coordination
Specialized agents routing based on intent:
- **Analysis Agent**: Post-run insights, pattern recognition
- **Planning Agent**: Training plan generation & adaptation
- **Motivation Agent**: Engagement, streak management, behavioral psychology
- **Q&A Agent**: Historical queries, "ask anything" capability
- **Memory Manager**: Updates core memory, triggers summarization

---

## Implementation Roadmap

### Phase 1: Conversational Foundation (Months 1-2)
**Goal**: Establish natural language Q&A and persistent memory

#### Feature 1.1: AI Training Chat ✅
**Status**: ✅ **COMPLETED** (2025-12-01)
**Priority**: 🔴 Critical - Core Differentiator

**Capabilities**:
- "When did I last run over 10 miles?" ✅
- "How does my pace this month compare to last year?" ✅
- "Why did that run feel so hard?" (cross-reference HR, weather, sleep) ✅
- "Am I running too much this week?" ✅

**Implementation**:
- [x] Supabase pgvector setup for workout embeddings
- [x] Activity summarization service (daily → weekly → monthly)
- [x] Claude prompt engineering for Q&A with structured data
- [x] RAG implementation over workout history
- [x] iOS chat interface component (repurposed existing UI)
- [x] Backend endpoint for chat conversations

**Actual Implementation Details** (Completed):
- **Embeddings**: 712 activities embedded using OpenAI ada-002 (1536 dimensions)
- **Storage**: pgvector extension in Supabase with HNSW index
- **Summarization**: ActivitySummarizer service (meters→miles, pace formatting, HR zones)
- **Search**: Semantic search with temporal query detection (prioritizes recency for "last" queries)
- **LLM**: Claude 3 Opus via Anthropic API
- **Backend**: Node.js service deployed to Cloud Run with public /api/chat endpoint
- **Context**: Recent 14 days + top 5 semantically relevant activities + athlete stats
- **iOS Integration**: Updated existing ChatService to call new backend
- **Production URL**: https://strava-sync-a2xd4ppmsq-uc.a.run.app/api/chat

**Technical Details**:
- Store embeddings in Supabase using pgvector extension
- Embed workout summaries (not raw GPS data) for efficient retrieval
- Use Claude with tool calling for structured queries (e.g., "get activities between dates")
- Context window: Core memory + recent 14 days + retrieved relevant workouts

**Dependencies**:
- Supabase pgvector extension
- Claude API integration
- Activity data already in database ✅

---

#### Feature 1.2: Persistent Athlete Profile ⏳
**Status**: Not Started
**Priority**: 🔴 Critical - Foundation for All Features

**Core Memory Blocks**:
```json
{
  "athlete_id": "uuid",
  "profile": {
    "age": 42,
    "experience_level": "intermediate",
    "goals": ["sub-4:00 marathon", "stay injury-free"],
    "preferences": {
      "coaching_style": "supportive",
      "preferred_distances": ["5k", "10k", "half marathon"],
      "available_days": ["mon", "wed", "fri", "sat", "sun"]
    }
  },
  "current_training": {
    "phase": "base building",
    "weekly_mileage": 35,
    "target_race": "2025-05-15",
    "race_distance": "half marathon"
  },
  "injury_history": [
    {
      "type": "IT band syndrome",
      "date": "2024-08-01",
      "status": "recovered",
      "notes": "Caused by rapid mileage increase"
    }
  ],
  "communication_prefs": {
    "tone": "encouraging",
    "verbosity": "concise",
    "explanation_depth": "moderate"
  }
}
```

**Implementation**:
- [ ] Extend Athlete model with AI-specific fields
- [ ] Profile setup wizard in iOS app
- [ ] Core memory management service
- [ ] Auto-update mechanisms (e.g., detect training phase from activity patterns)

**Database Schema**:
- New table: `athlete_ai_profiles`
- Fields: core_memory (JSONB), last_updated, version
- Foreign key to existing athletes table

---

#### Feature 1.3: Automated Training Journal ⏳
**Status**: Not Started
**Priority**: 🟡 High - Unique Feature

**Capabilities**:
- Daily: "Today's 6-mile tempo run showed strong progression—your average pace of 7:45/mi was 15 seconds faster than last week's tempo despite higher humidity (78% vs 65%). HR stayed controlled in Z3, indicating improved aerobic efficiency."

- Weekly: "This week's training marked a breakthrough in your marathon prep. You hit 42 miles total with quality work on Tuesday (8x800m at 6:40 pace) and Saturday (16-mile long run averaging 8:30/mi). Your body responded well—morning HRV stayed above baseline all week. The only concern: Friday's easy run showed elevated HR for the pace, suggesting you needed that rest day."

- Monthly: Narrative summaries identifying patterns, progress, setbacks

**Implementation**:
- [ ] Claude prompt templates for daily/weekly/monthly summaries
- [ ] Automated generation service (runs daily at midnight UTC)
- [ ] Journal storage in Supabase
- [ ] iOS journal view with timeline
- [ ] Export to PDF/text

**Prompt Structure**:
```
You are an experienced running coach reviewing an athlete's training.

ATHLETE CONTEXT:
{core_memory}

RECENT TRAINING (last 14 days):
{activity_summaries}

TODAY'S WORKOUT:
{detailed_activity_data}

ENVIRONMENTAL FACTORS:
- Weather: {temp}, {humidity}, {wind}
- Sleep: {hours} (HRV: {hrv_score})

Generate a concise, encouraging journal entry (2-3 sentences) that:
1. Highlights what went well
2. Identifies any concerning patterns
3. Provides one actionable insight
```

---

### Phase 2: Adaptive Training (Months 3-4)
**Goal**: Dynamic training plans that respond to life, recovery, and performance

#### Feature 2.1: Conversational Training Adjustment ⏳
**Status**: Not Started
**Priority**: 🟡 High

**Capabilities**:
- User: "I'm traveling next week for work"
- AI: "I see you're heading out Tuesday-Thursday. I've moved your interval session to Monday and your long run to Sunday. Wednesday and Thursday will be easy runs you can do from the hotel gym on a treadmill. Your weekly volume stays at 38 miles but intensity is redistributed."

- User: "That last workout felt really hard"
- AI: "I noticed your HR was 8 bpm higher than expected for that pace, and you mentioned feeling tired. Let's dial back tomorrow's tempo to an easy run and reassess Friday. This might be accumulated fatigue from your strong weekend."

**Implementation**:
- [ ] Training plan data model (workouts, intensity zones, progression)
- [ ] Plan generation service using Claude
- [ ] Re-planning logic with constraint satisfaction
- [ ] Conversational interface for adjustments
- [ ] Calendar integration (Google/Apple Calendar API)

**Technical Approach**:
- Store training plans as structured JSON with flexibility parameters
- Claude generates plans based on: goal race, current fitness, available time, preferences
- Re-planning maintains periodization principles while adapting workouts
- Integration with life calendar to detect conflicts automatically

---

#### Feature 2.2: HRV-Guided Training Readiness ⏳
**Status**: Not Started
**Priority**: 🟡 High

**Capabilities**:
- Morning readiness score: "Your HRV is 15% below baseline and sleep was only 5.5 hours. Today's planned interval session is shifted to an easy run. Your body needs recovery more than stimulus right now."

- Trend detection: "Your HRV has been declining for 5 days despite adequate sleep. This suggests accumulated training stress. Let's make this week a recovery week—reduce volume by 30% and skip all intensity."

**Implementation**:
- [ ] HRV data integration (WHOOP, Oura, Apple Health)
- [ ] Baseline calculation and trend analysis
- [ ] Training readiness algorithm
- [ ] Workout adjustment rules based on readiness
- [ ] iOS widget showing daily readiness

**Data Sources**:
- Apple Health HRV data
- Sleep duration and quality scores
- Resting heart rate trends
- Self-reported fatigue/soreness (optional input)

---

#### Feature 2.3: Weather-Aware Training ⏳
**Status**: Not Started
**Priority**: 🟢 Medium

**Capabilities**:
- "Tomorrow's tempo run faces 90°F heat and high humidity. I've moved it to 6 AM when it'll be 72°F. Alternatively, we can shift to Tuesday when a cold front arrives."

- "Rain forecasted all week. I've moved your long run to the treadmill and adjusted pace expectations accordingly (treadmill runs typically feel 10-15 seconds/mile harder)."

**Implementation**:
- [ ] Weather API integration (existing or new)
- [ ] Heat/humidity impact models for pace adjustment
- [ ] Automatic workout rescheduling suggestions
- [ ] iOS notifications for weather-related changes

**Existing Infrastructure**:
- Weather data may already be integrated (mentioned in analysis)
- Need to verify current implementation

---

### Phase 3: Advanced Analysis (Months 5-6)
**Goal**: Deep insights from ML models transformed into actionable coaching

#### Feature 3.1: Form Degradation Detection ⏳
**Status**: Not Started
**Priority**: 🟢 Medium

**Capabilities**:
- Real-time during run: "Your cadence dropped to 162 spm in the last mile (down from 175). This indicates fatigue—consider walking for 1 minute."

- Post-run: "Your heart rate decoupled from pace in the second half—HR drifted 8% while pace only slowed 2%. This suggests you're approaching your aerobic threshold limit. Future long runs should be 15-20 seconds/mile slower."

**Metrics Tracked**:
- Cadence drift (target: >165 spm)
- Ground contact time increase
- Heart rate decoupling (HR drift vs pace drift)
- Vertical oscillation changes
- Pace variability on flat terrain

**Implementation**:
- [ ] Real-time sensor data processing (if available from wearable)
- [ ] Post-run batch analysis of time-series data
- [ ] ML model for anomaly detection in metrics
- [ ] Claude narrative generation from structured signals
- [ ] iOS alerts and post-run insights

**Data Requirements**:
- Cadence: Available from GPS watch or phone accelerometer
- HR: Available from Strava/Apple Health
- Ground contact time: Requires advanced watch (Garmin, COROS)

---

#### Feature 3.2: Performance Forecasting with Uncertainty ⏳
**Status**: Not Started
**Priority**: 🟢 Medium

**Capabilities**:
- "Based on your current fitness, I predict a half marathon finish time of 1:45:30 ± 4 minutes (90% confidence). Key variables: your recent 10-mile tempo suggests strong lactate threshold, but weekly volume is 15% below optimal for this goal."

- "If you maintain current training, there's a 75% probability you'll hit your sub-4:00 marathon goal. Increasing weekly long run to 18+ miles would raise that to 85%."

**Implementation**:
- [ ] Lag-Llama time-series foundation model integration
- [ ] Training load calculation (CTL/ATL/TSB)
- [ ] Race prediction algorithms (Riegel, Vdot, custom ML)
- [ ] Uncertainty quantification (probability distributions, not point estimates)
- [ ] Scenario analysis ("what if I increase mileage 10%?")
- [ ] iOS visualization of predictions with confidence intervals

**Technical Stack**:
- Lag-Llama via HuggingFace (~4GB GPU memory for inference)
- Could run on backend service, not iOS device
- Alternative: TimeGPT-1 API for commercial solution

---

#### Feature 3.3: Causal Training Response Analysis ⏳
**Status**: Not Started
**Priority**: 🟢 Low (Advanced)

**Capabilities**:
- "Adding a second interval session per week caused a 12-second/mile improvement in tempo pace (p<0.05, causal effect isolated). However, it also increased injury risk markers by 18%."

- "Your body responds better to higher volume / lower intensity vs lower volume / higher intensity. Athletes with your profile see 25% greater fitness gains from the former approach."

**Implementation**:
- [ ] TMLE (Targeted Maximum Likelihood Estimation) implementation
- [ ] Counterfactual analysis framework
- [ ] Individual response modeling (not population averages)
- [ ] Long-term data collection for statistical power
- [ ] Experiment design suggestions

**Research Application**:
- Requires months of structured training data
- Phase 3+ feature, needs solid data foundation first

---

### Phase 4: Engagement & Retention (Months 7-8)
**Goal**: Behavioral psychology-driven features that keep athletes engaged

#### Feature 4.1: Intelligent Streak System ⏳
**Status**: Not Started
**Priority**: 🟡 High - Critical for Retention

**Capabilities**:
- **Flexible completion**: Any activity counts (run, walk, strength, yoga)
- **Recovery-aware**: Streak doesn't break on planned rest days
- **Multi-dimensional**: Separate streaks for workouts, sleep, nutrition
- **Loss aversion**: Visual "streak shield" that grows more valuable over time
- **Redemption**: One "freeze" per month to save a streak

**Why This Works**:
- Duolingo shows 7-day streaks = 3.6x engagement
- Research: Loss aversion > rewards for motivation
- Current platforms punish rest days (poor design)

**Implementation**:
- [ ] Flexible streak definition (user configurable)
- [ ] Streak storage with type, start_date, current_count
- [ ] Freeze/shield mechanic (limited uses)
- [ ] iOS widget showing current streaks
- [ ] Push notifications: "Your 42-day streak is at risk"

**Database Schema**:
- Table: `athlete_streaks`
- Fields: type, count, start_date, freeze_available, last_activity_date

---

#### Feature 4.2: Personality-Matched Coaching ⏳
**Status**: Not Started
**Priority**: 🟡 High - Unique Differentiator

**Coaching Styles**:
- **Tough Love**: "That pace wasn't easy—it was tempo. You need to actually recover on recovery days or you'll burn out."
- **Supportive**: "I know that run felt hard, and that's completely okay! Your body is adapting. Rest tomorrow and you'll come back stronger."
- **Analytical**: "Your lactate threshold appears to be at 165 bpm based on today's interval session. This is 3 bpm higher than last month, indicating positive adaptation."
- **Playful**: "You crushed that workout! 🔥 Your watch probably needs ice after those splits. Tomorrow: chill mode activated."

**Implementation**:
- [ ] Onboarding quiz to determine coaching style preference
- [ ] Claude system prompts tailored to personality
- [ ] User ability to switch styles anytime
- [ ] A/B testing different tones for engagement

**Prompt Engineering**:
```
COACHING PERSONALITY: {tough_love|supportive|analytical|playful}

TOUGH_LOVE_RULES:
- Be direct and honest, even if uncomfortable
- Point out mistakes clearly
- High expectations, low tolerance for excuses

SUPPORTIVE_RULES:
- Always find something positive first
- Acknowledge effort over outcome
- Use encouraging language
```

---

#### Feature 4.3: Variable Reward System ⏳
**Status**: Not Started
**Priority**: 🟢 Medium

**Capabilities**:
- **Surprise achievements**: "Congrats! You just earned the 'Early Bird' badge for 10 runs before 6 AM" (user didn't know it existed)
- **Mystery challenges**: "Complete this week's Mystery Challenge to unlock a reward" (revealed after completion)
- **Random bonus points**: Sometimes a run gives 100 points, sometimes 250 (unpredictable)
- **Loot box mechanic**: After milestones, "open" a reward (could be badge, training insight, or motivational message)

**Why This Works**:
- B.F. Skinner: Variable rewards > predictable rewards
- Dopamine releases during anticipation, not receipt
- Instagram delays likes for burst delivery

**Implementation**:
- [ ] Achievement system with hidden achievements
- [ ] Point randomization algorithm
- [ ] Mystery challenge generation
- [ ] Reward notification system
- [ ] Social sharing of rare achievements

**Ethical Consideration**:
- Use for motivation, not manipulation
- Transparent about randomness
- No financial incentives (avoid gambling mechanics)

---

### Phase 5: Underserved Segments (Months 9-12)
**Goal**: Tailor features for markets competitors ignore

#### Feature 5.1: Masters Athlete Specialization ⏳
**Status**: Not Started
**Priority**: 🟡 High - 50%+ of Marathon Market

**Key Differences for 40+/50+/60+ Athletes**:
- **10-day training cycles** instead of 7-day (better recovery alignment)
- **Different hard/easy patterns**: 2 hard days per 10 days instead of 3 per 7
- **Age-adjusted paces**: VO2max declines ~10% per decade
- **Enhanced recovery protocols**: More emphasis on sleep, nutrition, cross-training
- **Injury prevention focus**: Longer warm-ups, more mobility work

**Implementation**:
- [ ] Age-aware training plan generation
- [ ] 10-day cycle option in planning algorithms
- [ ] Age-graded performance calculations (built-in comparison to peers)
- [ ] Masters-specific injury prevention content
- [ ] Community features for age groups

**Claude Prompting**:
```
ATHLETE AGE: 52
MASTERS ATHLETE ADJUSTMENTS:
- Use 10-day training cycles
- Reduce hard day frequency: max 2 per 10 days
- Increase recovery emphasis (HRV, sleep critical)
- Add mobility/strength work requirements
- Age-grade all paces (compare to 52-year-old standards)
```

---

#### Feature 5.2: Return-from-Injury Protocol ⏳
**Status**: Not Started
**Priority**: 🟡 High

**Capabilities**:
- **Conversational injury intake**: "Tell me about your injury" → AI asks clarifying questions
- **Progressive load management**: Automatic percentage-based progressions (e.g., 10% weekly increase)
- **Real-time discomfort monitoring**: "How does your knee feel?" prompts during/after runs
- **Red flag detection**: "Sharp pain" → immediate stop recommendation
- **Physical therapy integration**: Tracks prescribed exercises alongside running

**Common Injuries Supported**:
- IT band syndrome
- Plantar fasciitis
- Achilles tendinitis
- Runner's knee (patellofemoral pain)
- Shin splints
- Stress fractures (post-healing)

**Implementation**:
- [ ] Injury profile data model (type, severity, PT exercises, pain levels)
- [ ] Conservative progression algorithms (Bone stress injury protocol: 10% increases)
- [ ] Pain tracking interface (1-10 scale, location, type)
- [ ] Claude-powered injury education and reassurance
- [ ] Integration with PT/doctor recommendations

**Safety**:
- Disclaimer: Not medical advice
- Encourage PT/doctor consultation
- Err on side of caution with load increases

---

#### Feature 5.3: Busy Parent/Professional Mode ⏳
**Status**: Not Started
**Priority**: 🟡 High - Massive Market

**Capabilities**:
- **Flexible plan execution**: "Didn't have time for the long run Saturday? Let's split it into two runs today and tomorrow."
- **Time-boxed workouts**: "You have 35 minutes? Here's an efficient tempo block that hits training goals."
- **Life calendar integration**: Knows about work travel, kids' activities, date nights
- **Minimal viable training**: "If you can only run 3x this week, here are the 3 workouts that matter most."
- **Family coordination**: Plan workouts around partner's schedule

**User Quote from Research**:
> "I have a full time job and two small children, so the ability to be flexible is huge."

**Implementation**:
- [ ] Calendar API integration (Google Calendar, Apple Calendar)
- [ ] Workout length constraints (user sets available time)
- [ ] Re-planning logic that maintains key workouts
- [ ] "Minimum effective dose" algorithm (3 workouts/week templates)
- [ ] Partner/family schedule coordination
- [ ] Quick workout library (20min, 30min, 45min options)

**Technical Challenge**:
- Calendar permissions and privacy
- Intelligent conflict detection
- Maintaining periodization with irregular schedule

---

## Database Schema Extensions

### New Tables Required

```sql
-- AI Profile Storage
CREATE TABLE athlete_ai_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    athlete_id INT REFERENCES athletes(id),
    core_memory JSONB NOT NULL,
    last_updated TIMESTAMP DEFAULT NOW(),
    version INT DEFAULT 1
);

-- Workout Embeddings for RAG
CREATE TABLE activity_embeddings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    activity_id BIGINT REFERENCES activities(id),
    summary TEXT NOT NULL,
    embedding VECTOR(1536), -- OpenAI ada-002 or similar
    created_at TIMESTAMP DEFAULT NOW()
);

-- Enable pgvector
CREATE EXTENSION IF NOT EXISTS vector;

-- Training Journal Entries
CREATE TABLE training_journal (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    athlete_id INT REFERENCES athletes(id),
    date DATE NOT NULL,
    entry_type VARCHAR(20), -- 'daily', 'weekly', 'monthly'
    narrative TEXT NOT NULL,
    generated_at TIMESTAMP DEFAULT NOW()
);

-- Training Plans
CREATE TABLE training_plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    athlete_id INT REFERENCES athletes(id),
    goal_race_date DATE,
    goal_race_distance VARCHAR(50),
    plan_data JSONB NOT NULL, -- Structured workout definitions
    created_at TIMESTAMP DEFAULT NOW(),
    active BOOLEAN DEFAULT TRUE
);

-- Streaks
CREATE TABLE athlete_streaks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    athlete_id INT REFERENCES athletes(id),
    streak_type VARCHAR(50), -- 'activity', 'sleep', 'nutrition'
    current_count INT DEFAULT 0,
    start_date DATE NOT NULL,
    last_activity_date DATE,
    freeze_available INT DEFAULT 1
);

-- Chat History
CREATE TABLE chat_conversations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    athlete_id INT REFERENCES athletes(id),
    message TEXT NOT NULL,
    role VARCHAR(20), -- 'user', 'assistant'
    timestamp TIMESTAMP DEFAULT NOW(),
    context_used JSONB -- What data was retrieved for this response
);

-- Injury Tracking
CREATE TABLE injury_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    athlete_id INT REFERENCES athletes(id),
    injury_type VARCHAR(100),
    start_date DATE,
    end_date DATE,
    severity VARCHAR(20), -- 'mild', 'moderate', 'severe'
    notes TEXT,
    pt_exercises JSONB
);
```

---

## API Architecture

### New Services Required

```
runaway-coach-api/
├── chat/
│   ├── POST /chat                    # Main conversational endpoint
│   ├── GET /chat/history             # Retrieve past conversations
│   └── POST /chat/memory/update      # Update core memory
├── analysis/
│   ├── POST /analyze/activity        # Post-run analysis
│   ├── GET /analyze/trends           # Pattern detection
│   └── POST /analyze/forecast        # Performance predictions
├── planning/
│   ├── POST /plans/generate          # Create training plan
│   ├── PUT /plans/{id}/adjust        # Conversational adjustment
│   └── GET /plans/{id}/today         # Today's workout
├── journal/
│   ├── POST /journal/generate        # Auto-generate entry
│   └── GET /journal/{athlete_id}     # Retrieve journal
└── embeddings/
    ├── POST /embeddings/activities   # Batch embed activities
    └── POST /embeddings/search       # Semantic search
```

---

## Claude Prompt Library

### Core System Prompt Template

```
You are an elite running coach with 20 years of experience. You have deep knowledge of:
- Exercise physiology and training periodization
- Injury prevention and rehabilitation
- Sports psychology and motivation
- Individual athlete differences (age, experience, goals)

ATHLETE PROFILE:
{core_memory}

RECENT TRAINING (14 days):
{recent_activities_summary}

TODAY'S CONTEXT:
- Date: {current_date}
- Training phase: {current_phase}
- Weather: {weather_data}

COACHING STYLE: {personality_mode}
- If tough_love: Be direct, honest, challenging
- If supportive: Encouraging, positive, empathetic
- If analytical: Data-driven, detailed, technical
- If playful: Fun, energetic, use emojis sparingly

YOUR TASK:
{specific_task}

RESPONSE FORMAT:
- Keep responses concise (2-4 sentences for quick questions, longer for complex analysis)
- Always explain WHY, not just WHAT
- Reference specific data points to build trust
- End with one actionable insight

CONSTRAINTS:
- Never recommend training that could cause injury
- Defer to medical professionals for injury questions
- Acknowledge uncertainty when data is limited
- Respect the athlete's autonomy (suggest, don't command)
```

### Q&A Prompt Example

```
QUERY: "{user_question}"

AVAILABLE TOOLS:
- search_activities(start_date, end_date, activity_type)
- get_activity_details(activity_id)
- calculate_statistics(metric, timeframe)
- compare_periods(period1, period2, metric)

INSTRUCTIONS:
1. Determine what data is needed to answer the question
2. Use tools to retrieve that data
3. Synthesize the data into a clear, conversational answer
4. Provide context (e.g., "This is typical for your fitness level" or "This is unusual")
5. Offer one related insight the athlete might not have considered

EXAMPLE:
Query: "When did I last run over 10 miles?"
Tools: search_activities(activity_type="Run", min_distance=10)
Response: "Your last 10+ mile run was November 18th—a 12-miler at 8:45 pace. That was 12 days ago, which is longer than your typical long run interval (you usually run long every 7-10 days). With your half marathon in 6 weeks, I'd recommend getting a 10+ miler in this weekend to maintain endurance."
```

---

## Progress Tracking

### Completed Features ✅
- [x] Strava OAuth integration
- [x] Activity sync (full and beta)
- [x] Background job processing
- [x] Athlete, activity, goal, commitment data models
- [x] iOS app with widget
- [x] Real-time data sync via Supabase
- [x] **AI Training Chat (Feature 1.1)** - 2025-12-01
  - pgvector semantic search over 712 activities
  - Claude 3 Opus conversational AI with RAG
  - OpenAI embeddings for activity summaries
  - Production deployment on Cloud Run
  - Integrated with existing iOS chat interface

### In Progress ⏳
- [ ] None currently

### Up Next 🎯
**Phase 1 Priorities** (Next 2 months):
1. ~~AI Training Chat (Feature 1.1)~~ ✅ COMPLETED
2. Persistent Athlete Profile (Feature 1.2) - Foundation
3. Automated Training Journal (Feature 1.3) - Unique feature

---

## Key Decisions Log

### 2025-12-01: AI Training Chat Implementation
- **Completed Feature 1.1** - First production AI feature deployed
  - Successfully embedded 712 historical activities
  - Implemented RAG with temporal query detection
  - Deployed to Cloud Run with public endpoint
  - Integrated with existing iOS chat interface

- **Temporal Query Handling**: Custom detection + date sorting
  - Problem: "When did I last run X" queries returned semantically similar but not most recent
  - Solution: Detect temporal keywords, fetch more results, sort by activity_date
  - Result: Accurate "last" queries (e.g., correctly found Nov 18 10+ mile run)

- **iOS Simulator Networking**: Used host IP instead of localhost
  - Problem: iOS simulator can't reach localhost (refers to simulator itself)
  - Solution: Configure server to listen on 0.0.0.0, use host Mac IP (192.168.x.x)
  - Added App Transport Security exception for development IP

- **Authentication Strategy**: Public endpoint for chat
  - Decision: Skip auth middleware for /api/chat endpoint
  - Rationale: Cloud Run handles IAM, iOS app needs direct access
  - Future: Add API key or athlete-specific auth tokens

### 2025-11-30: Architecture Decisions
- **Memory System**: MemGPT-style with 4-tier architecture
  - Rationale: Balance context efficiency with historical depth
  - Alternative considered: Zep's Temporal Knowledge Graph (more complex)

- **Embedding Model**: OpenAI ada-002 (1536 dimensions)
  - Rationale: Good balance of quality and cost
  - Store in Supabase pgvector for simplicity

- **ML vs LLM Split**: ML for time-series, Claude for language
  - Rationale: Use best tool for each job
  - ML handles numerical prediction, Claude handles explanation

- **Forecasting**: Lag-Llama open-source model
  - Rationale: Free, probabilistic outputs, works with irregular time series
  - Alternative: TimeGPT-1 (commercial, easier but costs)

---

## Success Metrics

### Engagement Metrics
- **7-day retention**: Target >60% (industry avg ~40%)
- **30-day retention**: Target >40% (industry avg ~25%)
- **Daily active usage**: Target >30% of weekly actives
- **Chat engagement**: Target >3 questions/week per active user

### Feature-Specific Metrics
- **Q&A accuracy**: >90% user satisfaction with answers
- **Journal value**: >70% of users read generated entries
- **Plan adherence**: >60% completion rate (vs ~40% industry standard)
- **Streak participation**: >50% of users maintain at least one streak

### Business Metrics
- **User growth**: Target 10,000 users in year 1
- **Conversion to paid**: Target 15% (freemium model)
- **Churn rate**: Target <5% monthly
- **NPS (Net Promoter Score)**: Target >50

---

## Risks & Mitigations

### Technical Risks
| Risk | Impact | Mitigation |
|------|--------|------------|
| Claude API costs | High | Implement caching, summarization, rate limiting |
| Context window limits | Medium | Hierarchical summarization pipeline |
| Supabase scaling | Medium | Monitor usage, plan for migration if needed |
| ML model inference latency | Low | Background processing, cache predictions |

### Product Risks
| Risk | Impact | Mitigation |
|------|--------|------------|
| AI hallucination | High | Structured outputs, fact-checking, disclaimers |
| User privacy concerns | High | Transparent data usage, local processing where possible |
| Strava API changes | Medium | Multi-platform support, own data storage |
| User overwhelm | Medium | Progressive disclosure, simple defaults |

### Market Risks
| Risk | Impact | Mitigation |
|------|--------|------------|
| Incumbent copies features | Medium | Speed of execution, depth of implementation |
| User distrust of AI | Low | Transparent AI, human-in-loop, build trust gradually |
| Coaching liability | High | Clear disclaimers, medical professional referrals |

---

## Resources & References

### Key Research Papers
- **PH-LLM (Google, 2025)**: Personal Health Large Language Model - Nature Medicine
- **Lag-Llama (2024)**: Foundation model for time-series forecasting
- **MemGPT (UC Berkeley)**: LLM memory management architecture
- **Zep Graphiti**: Temporal knowledge graphs for LLM memory
- **TMLE for Training**: Causal inference in endurance sports

### Commercial Examples
- **WHOOP Coach**: GPT-4 powered coaching (benchmark)
- **Garmin Training Status**: Training load + recovery (benchmark)
- **Athletica.ai**: Adaptive training with calendar integration (benchmark)
- **TrainerRoad**: ML-based plan adaptation (benchmark)

### Technical Stack
- **Frontend**: SwiftUI (iOS), eventual web app
- **Backend**: Supabase (PostgreSQL + Realtime + Auth)
- **AI**: Claude 3.5 Sonnet via API
- **ML**: Lag-Llama (HuggingFace), custom models
- **Embeddings**: OpenAI ada-002 + pgvector
- **Hosting**: Cloud Run (existing), potential edge functions

---

## Next Steps (Immediate)

1. **Enable pgvector in Supabase** ⏳
   - Required for semantic search over workout history
   - Foundation for Q&A feature

2. **Design Core Memory Schema** ⏳
   - Define JSONB structure for athlete profiles
   - Plan migration path from existing athlete table

3. **Prototype Chat Interface** ⏳
   - Simple iOS chat view
   - Test Claude integration with structured prompts
   - Validate RAG retrieval quality

4. **Activity Summarization Pipeline** ⏳
   - Script to batch-summarize existing activities
   - Automated daily summarization service
   - Embedding generation and storage

5. **Set up Claude API** ⏳
   - API key management
   - Prompt library organization
   - Cost monitoring and rate limiting

---

**Last Updated**: 2025-11-30
**Document Owner**: Jack Rudelic
**Status**: Active Development - Phase 1 Planning
