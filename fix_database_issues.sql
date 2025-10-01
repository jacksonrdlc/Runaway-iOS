-- Database Fix Script for Runaway iOS
-- Run this to fix common database schema issues

-- =============================================================================
-- 1. ADD auth_user_id TO ATHLETES TABLE (if missing)
-- =============================================================================

-- Add auth_user_id column to athletes table if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'athletes'
        AND column_name = 'auth_user_id'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE athletes ADD COLUMN auth_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;
        RAISE NOTICE '✅ Added auth_user_id column to athletes table';
    ELSE
        RAISE NOTICE '✅ auth_user_id column already exists in athletes table';
    END IF;
END $$;

-- Add unique constraint on auth_user_id (if it doesn't exist)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'unique_auth_user_id'
        AND table_name = 'athletes'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE athletes ADD CONSTRAINT unique_auth_user_id UNIQUE (auth_user_id);
        RAISE NOTICE '✅ Added unique constraint on auth_user_id';
    ELSE
        RAISE NOTICE '✅ Unique constraint on auth_user_id already exists';
    END IF;
END $$;

-- =============================================================================
-- 2. CREATE DAILY_COMMITMENTS TABLE (if missing)
-- =============================================================================

CREATE TABLE IF NOT EXISTS daily_commitments (
    id BIGSERIAL PRIMARY KEY,
    athlete_id BIGINT NOT NULL REFERENCES athletes(id) ON DELETE CASCADE,
    commitment_date DATE NOT NULL,
    activity_type VARCHAR(50) NOT NULL CHECK (activity_type IN ('Run', 'Weight Training', 'Walk', 'Yoga')),
    is_fulfilled BOOLEAN NOT NULL DEFAULT FALSE,
    fulfilled_at TIMESTAMP WITH TIME ZONE NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Ensure one commitment per athlete per day
    UNIQUE(athlete_id, commitment_date)
);

-- =============================================================================
-- 3. UPDATE RUNNING_GOALS TABLE (fix user_id -> athlete_id)
-- =============================================================================

-- Check if running_goals table uses user_id instead of athlete_id
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'running_goals'
        AND column_name = 'user_id'
        AND table_schema = 'public'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'running_goals'
        AND column_name = 'athlete_id'
        AND table_schema = 'public'
    ) THEN
        -- Rename user_id to athlete_id
        ALTER TABLE running_goals RENAME COLUMN user_id TO athlete_id;

        -- Update foreign key constraint if needed
        ALTER TABLE running_goals DROP CONSTRAINT IF EXISTS running_goals_user_id_fkey;
        ALTER TABLE running_goals ADD CONSTRAINT running_goals_athlete_id_fkey
            FOREIGN KEY (athlete_id) REFERENCES athletes(id) ON DELETE CASCADE;

        RAISE NOTICE '✅ Updated running_goals table: user_id -> athlete_id';
    ELSE
        RAISE NOTICE '✅ running_goals table already uses athlete_id or doesn''t exist';
    END IF;
END $$;

-- =============================================================================
-- 4. CREATE ESSENTIAL INDEXES (if missing)
-- =============================================================================

-- Index for daily_commitments lookups
CREATE INDEX IF NOT EXISTS idx_daily_commitments_athlete_date
ON daily_commitments(athlete_id, commitment_date);

-- Index for running_goals lookups
CREATE INDEX IF NOT EXISTS idx_running_goals_athlete_active
ON running_goals(athlete_id, is_active) WHERE is_active = TRUE;

-- Index for activities by athlete
CREATE INDEX IF NOT EXISTS idx_activities_athlete_date
ON activities(athlete_id, activity_date DESC);

-- Index for athletes by auth_user_id
CREATE INDEX IF NOT EXISTS idx_athletes_auth_user_id
ON athletes(auth_user_id);

-- =============================================================================
-- 5. ENABLE ROW LEVEL SECURITY (RLS)
-- =============================================================================

-- Enable RLS on critical tables
ALTER TABLE athletes ENABLE ROW LEVEL SECURITY;
ALTER TABLE activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE running_goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_commitments ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- 6. CREATE BASIC RLS POLICIES
-- =============================================================================

-- Athletes can only see their own data
DROP POLICY IF EXISTS "Users can manage their own athlete data" ON athletes;
CREATE POLICY "Users can manage their own athlete data" ON athletes
    FOR ALL USING (auth.uid() = auth_user_id);

-- Activities policy
DROP POLICY IF EXISTS "Users can manage their own activities" ON activities;
CREATE POLICY "Users can manage their own activities" ON activities
    FOR ALL USING (
        athlete_id IN (
            SELECT id FROM athletes WHERE auth_user_id = auth.uid()
        )
    );

-- Running goals policy
DROP POLICY IF EXISTS "Users can manage their own goals" ON running_goals;
CREATE POLICY "Users can manage their own goals" ON running_goals
    FOR ALL USING (
        athlete_id IN (
            SELECT id FROM athletes WHERE auth_user_id = auth.uid()
        )
    );

-- Daily commitments policy
DROP POLICY IF EXISTS "Users can manage their own commitments" ON daily_commitments;
CREATE POLICY "Users can manage their own commitments" ON daily_commitments
    FOR ALL USING (
        athlete_id IN (
            SELECT id FROM athletes WHERE auth_user_id = auth.uid()
        )
    );

-- =============================================================================
-- 7. GRANT PERMISSIONS
-- =============================================================================

GRANT ALL ON athletes TO authenticated;
GRANT ALL ON activities TO authenticated;
GRANT ALL ON running_goals TO authenticated;
GRANT ALL ON daily_commitments TO authenticated;
GRANT ALL ON activity_types TO authenticated;

-- Grant sequence permissions
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

RAISE NOTICE '';
RAISE NOTICE '🎉 Database fix script completed!';
RAISE NOTICE 'Run the verification script to check everything is working correctly.';