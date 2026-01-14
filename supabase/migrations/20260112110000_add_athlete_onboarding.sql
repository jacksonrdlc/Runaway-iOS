-- =====================================================
-- Migration: Add Athlete Onboarding Table
-- Purpose: Track onboarding progress and preferences
-- Date: 2026-01-12
-- =====================================================

-- Create athlete_onboarding table
CREATE TABLE IF NOT EXISTS athlete_onboarding (
    id SERIAL PRIMARY KEY,
    athlete_id INTEGER NOT NULL REFERENCES athletes(id) ON DELETE CASCADE,
    is_completed BOOLEAN DEFAULT FALSE,
    current_step INTEGER DEFAULT 0,
    movement_test_cadence DOUBLE PRECISION,
    movement_test_variance DOUBLE PRECISION,
    location_permission_granted BOOLEAN DEFAULT FALSE,
    coach_personality VARCHAR(20) DEFAULT 'balanced',
    experience_level VARCHAR(20),
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(athlete_id)
);

-- Create index for quick athlete lookup
CREATE INDEX IF NOT EXISTS idx_athlete_onboarding_athlete
ON athlete_onboarding(athlete_id);

-- Create index for incomplete onboarding queries
CREATE INDEX IF NOT EXISTS idx_athlete_onboarding_incomplete
ON athlete_onboarding(athlete_id)
WHERE is_completed = false;

-- Enable RLS
ALTER TABLE athlete_onboarding ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can read own onboarding" ON athlete_onboarding;
DROP POLICY IF EXISTS "Users can insert own onboarding" ON athlete_onboarding;
DROP POLICY IF EXISTS "Users can update own onboarding" ON athlete_onboarding;

-- RLS Policies
CREATE POLICY "Users can read own onboarding"
ON athlete_onboarding FOR SELECT
USING (
    athlete_id IN (
        SELECT id FROM athletes WHERE auth_user_id = auth.uid()
    )
);

CREATE POLICY "Users can insert own onboarding"
ON athlete_onboarding FOR INSERT
WITH CHECK (
    athlete_id IN (
        SELECT id FROM athletes WHERE auth_user_id = auth.uid()
    )
);

CREATE POLICY "Users can update own onboarding"
ON athlete_onboarding FOR UPDATE
USING (
    athlete_id IN (
        SELECT id FROM athletes WHERE auth_user_id = auth.uid()
    )
);

-- =====================================================
-- Function to check if athlete has completed onboarding
-- =====================================================
CREATE OR REPLACE FUNCTION check_onboarding_status(p_athlete_id INTEGER)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM athlete_onboarding
        WHERE athlete_id = p_athlete_id AND is_completed = true
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- Verification Queries
-- =====================================================
-- Check table was created:
-- SELECT column_name, data_type, column_default
-- FROM information_schema.columns
-- WHERE table_name = 'athlete_onboarding';
