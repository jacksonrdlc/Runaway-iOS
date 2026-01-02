-- Migration: Add lifetime stats function for awards calculation
-- This calculates all stats needed for awards in a single database call

CREATE OR REPLACE FUNCTION get_lifetime_running_stats(p_athlete_id INTEGER)
RETURNS JSON AS $$
DECLARE
    result JSON;
BEGIN
    SELECT json_build_object(
        'total_distance_meters', COALESCE(SUM(distance), 0),
        'total_runs', COUNT(*),
        'total_time_seconds', COALESCE(SUM(elapsed_time), 0),
        'total_elevation_meters', COALESCE(SUM(elevation_gain), 0),
        'longest_run_meters', COALESCE(MAX(distance), 0),
        'fastest_pace_seconds_per_meter', (
            SELECT MIN(elapsed_time / NULLIF(distance, 0))
            FROM activities
            WHERE athlete_id = p_athlete_id
            AND activity_type_id IN (SELECT id FROM activity_types WHERE LOWER(name) LIKE '%run%')
            AND distance >= 1609.34  -- At least 1 mile
            AND elapsed_time > 0
        ),
        'weekly_streak', (
            WITH weeks_with_runs AS (
                SELECT DISTINCT
                    DATE_TRUNC('week', TO_TIMESTAMP(activity_date))::DATE as week_start
                FROM activities
                WHERE athlete_id = p_athlete_id
                AND activity_type_id IN (SELECT id FROM activity_types WHERE LOWER(name) LIKE '%run%')
                ORDER BY week_start DESC
            ),
            numbered_weeks AS (
                SELECT
                    week_start,
                    ROW_NUMBER() OVER (ORDER BY week_start DESC) as rn,
                    DATE_TRUNC('week', CURRENT_DATE)::DATE - (ROW_NUMBER() OVER (ORDER BY week_start DESC) - 1) * INTERVAL '7 days' as expected_week
                FROM weeks_with_runs
            )
            SELECT COUNT(*)
            FROM numbered_weeks
            WHERE week_start::DATE = expected_week::DATE
        )
    ) INTO result
    FROM activities
    WHERE athlete_id = p_athlete_id
    AND activity_type_id IN (SELECT id FROM activity_types WHERE LOWER(name) LIKE '%run%');

    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Grant access to authenticated users
GRANT EXECUTE ON FUNCTION get_lifetime_running_stats(INTEGER) TO authenticated;
