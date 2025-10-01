-- Fix running_goals table - Add missing deadline column
-- Run this SQL in your Supabase SQL Editor

-- First, let's check if the table exists and see its current structure
DO $$
BEGIN
    -- Check if running_goals table exists
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'running_goals') THEN
        RAISE NOTICE 'running_goals table exists, checking structure...';

        -- Check if deadline column exists
        IF NOT EXISTS (SELECT FROM information_schema.columns
                      WHERE table_name = 'running_goals' AND column_name = 'deadline') THEN
            RAISE NOTICE 'Adding missing deadline column...';

            -- Add the missing deadline column
            ALTER TABLE running_goals ADD COLUMN deadline TIMESTAMP WITH TIME ZONE;

            RAISE NOTICE 'deadline column added successfully';
        ELSE
            RAISE NOTICE 'deadline column already exists';
        END IF;

    ELSE
        RAISE NOTICE 'running_goals table does not exist, creating it...';

        -- Create the complete running_goals table as per ERD
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

        RAISE NOTICE 'running_goals table created with all columns and constraints';
    END IF;
END $$;

-- Verify the final structure
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'running_goals'
ORDER BY ordinal_position;