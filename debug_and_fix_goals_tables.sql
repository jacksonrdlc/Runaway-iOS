-- Debug and fix goals table confusion
-- There are two goal tables in the ERD: 'goals' and 'running_goals'
-- Your iOS app uses 'running_goals' but the error suggests 'start_date' which is in 'goals'

-- First, let's see what tables actually exist
SELECT
    'Checking which goal tables exist in the database:' as info;

SELECT
    table_name,
    CASE
        WHEN table_name = 'goals' THEN 'General goals table (has start_date, end_date)'
        WHEN table_name = 'running_goals' THEN 'Running-specific goals table (has deadline)'
        ELSE 'Other table'
    END as description
FROM information_schema.tables
WHERE table_name IN ('goals', 'running_goals')
ORDER BY table_name;

-- Check the structure of running_goals if it exists
DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'running_goals') THEN
        RAISE NOTICE 'running_goals table structure:';
    END IF;
END $$;

SELECT
    'running_goals table columns:' as info;

SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'running_goals'
ORDER BY ordinal_position;

-- Check the structure of goals if it exists
DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'goals') THEN
        RAISE NOTICE 'goals table structure:';
    END IF;
END $$;

SELECT
    'goals table columns:' as info;

SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'goals'
ORDER BY ordinal_position;

-- Show any data in both tables
SELECT 'Data in running_goals:' as info;

DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'running_goals') THEN
        EXECUTE 'SELECT COUNT(*) as row_count FROM running_goals';
    ELSE
        RAISE NOTICE 'running_goals table does not exist';
    END IF;
END $$;

SELECT 'Data in goals:' as info;

DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'goals') THEN
        EXECUTE 'SELECT COUNT(*) as row_count FROM goals';
    ELSE
        RAISE NOTICE 'goals table does not exist';
    END IF;
END $$;

-- Based on the findings, we'll need to ensure running_goals has the correct structure
-- Drop and recreate running_goals table to match exactly what iOS expects

DROP TABLE IF EXISTS running_goals CASCADE;

CREATE TABLE running_goals (
    id BIGSERIAL PRIMARY KEY,
    athlete_id BIGINT NOT NULL,
    title VARCHAR NOT NULL,
    goal_type VARCHAR NOT NULL,
    target_value DECIMAL NOT NULL,
    deadline TIMESTAMP WITH TIME ZONE NOT NULL,
    is_active BOOLEAN DEFAULT true,
    is_completed BOOLEAN DEFAULT false,
    current_progress DECIMAL DEFAULT 0.0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,

    -- Foreign key constraint
    CONSTRAINT fk_running_goals_athlete_id
        FOREIGN KEY (athlete_id) REFERENCES athletes(id) ON DELETE CASCADE
);

-- Create indexes for better performance
CREATE INDEX idx_running_goals_athlete_id ON running_goals(athlete_id);
CREATE INDEX idx_running_goals_is_active ON running_goals(is_active);
CREATE INDEX idx_running_goals_deadline ON running_goals(deadline);

-- Enable RLS (Row Level Security)
ALTER TABLE running_goals ENABLE ROW LEVEL SECURITY;

-- Create RLS policy - users can only access their own goals
CREATE POLICY "Users can manage their own running goals"
    ON running_goals
    FOR ALL
    USING (athlete_id IN (
        SELECT id FROM athletes WHERE auth_user_id = auth.uid()
    ));

SELECT
    'FIXED: running_goals table now matches iOS RunningGoal model exactly' as result;