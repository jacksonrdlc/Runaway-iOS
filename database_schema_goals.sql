-- Running Goals Table Schema for Supabase
-- This table stores user running goals with AI recommendations support

CREATE TABLE IF NOT EXISTS running_goals (
    -- Primary key
    id BIGSERIAL PRIMARY KEY,
    
    -- User relationship (matches your existing user_id pattern)
    user_id INTEGER NOT NULL,
    
    -- Goal details
    title TEXT NOT NULL,
    goal_type TEXT NOT NULL CHECK (goal_type IN ('distance', 'time', 'pace')),
    target_value DECIMAL(10,4) NOT NULL CHECK (target_value > 0),
    deadline TIMESTAMPTZ NOT NULL,
    
    -- Status and tracking
    is_active BOOLEAN DEFAULT TRUE,
    is_completed BOOLEAN DEFAULT FALSE,
    current_progress DECIMAL(5,4) DEFAULT 0.0 CHECK (current_progress >= 0.0 AND current_progress <= 1.0),
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ NULL,
    
    -- Ensure deadline is in the future when created
    CONSTRAINT future_deadline CHECK (deadline > created_at)
    
    -- Note: Unique constraint for active goals will be handled by a partial index below
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_running_goals_user_id ON running_goals(user_id);
CREATE INDEX IF NOT EXISTS idx_running_goals_active ON running_goals(user_id, is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_running_goals_deadline ON running_goals(deadline);

-- Ensure only one active goal per user per goal type (partial unique index)
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_active_goal_per_type 
    ON running_goals(user_id, goal_type) 
    WHERE is_active = TRUE;

-- RLS (Row Level Security) policies
ALTER TABLE running_goals ENABLE ROW LEVEL SECURITY;

-- Option 1: Simple policy if you handle user_id validation in your app
-- Users can only access goals where they are authenticated
CREATE POLICY "Users can manage their own goals" ON running_goals
    FOR ALL USING (auth.uid() IS NOT NULL);

-- Option 2: If you have a users table with auth_id mapping, uncomment these instead:
-- CREATE POLICY "Users can view their own goals" ON running_goals
--     FOR SELECT USING (user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid()));
-- 
-- CREATE POLICY "Users can insert their own goals" ON running_goals
--     FOR INSERT WITH CHECK (user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid()));
-- 
-- CREATE POLICY "Users can update their own goals" ON running_goals
--     FOR UPDATE USING (user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid()));
-- 
-- CREATE POLICY "Users can delete their own goals" ON running_goals
--     FOR DELETE USING (user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid()));

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_running_goals_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    
    -- If goal is being marked as completed, set completed_at
    IF NEW.is_completed = TRUE AND OLD.is_completed = FALSE THEN
        NEW.completed_at = NOW();
    END IF;
    
    -- If goal is being marked as not completed, clear completed_at
    IF NEW.is_completed = FALSE AND OLD.is_completed = TRUE THEN
        NEW.completed_at = NULL;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to call the function
CREATE TRIGGER trigger_update_running_goals_updated_at
    BEFORE UPDATE ON running_goals
    FOR EACH ROW
    EXECUTE FUNCTION update_running_goals_updated_at();

-- Optional: Create a view for active goals with computed fields
CREATE OR REPLACE VIEW active_running_goals AS
SELECT 
    *,
    EXTRACT(DAY FROM (deadline - NOW())) AS days_remaining,
    EXTRACT(EPOCH FROM (deadline - NOW())) / (7 * 24 * 3600) AS weeks_remaining,
    CASE 
        WHEN current_progress >= 0.9 THEN 'on_track'
        WHEN current_progress >= 0.7 THEN 'slightly_behind'
        ELSE 'significantly_behind'
    END AS tracking_status
FROM running_goals 
WHERE is_active = TRUE AND is_completed = FALSE;

-- Grant permissions (adjust based on your Supabase setup)
-- GRANT ALL ON running_goals TO authenticated;
-- GRANT ALL ON SEQUENCE running_goals_id_seq TO authenticated;