-- Migration: Add Analytics Events Table
-- Description: Track user events for analytics dashboard
-- Run this in your Supabase SQL Editor

-- Create analytics_events table
CREATE TABLE IF NOT EXISTS analytics_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,

    -- User identification (nullable for anonymous events)
    -- Note: athlete_id is BIGINT to match athletes.id column type
    athlete_id BIGINT REFERENCES athletes(id) ON DELETE SET NULL,
    device_id TEXT, -- For tracking across sessions before auth

    -- Event identification
    event_name TEXT NOT NULL,
    event_category TEXT NOT NULL, -- 'activity', 'audio_coaching', 'navigation', 'engagement', etc.

    -- Event properties (flexible JSON for different event types)
    properties JSONB DEFAULT '{}',

    -- Context
    app_version TEXT,
    os_version TEXT,
    device_model TEXT,
    session_id UUID, -- Group events by session

    -- Location context (optional, for activity events)
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION
);

-- Create indexes for common queries
CREATE INDEX IF NOT EXISTS idx_analytics_events_athlete_id ON analytics_events(athlete_id);
CREATE INDEX IF NOT EXISTS idx_analytics_events_event_name ON analytics_events(event_name);
CREATE INDEX IF NOT EXISTS idx_analytics_events_event_category ON analytics_events(event_category);
CREATE INDEX IF NOT EXISTS idx_analytics_events_created_at ON analytics_events(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_analytics_events_session_id ON analytics_events(session_id);

-- Composite index for common dashboard queries
CREATE INDEX IF NOT EXISTS idx_analytics_events_category_date
ON analytics_events(event_category, created_at DESC);

-- Enable RLS
ALTER TABLE analytics_events ENABLE ROW LEVEL SECURITY;

-- Policy: Users can insert their own events
-- Note: athlete_id is BIGINT, auth.uid() is UUID, so we look up via athletes table
CREATE POLICY "Users can insert own events" ON analytics_events
    FOR INSERT
    WITH CHECK (
        athlete_id IN (SELECT id FROM athletes WHERE auth_user_id = auth.uid())
        OR athlete_id IS NULL
    );

-- Policy: Users can read their own events
CREATE POLICY "Users can read own events" ON analytics_events
    FOR SELECT
    USING (
        athlete_id IN (SELECT id FROM athletes WHERE auth_user_id = auth.uid())
        OR athlete_id IS NULL
    );

-- Policy: Service role can do anything (for admin dashboard)
CREATE POLICY "Service role full access" ON analytics_events
    FOR ALL
    USING (auth.role() = 'service_role');

-- ============================================
-- ANALYTICS VIEWS FOR DASHBOARD
-- ============================================

-- Daily event counts by category
CREATE OR REPLACE VIEW analytics_daily_summary AS
SELECT
    DATE(created_at) as date,
    event_category,
    event_name,
    COUNT(*) as event_count,
    COUNT(DISTINCT athlete_id) as unique_users,
    COUNT(DISTINCT session_id) as unique_sessions
FROM analytics_events
WHERE created_at > NOW() - INTERVAL '90 days'
GROUP BY DATE(created_at), event_category, event_name
ORDER BY date DESC, event_count DESC;

-- Activity recording funnel
CREATE OR REPLACE VIEW analytics_activity_funnel AS
SELECT
    DATE(created_at) as date,
    COUNT(*) FILTER (WHERE event_name = 'activity_started') as started,
    COUNT(*) FILTER (WHERE event_name = 'activity_paused') as paused,
    COUNT(*) FILTER (WHERE event_name = 'activity_resumed') as resumed,
    COUNT(*) FILTER (WHERE event_name = 'activity_stopped') as stopped,
    COUNT(*) FILTER (WHERE event_name = 'activity_saved') as saved,
    COUNT(*) FILTER (WHERE event_name = 'activity_discarded') as discarded
FROM analytics_events
WHERE event_category = 'activity'
    AND created_at > NOW() - INTERVAL '30 days'
GROUP BY DATE(created_at)
ORDER BY date DESC;

-- Audio coaching engagement
CREATE OR REPLACE VIEW analytics_audio_coaching AS
SELECT
    DATE(created_at) as date,
    event_name,
    COUNT(*) as count,
    COUNT(DISTINCT athlete_id) as unique_users,
    AVG((properties->>'elapsed_time')::numeric) as avg_elapsed_time
FROM analytics_events
WHERE event_category = 'audio_coaching'
    AND created_at > NOW() - INTERVAL '30 days'
GROUP BY DATE(created_at), event_name
ORDER BY date DESC;

-- User engagement metrics
CREATE OR REPLACE VIEW analytics_user_engagement AS
SELECT
    athlete_id,
    MIN(created_at) as first_seen,
    MAX(created_at) as last_seen,
    COUNT(DISTINCT DATE(created_at)) as active_days,
    COUNT(DISTINCT session_id) as total_sessions,
    COUNT(*) as total_events,
    COUNT(*) FILTER (WHERE event_category = 'activity') as activity_events,
    COUNT(*) FILTER (WHERE event_name = 'activity_saved') as activities_completed
FROM analytics_events
WHERE athlete_id IS NOT NULL
GROUP BY athlete_id;

-- Hourly activity distribution (what time do users run?)
CREATE OR REPLACE VIEW analytics_activity_hours AS
SELECT
    EXTRACT(HOUR FROM created_at) as hour_of_day,
    EXTRACT(DOW FROM created_at) as day_of_week,
    COUNT(*) as activity_count
FROM analytics_events
WHERE event_name = 'activity_started'
    AND created_at > NOW() - INTERVAL '90 days'
GROUP BY EXTRACT(HOUR FROM created_at), EXTRACT(DOW FROM created_at)
ORDER BY day_of_week, hour_of_day;

-- Grant access to views
GRANT SELECT ON analytics_daily_summary TO authenticated;
GRANT SELECT ON analytics_activity_funnel TO authenticated;
GRANT SELECT ON analytics_audio_coaching TO authenticated;
GRANT SELECT ON analytics_user_engagement TO authenticated;
GRANT SELECT ON analytics_activity_hours TO authenticated;

-- ============================================
-- USEFUL QUERIES FOR SUPABASE DASHBOARD
-- ============================================

-- Example: Get events for last 7 days
-- SELECT * FROM analytics_events
-- WHERE created_at > NOW() - INTERVAL '7 days'
-- ORDER BY created_at DESC;

-- Example: Most common events
-- SELECT event_name, COUNT(*) as count
-- FROM analytics_events
-- GROUP BY event_name
-- ORDER BY count DESC
-- LIMIT 20;

-- Example: Daily active users
-- SELECT DATE(created_at) as date, COUNT(DISTINCT athlete_id) as dau
-- FROM analytics_events
-- WHERE created_at > NOW() - INTERVAL '30 days'
-- GROUP BY DATE(created_at)
-- ORDER BY date DESC;
