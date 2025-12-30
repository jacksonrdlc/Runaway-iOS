-- Migration: Add Weekly Training Plans Table
-- Description: Store AI-generated weekly training plans
-- Run this in your Supabase SQL Editor

-- Create weekly_training_plans table
CREATE TABLE IF NOT EXISTS weekly_training_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    athlete_id BIGINT NOT NULL REFERENCES athletes(id) ON DELETE CASCADE,
    week_start_date DATE NOT NULL,  -- Sunday
    week_end_date DATE NOT NULL,    -- Saturday
    workouts JSONB NOT NULL DEFAULT '[]',
    week_number INT,
    total_mileage DECIMAL(5,2),
    focus_area TEXT,
    notes TEXT,
    goal_id INT REFERENCES running_goals(id) ON DELETE SET NULL,
    generated_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Ensure one plan per athlete per week
    UNIQUE(athlete_id, week_start_date)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_training_plans_athlete ON weekly_training_plans(athlete_id);
CREATE INDEX IF NOT EXISTS idx_training_plans_week ON weekly_training_plans(week_start_date DESC);
CREATE INDEX IF NOT EXISTS idx_training_plans_athlete_week ON weekly_training_plans(athlete_id, week_start_date DESC);

-- Enable RLS
ALTER TABLE weekly_training_plans ENABLE ROW LEVEL SECURITY;

-- Policy: Users can read their own plans
CREATE POLICY "Users can read own plans" ON weekly_training_plans
    FOR SELECT
    USING (
        athlete_id IN (SELECT id FROM athletes WHERE auth_user_id = auth.uid())
    );

-- Policy: Users can insert their own plans
CREATE POLICY "Users can insert own plans" ON weekly_training_plans
    FOR INSERT
    WITH CHECK (
        athlete_id IN (SELECT id FROM athletes WHERE auth_user_id = auth.uid())
    );

-- Policy: Users can update their own plans
CREATE POLICY "Users can update own plans" ON weekly_training_plans
    FOR UPDATE
    USING (
        athlete_id IN (SELECT id FROM athletes WHERE auth_user_id = auth.uid())
    );

-- Policy: Users can delete their own plans
CREATE POLICY "Users can delete own plans" ON weekly_training_plans
    FOR DELETE
    USING (
        athlete_id IN (SELECT id FROM athletes WHERE auth_user_id = auth.uid())
    );

-- Policy: Service role full access
CREATE POLICY "Service role full access" ON weekly_training_plans
    FOR ALL
    USING (auth.role() = 'service_role');

-- Function to get current week's plan
CREATE OR REPLACE FUNCTION get_current_week_plan(p_athlete_id BIGINT)
RETURNS weekly_training_plans AS $$
DECLARE
    week_start DATE;
    result weekly_training_plans;
BEGIN
    -- Calculate Sunday of current week
    week_start := date_trunc('week', CURRENT_DATE)::date - 1;
    IF EXTRACT(DOW FROM CURRENT_DATE) = 0 THEN
        week_start := CURRENT_DATE;
    END IF;

    SELECT * INTO result
    FROM weekly_training_plans
    WHERE athlete_id = p_athlete_id
      AND week_start_date = week_start;

    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION get_current_week_plan(BIGINT) TO authenticated;

-- ============================================
-- EXAMPLE WORKOUTS JSONB STRUCTURE
-- ============================================
-- [
--   {
--     "id": "uuid",
--     "date": "2025-01-05",
--     "day_of_week": "sunday",
--     "workout_type": "long_run",
--     "title": "Long Run",
--     "description": "Build aerobic base with comfortable pace",
--     "duration": 70,
--     "distance": 8.0,
--     "target_pace": "9:00-10:00/mi",
--     "exercises": null,
--     "is_completed": false,
--     "completed_activity_id": null
--   },
--   {
--     "id": "uuid",
--     "date": "2025-01-06",
--     "day_of_week": "monday",
--     "workout_type": "upper_body",
--     "title": "Upper Body Strength",
--     "description": "Focus on pushing and pulling movements",
--     "duration": 45,
--     "distance": null,
--     "target_pace": null,
--     "exercises": [
--       {"name": "Bench Press", "sets": 4, "reps": "8-10"},
--       {"name": "Rows", "sets": 4, "reps": "8-10"}
--     ],
--     "is_completed": false,
--     "completed_activity_id": null
--   }
-- ]
