-- Create athlete_stats table for Runaway iOS
-- This table stores calculated statistics for each athlete

CREATE TABLE IF NOT EXISTS athlete_stats (
    id BIGSERIAL PRIMARY KEY,
    athlete_id BIGINT NOT NULL REFERENCES athletes(id) ON DELETE CASCADE,

    -- Activity counts and totals
    count INTEGER DEFAULT 0,                    -- Total number of activities
    distance DECIMAL(10,2) DEFAULT 0,          -- Total distance (meters)
    moving_time BIGINT DEFAULT 0,              -- Total moving time (seconds)
    elapsed_time BIGINT DEFAULT 0,             -- Total elapsed time (seconds)
    elevation_gain DECIMAL(10,2) DEFAULT 0,    -- Total elevation gain (meters)

    -- Achievements and yearly stats
    achievement_count INTEGER DEFAULT 0,        -- Number of achievements earned
    ytd_distance DECIMAL(10,2) DEFAULT 0,      -- Year-to-date distance (meters)

    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Ensure one stats record per athlete
    UNIQUE(athlete_id)
);

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_athlete_stats_athlete_id ON athlete_stats(athlete_id);

-- Create trigger for automatic updated_at timestamp
CREATE OR REPLACE FUNCTION update_athlete_stats_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER trigger_update_athlete_stats_updated_at
    BEFORE UPDATE ON athlete_stats
    FOR EACH ROW
    EXECUTE FUNCTION update_athlete_stats_updated_at();

-- Enable RLS
ALTER TABLE athlete_stats ENABLE ROW LEVEL SECURITY;

-- Create RLS policy
CREATE POLICY "Users can manage their own stats" ON athlete_stats
    FOR ALL USING (
        athlete_id IN (
            SELECT id FROM athletes WHERE auth_user_id = auth.uid()
        )
    );

-- Grant permissions
GRANT ALL ON athlete_stats TO authenticated;
GRANT USAGE ON SEQUENCE athlete_stats_id_seq TO authenticated;

-- Insert initial stats for existing athletes (optional)
-- This calculates basic stats from existing activities
INSERT INTO athlete_stats (athlete_id, count, distance, moving_time, elapsed_time, elevation_gain)
SELECT
    a.id as athlete_id,
    COALESCE(COUNT(act.id), 0) as count,
    COALESCE(SUM(act.distance), 0) as distance,
    COALESCE(SUM(act.moving_time), 0) as moving_time,
    COALESCE(SUM(act.elapsed_time), 0) as elapsed_time,
    COALESCE(SUM(act.elevation_gain), 0) as elevation_gain
FROM athletes a
LEFT JOIN activities act ON a.id = act.athlete_id
GROUP BY a.id
ON CONFLICT (athlete_id) DO UPDATE SET
    count = EXCLUDED.count,
    distance = EXCLUDED.distance,
    moving_time = EXCLUDED.moving_time,
    elapsed_time = EXCLUDED.elapsed_time,
    elevation_gain = EXCLUDED.elevation_gain,
    updated_at = CURRENT_TIMESTAMP;