# Adlerian Psychology Integration — Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add encouragement-first Adlerian psychology to Runaway's backend — runner identity profiles, post-workout feedback, and Adlerian-aware coaching prompts — with two minimal iOS hooks so data lands in the right place.

**Architecture:** Two new Supabase migrations create the `runner_identity_milestones` table and `goal_framing` column. Two new Deno edge functions (`identity-profile`, `feedback-workout`) write to `athlete_ai_profiles.core_memory` and `activity_insights`. Three existing functions get non-breaking Adlerian prompt injections. iOS gets a new `FeedbackWorkoutService` and a `goalFraming` field on `RunningGoal`.

**Tech Stack:** Deno + TypeScript (edge functions), Supabase PostgreSQL (migrations), Anthropic Claude API (`claude-haiku-4-5`), Swift/SwiftUI (iOS model + service).

**Edge function repo:** `/Users/jack.rudelic/projects/labs/runaway/runaway-edge/`
**iOS repo:** `/Users/jack.rudelic/projects/labs/runaway/Runaway iOS/`

---

## File Map

| Action | Path |
|---|---|
| Create | `runaway-edge/supabase/migrations/20260506000001_add_runner_identity_milestones.sql` |
| Create | `runaway-edge/supabase/migrations/20260506000002_add_goal_framing.sql` |
| Create | `runaway-edge/supabase/functions/identity-profile/index.ts` |
| Create | `runaway-edge/supabase/functions/feedback-workout/index.ts` |
| Modify | `runaway-edge/supabase/functions/chat/index.ts` |
| Modify | `runaway-edge/supabase/functions/goal-assessment/index.ts` |
| Modify | `runaway-edge/supabase/functions/generate-training-plan/index.ts` |
| Modify | `Runaway iOS/Runaway iOS/Models/GoalModels.swift` |
| Create | `Runaway iOS/Runaway iOS/Services/FeedbackWorkoutService.swift` |
| Modify | `Runaway iOS/Runaway iOS/Services/ActivityService.swift` |

---

### Task 1: Migration — `runner_identity_milestones` table

**Files:**
- Create: `runaway-edge/supabase/migrations/20260506000001_add_runner_identity_milestones.sql`

- [ ] **Step 1: Write the migration file**

```sql
-- Migration: add runner_identity_milestones table
CREATE TABLE runner_identity_milestones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  athlete_id bigint NOT NULL REFERENCES athletes(id) ON DELETE CASCADE,
  milestone_key text NOT NULL,
  label text NOT NULL,
  description text NOT NULL,
  earned boolean NOT NULL DEFAULT false,
  earned_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(athlete_id, milestone_key)
);

CREATE INDEX idx_milestones_athlete ON runner_identity_milestones(athlete_id);

ALTER TABLE runner_identity_milestones ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Athletes see own milestones" ON runner_identity_milestones
  FOR ALL USING (
    athlete_id = (SELECT id FROM athletes WHERE auth_user_id = auth.uid())
  );
```

- [ ] **Step 2: Apply migration to local Supabase**

```bash
cd /Users/jack.rudelic/projects/labs/runaway/runaway-edge
supabase db push
```

Expected: migration runs without error, table appears in local schema.

- [ ] **Step 3: Verify table exists**

```bash
supabase db dump --schema public | grep runner_identity_milestones
```

Expected: output includes the table name.

- [ ] **Step 4: Commit**

```bash
cd /Users/jack.rudelic/projects/labs/runaway/runaway-edge
git add supabase/migrations/20260506000001_add_runner_identity_milestones.sql
git commit -m "feat: add runner_identity_milestones table with RLS"
```

---

### Task 2: Migration — `goal_framing` column

**Files:**
- Create: `runaway-edge/supabase/migrations/20260506000002_add_goal_framing.sql`

- [ ] **Step 1: Write the migration file**

```sql
-- Migration: add goal_framing column to running_goals
ALTER TABLE running_goals ADD COLUMN goal_framing text;
```

- [ ] **Step 2: Apply migration**

```bash
cd /Users/jack.rudelic/projects/labs/runaway/runaway-edge
supabase db push
```

Expected: runs without error.

