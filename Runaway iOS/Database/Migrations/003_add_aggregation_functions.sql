-- =====================================================
-- Migration: Add Aggregation Functions
-- Purpose: Move expensive calculations from client to database
-- Date: 2025-11-26
-- Performance: Reduces client-side processing and network payload
-- =====================================================

-- =====================================================
-- 1. GET COMMITMENT STATS FUNCTION
-- =====================================================
-- Replaces: CommitmentService.swift getCommitmentStats() lines 189-213
-- Performance: Calculates stats in database instead of fetching all records

CREATE OR REPLACE FUNCTION get_commitment_stats(
    p_athlete_id INTEGER,
    p_days INTEGER DEFAULT 30
)
RETURNS TABLE(
    total_commitments INTEGER,
    fulfilled_commitments INTEGER,
    fulfillment_rate NUMERIC,
    current_streak INTEGER
) AS $$
DECLARE
    v_start_date DATE;
    v_total INTEGER;
    v_fulfilled INTEGER;
    v_rate NUMERIC;
    v_streak INTEGER;
BEGIN
    -- Calculate start date
    v_start_date := CURRENT_DATE - (p_days || ' days')::INTERVAL;

    -- Get total and fulfilled commitments
    SELECT
        COUNT(*)::INTEGER,
        SUM(CASE WHEN is_fulfilled THEN 1 ELSE 0 END)::INTEGER
    INTO v_total, v_fulfilled
    FROM daily_commitments
    WHERE athlete_id = p_athlete_id
    AND commitment_date >= v_start_date;

    -- Calculate fulfillment rate
    IF v_total > 0 THEN
        v_rate := ROUND(v_fulfilled::NUMERIC / v_total::NUMERIC, 4);
    ELSE
        v_rate := 0.0;
    END IF;

    -- Calculate current streak (call helper function)
    v_streak := calculate_streak(p_athlete_id);

    -- Return single row result
    RETURN QUERY SELECT v_total, v_fulfilled, v_rate, v_streak;
END;
$$ LANGUAGE plpgsql STABLE;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_commitment_stats(INTEGER, INTEGER) TO authenticated;

-- =====================================================
-- 2. CALCULATE CURRENT STREAK FUNCTION
-- =====================================================
-- Replaces: CommitmentService.swift calculateCurrentStreak() lines 217-231
-- Performance: Single query instead of fetching all commitments and iterating

CREATE OR REPLACE FUNCTION calculate_streak(p_athlete_id INTEGER)
RETURNS INTEGER AS $$
DECLARE
    v_streak INTEGER := 0;
    v_current_date DATE := CURRENT_DATE;
    v_is_fulfilled BOOLEAN;
BEGIN
    -- Loop backwards from today to find consecutive fulfilled commitments
    LOOP
        -- Check if commitment exists and is fulfilled for current date
        SELECT is_fulfilled INTO v_is_fulfilled
        FROM daily_commitments
        WHERE athlete_id = p_athlete_id
        AND commitment_date = v_current_date;

        -- Exit if no commitment found or not fulfilled
        IF v_is_fulfilled IS NULL OR v_is_fulfilled = FALSE THEN
            EXIT;
        END IF;

        -- Increment streak and move to previous day
        v_streak := v_streak + 1;
        v_current_date := v_current_date - INTERVAL '1 day';

        -- Safety check: don't loop forever (max 365 days)
        IF v_streak >= 365 THEN
            EXIT;
        END IF;
    END LOOP;

    RETURN v_streak;
END;
$$ LANGUAGE plpgsql STABLE;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION calculate_streak(INTEGER) TO authenticated;

-- =====================================================
-- 3. GET WEEKLY COMMITMENT SUMMARY (BONUS)
-- =====================================================
-- New function for weekly insights (can be used in future dashboard views)

CREATE OR REPLACE FUNCTION get_weekly_commitment_summary(p_athlete_id INTEGER)
RETURNS TABLE(
    week_start DATE,
    total_commitments INTEGER,
    fulfilled_commitments INTEGER,
    fulfillment_rate NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        DATE_TRUNC('week', commitment_date)::DATE as week_start,
        COUNT(*)::INTEGER as total_commitments,
        SUM(CASE WHEN is_fulfilled THEN 1 ELSE 0 END)::INTEGER as fulfilled_commitments,
        ROUND(
            SUM(CASE WHEN is_fulfilled THEN 1 ELSE 0 END)::NUMERIC /
            COUNT(*)::NUMERIC,
            4
        ) as fulfillment_rate
    FROM daily_commitments
    WHERE athlete_id = p_athlete_id
    AND commitment_date >= CURRENT_DATE - INTERVAL '8 weeks'
    GROUP BY DATE_TRUNC('week', commitment_date)
    ORDER BY week_start DESC;
END;
$$ LANGUAGE plpgsql STABLE;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_weekly_commitment_summary(INTEGER) TO authenticated;

-- =====================================================
-- 4. GET MONTHLY COMMITMENT SUMMARY (BONUS)
-- =====================================================
-- New function for monthly trends

CREATE OR REPLACE FUNCTION get_monthly_commitment_summary(p_athlete_id INTEGER)
RETURNS TABLE(
    month_start DATE,
    total_commitments INTEGER,
    fulfilled_commitments INTEGER,
    fulfillment_rate NUMERIC,
    most_common_type TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        DATE_TRUNC('month', commitment_date)::DATE as month_start,
        COUNT(*)::INTEGER as total_commitments,
        SUM(CASE WHEN is_fulfilled THEN 1 ELSE 0 END)::INTEGER as fulfilled_commitments,
        ROUND(
            SUM(CASE WHEN is_fulfilled THEN 1 ELSE 0 END)::NUMERIC /
            COUNT(*)::NUMERIC,
            4
        ) as fulfillment_rate,
        MODE() WITHIN GROUP (ORDER BY activity_type) as most_common_type
    FROM daily_commitments
    WHERE athlete_id = p_athlete_id
    AND commitment_date >= CURRENT_DATE - INTERVAL '12 months'
    GROUP BY DATE_TRUNC('month', commitment_date)
    ORDER BY month_start DESC;
END;
$$ LANGUAGE plpgsql STABLE;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_monthly_commitment_summary(INTEGER) TO authenticated;

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================
-- Test the functions with your athlete_id (replace 123 with your actual ID):

-- Test commitment stats:
-- SELECT * FROM get_commitment_stats(123, 30);

-- Test streak calculation:
-- SELECT calculate_streak(123);

-- Test weekly summary:
-- SELECT * FROM get_weekly_commitment_summary(123);

-- Test monthly summary:
-- SELECT * FROM get_monthly_commitment_summary(123);

-- List all created functions:
-- SELECT routine_name, routine_type
-- FROM information_schema.routines
-- WHERE routine_schema = 'public'
-- AND routine_name IN ('get_commitment_stats', 'calculate_streak', 'get_weekly_commitment_summary', 'get_monthly_commitment_summary');
