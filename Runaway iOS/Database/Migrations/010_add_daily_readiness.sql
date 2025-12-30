-- Migration: Add Daily Readiness Table
-- Description: Store daily readiness/recovery scores calculated from HealthKit data
-- Run this in your Supabase SQL Editor

-- Create daily_readiness table
CREATE TABLE IF NOT EXISTS daily_readiness (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    athlete_id INTEGER NOT NULL REFERENCES athletes(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    score INTEGER NOT NULL CHECK (score >= 0 AND score <= 100),
    sleep_score INTEGER CHECK (sleep_score >= 0 AND sleep_score <= 100),
    hrv_score INTEGER CHECK (hrv_score >= 0 AND hrv_score <= 100),
    resting_hr_score INTEGER CHECK (resting_hr_score >= 0 AND resting_hr_score <= 100),
    training_load_score INTEGER CHECK (training_load_score >= 0 AND training_load_score <= 100),
    recommendation TEXT,
    factors JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(athlete_id, date)
);

-- Index for efficient queries by athlete and date
CREATE INDEX IF NOT EXISTS idx_daily_readiness_athlete_date
ON daily_readiness(athlete_id, date DESC);

-- Index for recent readiness lookups
CREATE INDEX IF NOT EXISTS idx_daily_readiness_recent
ON daily_readiness(athlete_id, created_at DESC);

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_daily_readiness_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER daily_readiness_updated_at
    BEFORE UPDATE ON daily_readiness
    FOR EACH ROW
    EXECUTE FUNCTION update_daily_readiness_timestamp();

-- Enable Row Level Security
ALTER TABLE daily_readiness ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own readiness data
CREATE POLICY "Users can view their own readiness"
ON daily_readiness FOR SELECT
USING (athlete_id = (SELECT id FROM athletes WHERE user_id = auth.uid() LIMIT 1));

-- Policy: Users can insert their own readiness data
CREATE POLICY "Users can insert their own readiness"
ON daily_readiness FOR INSERT
WITH CHECK (athlete_id = (SELECT id FROM athletes WHERE user_id = auth.uid() LIMIT 1));

-- Policy: Users can update their own readiness data
CREATE POLICY "Users can update their own readiness"
ON daily_readiness FOR UPDATE
USING (athlete_id = (SELECT id FROM athletes WHERE user_id = auth.uid() LIMIT 1));

-- Function to get readiness history for an athlete
CREATE OR REPLACE FUNCTION get_readiness_history(
    p_athlete_id INTEGER,
    p_days INTEGER DEFAULT 30
)
RETURNS SETOF daily_readiness AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM daily_readiness
    WHERE athlete_id = p_athlete_id
      AND date >= CURRENT_DATE - p_days
    ORDER BY date DESC;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION get_readiness_history(INTEGER, INTEGER) TO authenticated;

-- Function to get average readiness score for last N days
CREATE OR REPLACE FUNCTION get_average_readiness(
    p_athlete_id INTEGER,
    p_days INTEGER DEFAULT 7
)
RETURNS NUMERIC AS $$
DECLARE
    avg_score NUMERIC;
BEGIN
    SELECT AVG(score)::NUMERIC(5,2)
    INTO avg_score
    FROM daily_readiness
    WHERE athlete_id = p_athlete_id
      AND date >= CURRENT_DATE - p_days;

    RETURN COALESCE(avg_score, 0);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION get_average_readiness(INTEGER, INTEGER) TO authenticated;
