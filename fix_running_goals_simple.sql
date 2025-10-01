-- Simple fix for running_goals table schema issue
-- This script ensures the running_goals table matches exactly what your iOS app expects

-- Drop the existing table if it has wrong schema
DROP TABLE IF EXISTS running_goals CASCADE;

-- Create the correct running_goals table matching your iOS RunningGoal model
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

-- Verify the table was created correctly
SELECT
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'running_goals'
ORDER BY ordinal_position;