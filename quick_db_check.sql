-- Quick Database Check for Runaway iOS
-- Run this for a fast overview of your database status

-- Check if all critical tables exist
SELECT
    'athletes' as table_name,
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'athletes' AND table_schema = 'public')
        THEN '✅ EXISTS' ELSE '❌ MISSING' END as status
UNION ALL
SELECT
    'activities',
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'activities' AND table_schema = 'public')
        THEN '✅ EXISTS' ELSE '❌ MISSING' END
UNION ALL
SELECT
    'running_goals',
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'running_goals' AND table_schema = 'public')
        THEN '✅ EXISTS' ELSE '❌ MISSING' END
UNION ALL
SELECT
    'daily_commitments',
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'daily_commitments' AND table_schema = 'public')
        THEN '✅ EXISTS' ELSE '❌ MISSING' END
UNION ALL
SELECT
    'activity_types',
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'activity_types' AND table_schema = 'public')
        THEN '✅ EXISTS' ELSE '❌ MISSING' END;

-- Check if auth_user_id column exists in athletes table
SELECT
    'auth_user_id in athletes' as column_check,
    CASE WHEN EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'athletes'
        AND column_name = 'auth_user_id'
        AND table_schema = 'public'
    )
    THEN '✅ EXISTS' ELSE '❌ MISSING - ADD THIS COLUMN' END as status;

-- Quick row counts
SELECT
    'Row Counts' as info,
    (SELECT COUNT(*) FROM athletes) as athletes_count,
    (SELECT COUNT(*) FROM activities) as activities_count,
    (SELECT COALESCE(COUNT(*), 0) FROM running_goals) as goals_count,
    (SELECT COALESCE(COUNT(*), 0) FROM daily_commitments) as commitments_count;