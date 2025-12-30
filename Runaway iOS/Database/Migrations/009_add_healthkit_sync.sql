-- Migration: Add HealthKit Sync Tracking
-- Description: Track which activities have been synced to Apple Health
-- Run this in your Supabase SQL Editor

-- Add HealthKit sync columns to activities table
ALTER TABLE activities ADD COLUMN IF NOT EXISTS healthkit_uuid UUID;
ALTER TABLE activities ADD COLUMN IF NOT EXISTS synced_to_healthkit BOOLEAN DEFAULT FALSE;
ALTER TABLE activities ADD COLUMN IF NOT EXISTS healthkit_synced_at TIMESTAMPTZ;

-- Index for efficient sync queries
CREATE INDEX IF NOT EXISTS idx_activities_healthkit_sync
ON activities(athlete_id, synced_to_healthkit)
WHERE synced_to_healthkit = FALSE;

-- Index for finding activities by HealthKit UUID
CREATE INDEX IF NOT EXISTS idx_activities_healthkit_uuid
ON activities(healthkit_uuid)
WHERE healthkit_uuid IS NOT NULL;

-- Function to mark activity as synced to HealthKit
CREATE OR REPLACE FUNCTION mark_activity_healthkit_synced(
    p_activity_id BIGINT,
    p_healthkit_uuid UUID
)
RETURNS VOID AS $$
BEGIN
    UPDATE activities
    SET
        healthkit_uuid = p_healthkit_uuid,
        synced_to_healthkit = TRUE,
        healthkit_synced_at = NOW()
    WHERE id = p_activity_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION mark_activity_healthkit_synced(BIGINT, UUID) TO authenticated;

-- Function to get unsynced activities for an athlete
CREATE OR REPLACE FUNCTION get_unsynced_healthkit_activities(p_athlete_id BIGINT)
RETURNS SETOF activities AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM activities
    WHERE athlete_id = p_athlete_id
      AND synced_to_healthkit = FALSE
      AND healthkit_uuid IS NULL
    ORDER BY start_date DESC
    LIMIT 50;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION get_unsynced_healthkit_activities(BIGINT) TO authenticated;
