-- Migration: Add Rest Days Table
-- Description: Track rest days (days without activity) for readiness calculation
-- Run this in your Supabase SQL Editor

-- Create rest_days table
CREATE TABLE IF NOT EXISTS rest_days (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    athlete_id INTEGER NOT NULL REFERENCES athletes(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    is_planned BOOLEAN DEFAULT FALSE,  -- true = scheduled rest, false = unplanned/detected
    reason TEXT,                        -- 'recovery', 'injury', 'life', 'scheduled', 'detected'
    notes TEXT,
    recovery_benefit INTEGER CHECK (recovery_benefit >= 0 AND recovery_benefit <= 100),  -- estimated recovery value
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(athlete_id, date)
);

-- Index for efficient queries by athlete and date
CREATE INDEX IF NOT EXISTS idx_rest_days_athlete_date
ON rest_days(athlete_id, date DESC);

-- Index for recent rest day lookups
CREATE INDEX IF NOT EXISTS idx_rest_days_recent
ON rest_days(athlete_id, created_at DESC);

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_rest_days_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS rest_days_updated_at ON rest_days;
CREATE TRIGGER rest_days_updated_at
    BEFORE UPDATE ON rest_days
    FOR EACH ROW
    EXECUTE FUNCTION update_rest_days_timestamp();

-- Enable Row Level Security
ALTER TABLE rest_days ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own rest days
CREATE POLICY "Users can view their own rest days"
ON rest_days FOR SELECT
USING (athlete_id = (SELECT id FROM athletes WHERE auth_user_id = auth.uid() LIMIT 1));

-- Policy: Users can insert their own rest days
CREATE POLICY "Users can insert their own rest days"
ON rest_days FOR INSERT
WITH CHECK (athlete_id = (SELECT id FROM athletes WHERE auth_user_id = auth.uid() LIMIT 1));

-- Policy: Users can update their own rest days
CREATE POLICY "Users can update their own rest days"
ON rest_days FOR UPDATE
USING (athlete_id = (SELECT id FROM athletes WHERE auth_user_id = auth.uid() LIMIT 1));

-- Policy: Users can delete their own rest days
CREATE POLICY "Users can delete their own rest days"
ON rest_days FOR DELETE
USING (athlete_id = (SELECT id FROM athletes WHERE auth_user_id = auth.uid() LIMIT 1));

-- Function to get rest days count for a date range
CREATE OR REPLACE FUNCTION get_rest_days_count(
    p_athlete_id INTEGER,
    p_start_date DATE,
    p_end_date DATE
)
RETURNS INTEGER AS $$
DECLARE
    rest_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO rest_count
    FROM rest_days
    WHERE athlete_id = p_athlete_id
      AND date >= p_start_date
      AND date <= p_end_date;

    RETURN COALESCE(rest_count, 0);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION get_rest_days_count(INTEGER, DATE, DATE) TO authenticated;

-- Function to get consecutive rest days ending on a specific date
CREATE OR REPLACE FUNCTION get_consecutive_rest_days(
    p_athlete_id INTEGER,
    p_end_date DATE DEFAULT CURRENT_DATE
)
RETURNS INTEGER AS $$
DECLARE
    consecutive_count INTEGER := 0;
    check_date DATE := p_end_date;
    has_rest BOOLEAN;
BEGIN
    LOOP
        SELECT EXISTS(
            SELECT 1 FROM rest_days
            WHERE athlete_id = p_athlete_id AND date = check_date
        ) INTO has_rest;

        EXIT WHEN NOT has_rest;

        consecutive_count := consecutive_count + 1;
        check_date := check_date - INTERVAL '1 day';
    END LOOP;

    RETURN consecutive_count;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION get_consecutive_rest_days(INTEGER, DATE) TO authenticated;

-- Function to get rest day history for an athlete
CREATE OR REPLACE FUNCTION get_rest_day_history(
    p_athlete_id INTEGER,
    p_days INTEGER DEFAULT 30
)
RETURNS TABLE (
    id UUID,
    date DATE,
    is_planned BOOLEAN,
    reason TEXT,
    notes TEXT,
    recovery_benefit INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT rd.id, rd.date, rd.is_planned, rd.reason, rd.notes, rd.recovery_benefit
    FROM rest_days rd
    WHERE rd.athlete_id = p_athlete_id
      AND rd.date >= CURRENT_DATE - p_days
    ORDER BY rd.date DESC;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION get_rest_day_history(INTEGER, INTEGER) TO authenticated;

-- Function to detect and insert missing rest days
-- This can be called periodically to backfill rest days
CREATE OR REPLACE FUNCTION detect_rest_days(
    p_athlete_id INTEGER,
    p_lookback_days INTEGER DEFAULT 7
)
RETURNS INTEGER AS $$
DECLARE
    check_date DATE;
    has_activity BOOLEAN;
    has_rest_day BOOLEAN;
    inserted_count INTEGER := 0;
BEGIN
    -- Loop through the last N days (excluding today)
    FOR i IN 1..p_lookback_days LOOP
        check_date := CURRENT_DATE - i;

        -- Check if there's an activity on this date
        SELECT EXISTS(
            SELECT 1 FROM activities
            WHERE athlete_id = p_athlete_id
              AND DATE(to_timestamp(COALESCE(activity_date, start_date))) = check_date
        ) INTO has_activity;

        -- Check if there's already a rest day record
        SELECT EXISTS(
            SELECT 1 FROM rest_days
            WHERE athlete_id = p_athlete_id AND date = check_date
        ) INTO has_rest_day;

        -- If no activity and no rest day record, insert one
        IF NOT has_activity AND NOT has_rest_day THEN
            INSERT INTO rest_days (athlete_id, date, is_planned, reason, recovery_benefit)
            VALUES (p_athlete_id, check_date, FALSE, 'detected', 75);
            inserted_count := inserted_count + 1;
        END IF;
    END LOOP;

    RETURN inserted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION detect_rest_days(INTEGER, INTEGER) TO authenticated;
