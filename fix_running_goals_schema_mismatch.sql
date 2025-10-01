-- Fix running_goals table schema to match iOS model
-- This script aligns the database with the RunningGoal model and ERD

-- First, check current table structure
SELECT
    'Current running_goals table structure:' as info;

SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'running_goals'
ORDER BY ordinal_position;

-- Show what the iOS model expects vs what we have
SELECT
    'Expected columns per iOS RunningGoal model:' as info;

-- Drop and recreate the table to match the ERD and iOS model exactly
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

-- Verify the final structure matches what iOS expects
SELECT
    'Final running_goals table structure (should match iOS RunningGoal model):' as info;

SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'running_goals'
ORDER BY ordinal_position;

-- Show mapping to iOS RunningGoal model
SELECT
    'iOS RunningGoal field -> Database column mapping:' as info,
    'id -> id' as mapping
UNION ALL SELECT '', 'athleteId -> athlete_id'
UNION ALL SELECT '', 'type -> goal_type'
UNION ALL SELECT '', 'targetValue -> target_value'
UNION ALL SELECT '', 'deadline -> deadline'
UNION ALL SELECT '', 'createdDate -> created_at'
UNION ALL SELECT '', 'updatedDate -> updated_at'
UNION ALL SELECT '', 'title -> title'
UNION ALL SELECT '', 'isActive -> is_active'
UNION ALL SELECT '', 'isCompleted -> is_completed'
UNION ALL SELECT '', 'currentProgress -> current_progress'
UNION ALL SELECT '', 'completedDate -> completed_at';