- [ ] **Step 3: Verify column exists**

```bash
supabase db dump --schema public | grep -A 5 "running_goals"
```

Expected: `goal_framing` appears in the column list.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260506000002_add_goal_framing.sql
git commit -m "feat: add goal_framing column to running_goals"
```

---

### Task 3: New edge function — `/identity-profile`

**Files:**
- Create: `runaway-edge/supabase/functions/identity-profile/index.ts`

This function receives `athlete_id`, `why_i_run`, `core_values`, and `mode`. It fetches the last 90 days of activities, calls Claude to pick a runner identity label (one of five), upserts `adlerian_profile` into `athlete_ai_profiles.core_memory`, seeds 6 milestone rows, and optionally writes `goal_framing` to the athlete's active goal.

**Note on `core_memory` merge:** `athlete_ai_profiles` has a JSONB column `core_memory`. Merge by fetching current value, spreading it, and adding the `adlerian_profile` key — never replace the whole object.

- [ ] **Step 1: Create the function**

```typescript
// runaway-edge/supabase/functions/identity-profile/index.ts
import { createClient } from 'jsr:@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

const ANTHROPIC_API_KEY = Deno.env.get('ANTHROPIC_API_KEY')

const IDENTITY_LABELS = [
  'Morning Runner',
  'Trail Explorer',
  'Consistent Builder',
  'Weekend Warrior',
  'Comeback Runner',
] as const

type IdentityLabel = typeof IDENTITY_LABELS[number]

