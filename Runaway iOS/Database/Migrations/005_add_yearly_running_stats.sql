-- =====================================================
-- Migration: Add Yearly Running Stats Function
-- Purpose: Calculate yearly running stats server-side to avoid pagination issues
-- Date: 2025-12-23
-- Performance: Single query returns yearly totals regardless of activity count
-- =====================================================

-- =====================================================
-- 1. GET YEARLY RUNNING STATS FUNCTION
-- =====================================================
-- Replaces: Client-side calculation in WidgetSyncService.swift
-- Performance: Calculates stats in database, not affected by pagination

CREATE OR REPLACE FUNCTION get_yearly_running_stats(
    p_athlete_id INTEGER,
    p_year INTEGER DEFAULT EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER
)
RETURNS TABLE(
    year INTEGER,
    total_runs INTEGER,
    total_distance_meters NUMERIC,
    total_distance_miles NUMERIC,
    total_moving_time_seconds BIGINT,
    total_elapsed_time_seconds BIGINT,
    total_elevation_gain_meters NUMERIC,
    average_pace_per_mile_seconds NUMERIC,
    longest_run_meters NUMERIC,
    fastest_pace_per_mile_seconds NUMERIC
) AS $$
DECLARE
    v_year_start TIMESTAMP;
    v_year_end TIMESTAMP;
BEGIN
    -- Calculate year boundaries
    v_year_start := make_timestamp(p_year, 1, 1, 0, 0, 0);
    v_year_end := make_timestamp(p_year + 1, 1, 1, 0, 0, 0);

    RETURN QUERY
    SELECT
        p_year as year,
        COUNT(*)::INTEGER as total_runs,
        COALESCE(SUM(a.distance), 0)::NUMERIC as total_distance_meters,
        COALESCE(SUM(a.distance) * 0.000621371, 0)::NUMERIC as total_distance_miles,
        COALESCE(SUM(a.moving_time), 0)::BIGINT as total_moving_time_seconds,
        COALESCE(SUM(a.elapsed_time), 0)::BIGINT as total_elapsed_time_seconds,
        COALESCE(SUM(a.elevation_gain), 0)::NUMERIC as total_elevation_gain_meters,
        -- Average pace: total time / total miles (in seconds per mile)
        CASE
            WHEN SUM(a.distance) > 0 THEN
                (SUM(a.moving_time)::NUMERIC / (SUM(a.distance) * 0.000621371))::NUMERIC
            ELSE 0
        END as average_pace_per_mile_seconds,
        COALESCE(MAX(a.distance), 0)::NUMERIC as longest_run_meters,
        -- Fastest pace: minimum of (moving_time / distance in miles) for each run
        (
            SELECT MIN(sub.moving_time::NUMERIC / (sub.distance * 0.000621371))
            FROM activities sub
            INNER JOIN activity_types sub_at ON sub.activity_type_id = sub_at.id
            WHERE sub.athlete_id = p_athlete_id
            AND sub.distance > 0
            AND sub.moving_time > 0
            AND LOWER(sub_at.name) LIKE '%run%'
            AND sub.activity_date >= v_year_start
            AND sub.activity_date < v_year_end
        )::NUMERIC as fastest_pace_per_mile_seconds
    FROM activities a
    INNER JOIN activity_types at ON a.activity_type_id = at.id
    WHERE a.athlete_id = p_athlete_id
    AND LOWER(at.name) LIKE '%run%'
    AND a.activity_date >= v_year_start
    AND a.activity_date < v_year_end;
END;
$$ LANGUAGE plpgsql STABLE;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_yearly_running_stats(INTEGER, INTEGER) TO authenticated;

-- =====================================================
-- 2. GET MONTHLY RUNNING STATS FUNCTION
-- =====================================================
-- For current month stats used in widget

CREATE OR REPLACE FUNCTION get_monthly_running_stats(
    p_athlete_id INTEGER,
    p_year INTEGER DEFAULT EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER,
    p_month INTEGER DEFAULT EXTRACT(MONTH FROM CURRENT_DATE)::INTEGER
)
RETURNS TABLE(
    year INTEGER,
    month INTEGER,
    total_runs INTEGER,
    total_distance_meters NUMERIC,
    total_distance_miles NUMERIC,
    total_moving_time_seconds BIGINT,
    total_elevation_gain_meters NUMERIC,
    average_pace_per_mile_seconds NUMERIC
) AS $$
DECLARE
    v_month_start TIMESTAMP;
    v_month_end TIMESTAMP;
BEGIN
    -- Calculate month boundaries
    v_month_start := make_timestamp(p_year, p_month, 1, 0, 0, 0);
    v_month_end := v_month_start + INTERVAL '1 month';

    RETURN QUERY
    SELECT
        p_year as year,
        p_month as month,
        COUNT(*)::INTEGER as total_runs,
        COALESCE(SUM(a.distance), 0)::NUMERIC as total_distance_meters,
        COALESCE(SUM(a.distance) * 0.000621371, 0)::NUMERIC as total_distance_miles,
        COALESCE(SUM(a.moving_time), 0)::BIGINT as total_moving_time_seconds,
        COALESCE(SUM(a.elevation_gain), 0)::NUMERIC as total_elevation_gain_meters,
        CASE
            WHEN SUM(a.distance) > 0 THEN
                (SUM(a.moving_time)::NUMERIC / (SUM(a.distance) * 0.000621371))::NUMERIC
            ELSE 0
        END as average_pace_per_mile_seconds
    FROM activities a
    INNER JOIN activity_types at ON a.activity_type_id = at.id
    WHERE a.athlete_id = p_athlete_id
    AND LOWER(at.name) LIKE '%run%'
    AND a.activity_date >= v_month_start
    AND a.activity_date < v_month_end;
END;
$$ LANGUAGE plpgsql STABLE;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_monthly_running_stats(INTEGER, INTEGER, INTEGER) TO authenticated;

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================
-- Test yearly stats:
-- SELECT * FROM get_yearly_running_stats(YOUR_ATHLETE_ID, 2025);

-- Test monthly stats:
-- SELECT * FROM get_monthly_running_stats(YOUR_ATHLETE_ID, 2025, 12);

-- List all running stats functions:
-- SELECT routine_name, routine_type
-- FROM information_schema.routines
-- WHERE routine_schema = 'public'
-- AND routine_name IN ('get_yearly_running_stats', 'get_monthly_running_stats');