const SEED_MILESTONES = [
  { key: 'first_run', label: 'First Step', description: 'Completed your first run with Runaway' },
  { key: 'streak_7', label: 'Seven-Day Streak', description: 'Ran 7 days in a row' },
  { key: 'distance_5k', label: '5K Club', description: 'Completed a run of at least 5K' },
  { key: 'distance_half', label: 'Half Marathon Club', description: 'Completed a half marathon or longer' },
  { key: 'consistency_4weeks', label: 'Consistent Builder', description: 'Ran at least once a week for 4 consecutive weeks' },
  { key: 'comeback', label: 'Comeback Runner', description: 'Returned to running after a gap of 2+ weeks' },
]

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: corsHeaders })

  try {
    const { athlete_id, why_i_run, core_values, mode } = await req.json()

    if (!athlete_id || !why_i_run || !Array.isArray(core_values)) {
      return new Response(
        JSON.stringify({ error: 'athlete_id, why_i_run, and core_values are required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Fetch last 90 days of activities
    const cutoff = new Date()
    cutoff.setDate(cutoff.getDate() - 90)

    const { data: activities } = await supabase
      .from('activities')
      .select('distance, elapsed_time, activity_date, elevation_gain, sport_type')
      .eq('athlete_id', athlete_id)
      .gte('activity_date', cutoff.toISOString().split('T')[0])
      .order('activity_date', { ascending: false })
      .limit(100)

    // Build activity summary for Claude
    const acts = activities ?? []
    const totalRuns = acts.length
    const totalDistanceM = acts.reduce((s: number, a: any) => s + (a.distance ?? 0), 0)
    const totalDistanceKm = (totalDistanceM / 1000).toFixed(1)

    // Detect weekend-heavy pattern
    const weekendRuns = acts.filter((a: any) => {
      const d = new Date(a.activity_date).getDay()
      return d === 0 || d === 6
    }).length

    // Detect AM pattern (approximate from activity names / timestamps not always available)
    // Detect trail pattern from elevation
    const avgElevation = acts.length > 0
      ? acts.reduce((s: number, a: any) => s + (a.elevation_gain ?? 0), 0) / acts.length
      : 0

    // Detect comeback (gap of 2+ weeks in the last 90 days)
    let hasComeback = false
    for (let i = 1; i < acts.length; i++) {
      const dayGap = (new Date(acts[i - 1].activity_date).getTime() - new Date(acts[i].activity_date).getTime()) / 86400000
      if (dayGap >= 14) { hasComeback = true; break }
    }

    // Fetch current core_memory
    const { data: aiProfile } = await supabase
      .from('athlete_ai_profiles')
      .select('core_memory')
      .eq('athlete_id', athlete_id)
      .single()

    const existingMemory = (aiProfile?.core_memory as Record<string, unknown>) ?? {}

    // Call Claude
    const prompt = `You are categorizing a runner's identity. Based on the data below, pick EXACTLY ONE identity label from this list:
- Morning Runner (runs frequently, often early)
- Trail Explorer (high average elevation gain, varied terrain)
- Consistent Builder (steady weekly cadence, no long gaps)
- Weekend Warrior (most runs cluster on Saturday/Sunday)
- Comeback Runner (returned after a 2+ week gap recently)

Runner data:
- Total runs last 90 days: ${totalRuns}
- Total distance: ${totalDistanceKm} km
- Weekend runs: ${weekendRuns} of ${totalRuns}
- Average elevation gain per run: ${avgElevation.toFixed(0)}m
- Has comeback pattern: ${hasComeback}
- Why they run: "${why_i_run}"
- Core values: ${core_values.join(', ')}

Default to "Consistent Builder" if data is insufficient.

Respond with ONLY valid JSON, no markdown:
{
  "runner_identity": "<one of the five labels>",
  "identity_summary": "<one sentence, second person, under 20 words, never mention pace/goals/PRs>"
}`

    const anthropicRes = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': ANTHROPIC_API_KEY ?? '',
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: 'claude-haiku-4-5',
        max_tokens: 200,
        messages: [{ role: 'user', content: prompt }],
      }),
    })

    const anthropicData = await anthropicRes.json()
    const rawText = (anthropicData.content?.[0]?.text ?? '{}')
      .replace(/^```(?:json)?\s*/i, '').replace(/\s*```\s*$/, '').trim()

    let runner_identity: IdentityLabel = 'Consistent Builder'
    let identity_summary = 'You run to stay connected to yourself and keep moving forward.'

    try {
      const parsed = JSON.parse(rawText)
      if (IDENTITY_LABELS.includes(parsed.runner_identity)) {
        runner_identity = parsed.runner_identity
      }
      if (parsed.identity_summary) {
        identity_summary = parsed.identity_summary
      }
    } catch { /* use defaults */ }

    // Upsert adlerian_profile into core_memory (merge, don't replace)
    const adlerianProfile = {
      runner_identity,
      identity_summary,
      why_i_run,
      core_values,
      updated_at: new Date().toISOString(),
    }

    const mergedMemory = { ...existingMemory, adlerian_profile: adlerianProfile }

    await supabase
      .from('athlete_ai_profiles')
      .upsert({ athlete_id, core_memory: mergedMemory }, { onConflict: 'athlete_id' })

    // Seed 6 milestone rows (ON CONFLICT DO NOTHING)
    const milestoneRows = SEED_MILESTONES.map((m) => ({
      athlete_id,
      milestone_key: m.key,
      label: m.label,
      description: m.description,
    }))

    await supabase
      .from('runner_identity_milestones')
      .upsert(milestoneRows, { onConflict: 'athlete_id,milestone_key', ignoreDuplicates: true })

    // Optionally update goal_framing on active goal
    const { data: activeGoal } = await supabase
      .from('running_goals')
      .select('id, title, goal_type')
      .eq('athlete_id', athlete_id)
      .eq('is_active', true)
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle()

    if (activeGoal) {
      const framingPrompt = `Write one sentence (under 20 words) framing this running goal in identity terms for a "${runner_identity}". Never mention numbers or pace. Second person.

Goal: ${activeGoal.title} (type: ${activeGoal.goal_type})
Runner identity: ${runner_identity}

Respond with ONLY the sentence, no JSON, no quotes.`

      const framingRes = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': ANTHROPIC_API_KEY ?? '',
          'anthropic-version': '2023-06-01',
        },
        body: JSON.stringify({
          model: 'claude-haiku-4-5',
          max_tokens: 80,
          messages: [{ role: 'user', content: framingPrompt }],
        }),
      })

      const framingData = await framingRes.json()
      const goalFraming = framingData.content?.[0]?.text?.trim() ?? null

      if (goalFraming) {
        await supabase
          .from('running_goals')
          .update({ goal_framing: goalFraming })
          .eq('id', activeGoal.id)
      }
    }

    return new Response(
      JSON.stringify({ runner_identity, identity_summary, why_i_run, core_values }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (err) {
    console.error('identity-profile error:', err)
    return new Response(
      JSON.stringify({ error: 'Internal error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
```

- [ ] **Step 2: Deploy function locally and smoke-test**

```bash
cd /Users/jack.rudelic/projects/labs/runaway/runaway-edge
supabase functions serve identity-profile --env-file .env.local
```

In a second terminal:
```bash
curl -X POST http://localhost:54321/functions/v1/identity-profile \
  -H "Content-Type: application/json" \
  -d '{"athlete_id": 1, "why_i_run": "I run to clear my head", "core_values": ["consistency", "mental health"], "mode": "onboarding"}'
```

Expected: `{"runner_identity": "<one of five>", "identity_summary": "...", "why_i_run": "I run to clear my head", "core_values": ["consistency", "mental health"]}`

- [ ] **Step 3: Deploy to production**

```bash
supabase functions deploy identity-profile
```

Expected: `Deployed identity-profile`

- [ ] **Step 4: Commit**

```bash
git add supabase/functions/identity-profile/index.ts
git commit -m "feat: add identity-profile edge function"
```

---

### Task 4: New edge function — `/feedback-workout`

**Files:**
- Create: `runaway-edge/supabase/functions/feedback-workout/index.ts`

This function receives `athlete_id` and `activity_id`. It fetches the activity, reads `adlerian_profile` from `core_memory`, derives an effort label locally, calls Claude for 2–3 sentence encouragement feedback, and writes the result to `activity_insights`.

**Note on `activity_insights` schema:** The table uses `insight_data` (JSONB) — not separate `content`/`metadata` columns. Store `{ content, effort_label, athlete_id }` inside `insight_data`.

- [ ] **Step 1: Create the function**

```typescript
// runaway-edge/supabase/functions/feedback-workout/index.ts
import { createClient } from 'jsr:@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

const ANTHROPIC_API_KEY = Deno.env.get('ANTHROPIC_API_KEY')

type EffortLabel = 'Easy' | 'Moderate' | 'Tempo' | 'Long'

function deriveEffortLabel(distanceM: number, elapsedSec: number): EffortLabel {
  if (elapsedSec <= 0 || distanceM <= 0) return 'Easy'
  const durationMin = elapsedSec / 60
  const paceSecPerKm = elapsedSec / (distanceM / 1000)
  const paceMinPerKm = paceSecPerKm / 60

  if (durationMin >= 70) return 'Long'
  if (paceMinPerKm < 6.0 && durationMin < 40) return 'Tempo'
  if (paceMinPerKm <= 7.0) return 'Moderate'
  return 'Easy'
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: corsHeaders })

  try {
    const { athlete_id, activity_id } = await req.json()

    if (!athlete_id || !activity_id) {
      return new Response(
        JSON.stringify({ error: 'athlete_id and activity_id are required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Fetch activity
    const { data: activity, error: actErr } = await supabase
      .from('activities')
      .select('id, distance, elapsed_time, average_heartrate, sport_type, name')
      .eq('id', activity_id)
      .eq('athlete_id', athlete_id)
      .single()

    if (actErr || !activity) {
      return new Response(
        JSON.stringify({ error: 'Activity not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Fetch adlerian_profile from core_memory
    const { data: aiProfile } = await supabase
      .from('athlete_ai_profiles')
      .select('core_memory')
      .eq('athlete_id', athlete_id)
      .maybeSingle()

    const coreMemory = (aiProfile?.core_memory as Record<string, any>) ?? {}
    const adlerianProfile = coreMemory.adlerian_profile ?? {}
    const runnerIdentity: string = adlerianProfile.runner_identity ?? 'runner'
    const whyIRun: string = adlerianProfile.why_i_run ?? ''

    const distanceM = activity.distance ?? 0
    const elapsedSec = activity.elapsed_time ?? 0
    const distanceKm = (distanceM / 1000).toFixed(2)
    const durationMin = Math.round(elapsedSec / 60)

    const effortLabel: EffortLabel = deriveEffortLabel(distanceM, elapsedSec)

    // Call Claude for feedback
    const prompt = `You are an Adlerian running coach. Write 2-3 sentences of post-workout encouragement.

Rules:
- Open by acknowledging they showed up ("You got out there", "Today you ran", "You laced up")
- Name their identity naturally: "${runnerIdentity}"
- Never compare to a goal, PR, or previous run
- Never use "but", "however", or pivot language
- 2-3 sentences maximum
- Second person

Athlete context:
- Runner identity: ${runnerIdentity}
- Why they run: ${whyIRun || '(not set)'}
- Today's workout: ${distanceKm}km in ${durationMin}min (${effortLabel})
- Sport: ${activity.sport_type ?? 'Run'}

Respond with ONLY the feedback text. No JSON, no quotes, no preamble.`

    const anthropicRes = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': ANTHROPIC_API_KEY ?? '',
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: 'claude-haiku-4-5',
        max_tokens: 200,
        messages: [{ role: 'user', content: prompt }],
      }),
    })

    const anthropicData = await anthropicRes.json()
    const feedback: string = anthropicData.content?.[0]?.text?.trim()
      ?? `You showed up today — that's what a ${runnerIdentity} does.`

    // Store in activity_insights
    await supabase
      .from('activity_insights')
      .insert({
        activity_id,
        insight_type: 'adlerian_feedback',
        insight_data: {
          content: feedback,
          effort_label: effortLabel,
          athlete_id,
        },
        generated_by: 'feedback-workout',
      })

    return new Response(
      JSON.stringify({ feedback, effort_label: effortLabel }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (err) {
    console.error('feedback-workout error:', err)
    return new Response(
      JSON.stringify({ error: 'Internal error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
```

- [ ] **Step 2: Smoke-test locally**

```bash
supabase functions serve feedback-workout --env-file .env.local
```

```bash
curl -X POST http://localhost:54321/functions/v1/feedback-workout \
  -H "Content-Type: application/json" \
  -d '{"athlete_id": 1, "activity_id": <real_activity_id>}'
```

Expected: `{"feedback": "You got out there...", "effort_label": "Easy"}`

Verify in local DB:
```sql
SELECT insight_type, insight_data FROM activity_insights ORDER BY created_at DESC LIMIT 1;
```

Expected: row with `insight_type = 'adlerian_feedback'` and `insight_data.content` set.

- [ ] **Step 3: Deploy to production**

```bash
supabase functions deploy feedback-workout
```

- [ ] **Step 4: Commit**

```bash
git add supabase/functions/feedback-workout/index.ts
git commit -m "feat: add feedback-workout edge function"
```

---

### Task 5: Update `chat` — inject Adlerian context

**Files:**
- Modify: `runaway-edge/supabase/functions/chat/index.ts`

The `chat` function already fetches activities and builds a context string. After fetching the athlete, add a fetch for `adlerian_profile` from `athlete_ai_profiles.core_memory`. Inject it into the system prompt when present. If absent, behavior is unchanged.

- [ ] **Step 1: Add the Adlerian context fetch after the existing athlete fetch (around line 65)**

After the athlete fetch block (`if (athleteError) { ... }`), add:

```typescript
    // Fetch Adlerian profile from core_memory
    const { data: aiProfile } = await supabaseAdmin
      .from('athlete_ai_profiles')
      .select('core_memory')
      .eq('athlete_id', athlete_id)
      .maybeSingle()

    const coreMemory = (aiProfile?.core_memory as Record<string, any>) ?? {}
    const adlerianProfile = coreMemory.adlerian_profile ?? null
```

- [ ] **Step 2: Build the Adlerian system prompt block**

After the `const context = contextParts.join('\n')` line (around line 100), add:

```typescript
    const adlerianBlock = adlerianProfile
      ? `\n\n[COACHING VOICE]\nThis athlete's identity: ${adlerianProfile.runner_identity}. Why they run: ${adlerianProfile.why_i_run}.\nLead with encouragement. Name their identity when relevant.\nNever open with performance critique or goal comparison.`
      : ''
```

- [ ] **Step 3: Inject `adlerianBlock` into the system prompt string**

In the `body: JSON.stringify({ ... system: \`...\`` block (around line 113), change:

```typescript
        system: `You are an expert running coach. You provide personalized training advice based on the athlete's activity history. Be supportive, concise, and data-driven. Use the context provided to give specific, actionable advice.

Context about the athlete:
${context}`,
```

To:

```typescript
        system: `You are an expert running coach. You provide personalized training advice based on the athlete's activity history. Be supportive, concise, and data-driven. Use the context provided to give specific, actionable advice.

Context about the athlete:
${context}${adlerianBlock}`,
```

- [ ] **Step 4: Deploy and smoke-test**

```bash
supabase functions deploy chat
```

Test with an athlete who has an `adlerian_profile` set (from Task 3):
```bash
curl -X POST https://<project-ref>.supabase.co/functions/v1/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <anon-key>" \
  -d '{"athlete_id": 1, "message": "How is my training going?"}'
```

Expected: response arrives (no 500 error). If athlete has no `adlerian_profile`, response still arrives normally.

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/chat/index.ts
git commit -m "feat: inject Adlerian identity context into chat prompt"
```

---

### Task 6: Update `goal-assessment` — inject `goal_framing`

**Files:**
- Modify: `runaway-edge/supabase/functions/goal-assessment/index.ts`

The `goal-assessment` function currently queries the `goals` table (line 33). The production table is `running_goals`. It also doesn't read `goal_framing`. This task: fix the table name and inject `goal_framing` into the prompt when present.

- [ ] **Step 1: Fix the table query and add `goal_framing` to the select**

Current (line 33):
```typescript
    const { data: goal } = await supabase
      .from('goals')
      .select('*')
      .eq('id', goal_id)
      .eq('athlete_id', athlete.id)
      .single()
```

Replace with:
```typescript
    const { data: goal } = await supabase
      .from('running_goals')
      .select('*')
      .eq('id', goal_id)
      .eq('athlete_id', athlete.id)
      .single()
```

- [ ] **Step 2: Add the Adlerian block to the prompt string**

Find the `const prompt = \`` line (around line 81) and the `Rules:` section at the bottom. Before the closing backtick of the prompt, add:

```typescript
${goal?.goal_framing ? `\nThis athlete's goal framing: "${goal.goal_framing}".\nFrame assessment in identity terms, not deficit terms.\n` : ''}
```

The full prompt closing should look like:
```typescript
- Do not wrap in markdown or add any text outside the JSON.${goal?.goal_framing ? `\n\nThis athlete's goal framing: "${goal.goal_framing}".\nFrame assessment in identity terms, not deficit terms.` : ''}`
```

- [ ] **Step 3: Deploy**

```bash
supabase functions deploy goal-assessment
```

- [ ] **Step 4: Commit**

```bash
git add supabase/functions/goal-assessment/index.ts
git commit -m "feat: fix goal-assessment table name + inject goal_framing into prompt"
```

---

### Task 7: Update `generate-training-plan` — inject runner identity

**Files:**
- Modify: `runaway-edge/supabase/functions/generate-training-plan/index.ts`

After the athlete fetch (around line 85), add a fetch for `adlerian_profile`. Inject it into the existing system prompt when present.

- [ ] **Step 1: Add the Adlerian fetch after the athlete fetch block**

After:
```typescript
    if (athleteError) {
      console.error('Error fetching athlete:', athleteError)
    }
```

Add:
```typescript
    // Fetch Adlerian profile
    const { data: aiProfileData } = await supabaseAdmin
      .from('athlete_ai_profiles')
      .select('core_memory')
      .eq('athlete_id', athlete_id)
      .maybeSingle()

    const planCoreMemory = (aiProfileData?.core_memory as Record<string, any>) ?? {}
    const planAdlerian = planCoreMemory.adlerian_profile ?? null
```

- [ ] **Step 2: Build and inject the Adlerian block into the system prompt**

Find the `system:` string in the `body: JSON.stringify(...)` call (around line 129). It currently ends with `7. GOAL ALIGNMENT: Prioritize workout types that match the athlete's goal`. After that closing backtick on the `system:` value, add the Adlerian block:

```typescript
        system: `You are an expert running coach and exercise physiologist. Your task is to create a comprehensive weekly training plan for a runner.
...
7. GOAL ALIGNMENT: Prioritize workout types that match the athlete's goal${planAdlerian ? `\n\n[RUNNER IDENTITY]\nRunner identity: ${planAdlerian.runner_identity}. Core values: ${planAdlerian.core_values?.join(', ') ?? ''}.\nPlan description and weekly summaries should reinforce identity, not just list mileage.` : ''}`,
```

- [ ] **Step 3: Deploy**

```bash
supabase functions deploy generate-training-plan
```

- [ ] **Step 4: Commit**

```bash
git add supabase/functions/generate-training-plan/index.ts
git commit -m "feat: inject runner identity into training plan generation prompt"
```

---

### Task 8: iOS — add `goalFraming` to `RunningGoal`

**Files:**
- Modify: `Runaway iOS/Runaway iOS/Models/GoalModels.swift`

`RunningGoal` has a custom `init(from decoder:)` and `encode(to encoder:)`. Add `goalFraming: String?` as a stored property and thread it through both.

- [ ] **Step 1: Add stored property after `completedDate`**

In `GoalModels.swift`, line 47 (after `let completedDate: Date?`), add:

```swift
    let goalFraming: String?
```

- [ ] **Step 2: Add CodingKey**

In the `enum CodingKeys` block (around line 82), after `case completedDate = "completed_at"`, add:

```swift
        case goalFraming = "goal_framing"
```

- [ ] **Step 3: Update the client-side `init` (around line 49)**

After `self.completedDate = nil`, add:

```swift
        self.goalFraming = nil
```

- [ ] **Step 4: Update the database `init` signature and body (around line 65)**

Change signature from:
```swift
    init(id: Int?, athleteId: Int?, type: GoalType, targetValue: Double, deadline: Date,
         createdDate: Date, updatedDate: Date?, title: String, isActive: Bool,
         isCompleted: Bool, currentProgress: Double, completedDate: Date?) {
```
To:
```swift
    init(id: Int?, athleteId: Int?, type: GoalType, targetValue: Double, deadline: Date,
         createdDate: Date, updatedDate: Date?, title: String, isActive: Bool,
         isCompleted: Bool, currentProgress: Double, completedDate: Date?,
         goalFraming: String? = nil) {
```

Add at the end of the body (after `self.completedDate = completedDate`):
```swift
        self.goalFraming = goalFraming
```

- [ ] **Step 5: Update `encode(to encoder:)`**

After `try container.encodeIfPresent(completedDate, forKey: .completedDate)`, add:

```swift
        try container.encodeIfPresent(goalFraming, forKey: .goalFraming)
```

- [ ] **Step 6: Update `init(from decoder:)`**

After `completedDate = try container.decodeIfPresent(Date.self, forKey: .completedDate)`, add:

```swift
        goalFraming = try container.decodeIfPresent(String.self, forKey: .goalFraming)
```

- [ ] **Step 7: Build to confirm no compile errors**

```bash
cd "/Users/jack.rudelic/projects/labs/runaway/Runaway iOS"
xcodebuild -project "Runaway iOS.xcodeproj" -scheme "Runaway iOS" \
  -destination "platform=iOS Simulator,name=iPhone 15" build 2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 8: Commit**

```bash
git add "Runaway iOS/Models/GoalModels.swift"
git commit -m "feat: add goalFraming field to RunningGoal model"
```

---

### Task 9: iOS — `FeedbackWorkoutService`

**Files:**
- Create: `Runaway iOS/Runaway iOS/Services/FeedbackWorkoutService.swift`

Thin service that calls the `/feedback-workout` edge function and upserts the result into `activity_insights` via the Supabase Swift SDK. Errors are intentionally swallowed — a missing insight is not user-facing.

- [ ] **Step 1: Create the file**

```swift
// FeedbackWorkoutService.swift
// Runaway iOS

import Foundation
import Supabase

struct FeedbackWorkoutService {
    private struct Request: Encodable {
        let athlete_id: Int
        let activity_id: Int
    }

    private struct Response: Decodable {
        let feedback: String
        let effort_label: String
    }

    static func generateFeedback(athleteId: Int, activityId: Int) async throws {
        let response: Response = try await supabase.functions.invoke(
            "feedback-workout",
            options: .init(body: Request(athlete_id: athleteId, activity_id: activityId))
        )
        // Result is already stored server-side in activity_insights by the edge function.
        // Log in debug so we can verify end-to-end during development.
        #if DEBUG
        print("✅ FeedbackWorkoutService: \(response.effort_label) — \(response.feedback)")
        #endif
    }
}
```

- [ ] **Step 2: Build to confirm it compiles**

```bash
cd "/Users/jack.rudelic/projects/labs/runaway/Runaway iOS"
xcodebuild -project "Runaway iOS.xcodeproj" -scheme "Runaway iOS" \
  -destination "platform=iOS Simulator,name=iPhone 15" build 2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add "Runaway iOS/Services/FeedbackWorkoutService.swift"
git commit -m "feat: add FeedbackWorkoutService for post-workout Adlerian feedback"
```

---

### Task 10: iOS — fire feedback call after activity sync

**Files:**
- Modify: `Runaway iOS/Runaway iOS/Services/ActivityService.swift`

Find where new activities are saved after a sync (the method that inserts or upserts activity rows). After a successful save, fire `FeedbackWorkoutService.generateFeedback` in a background `Task`. The call must be fire-and-forget — `try?`, no `await` blocking the caller.

- [ ] **Step 1: Find the sync save site**

```bash
grep -n "upsert\|insert" "Runaway iOS/Runaway iOS/Services/ActivityService.swift" | head -20
```

Look for the method that saves a single new activity (not batch). It will have a return of the saved `Activity` or similar.

- [ ] **Step 2: Add fire-and-forget call after the successful save**

After the line where the upserted/inserted activity is confirmed (look for `.execute().value` or similar where the activity row is returned), add:

```swift
Task {
    guard let athleteId = activity.athleteId else { return }
    try? await FeedbackWorkoutService.generateFeedback(
        athleteId: athleteId,
        activityId: activity.id
    )
}
```

Where `activity` is the `Activity` struct returned from the insert/upsert. Use the correct variable name from the surrounding code.

- [ ] **Step 3: Build**

```bash
cd "/Users/jack.rudelic/projects/labs/runaway/Runaway iOS"
xcodebuild -project "Runaway iOS.xcodeproj" -scheme "Runaway iOS" \
  -destination "platform=iOS Simulator,name=iPhone 15" build 2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add "Runaway iOS/Services/ActivityService.swift"
git commit -m "feat: fire Adlerian feedback call after activity sync"
```

---

## End-to-End Verification

After all tasks are committed and deployed:

1. **Confirm migrations in production:**
   ```bash
   cd /Users/jack.rudelic/projects/labs/runaway/runaway-edge
   supabase db push
   ```

2. **Call `/identity-profile` for a real athlete and confirm `core_memory` updated:**
   ```bash
   curl -X POST https://<ref>.supabase.co/functions/v1/identity-profile \
     -H "Content-Type: application/json" \
     -d '{"athlete_id": <id>, "why_i_run": "I run to clear my head", "core_values": ["consistency"], "mode": "onboarding"}'
   ```
   Then in Supabase dashboard: `SELECT core_memory FROM athlete_ai_profiles WHERE athlete_id = <id>` — confirm `adlerian_profile` key is present.

3. **Call `/feedback-workout` for a real activity and confirm `activity_insights` row:**
   ```bash
   curl -X POST https://<ref>.supabase.co/functions/v1/feedback-workout \
     -H "Content-Type: application/json" \
     -d '{"athlete_id": <id>, "activity_id": <id>}'
   ```
   Then: `SELECT insight_type, insight_data FROM activity_insights ORDER BY created_at DESC LIMIT 3;`

4. **iOS build clean:**
   ```bash
   cd "/Users/jack.rudelic/projects/labs/runaway/Runaway iOS"
   xcodebuild -project "Runaway iOS.xcodeproj" -scheme "Runaway iOS" \
     -destination "platform=iOS Simulator,name=iPhone 15" build 2>&1 | tail -5
   ```
   Expected: `** BUILD SUCCEEDED **`
