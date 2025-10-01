-- Quick check of running_goals table structure
-- Run this in Supabase SQL Editor to see current state

-- Check if table exists
SELECT
    CASE
        WHEN EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'running_goals')
        THEN 'running_goals table EXISTS'
        ELSE 'running_goals table DOES NOT EXIST'
    END as table_status;

-- If table exists, show its current structure
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default,
    ordinal_position
FROM information_schema.columns
WHERE table_name = 'running_goals'
ORDER BY ordinal_position;

-- Show any existing data (first 5 rows)
SELECT * FROM running_goals LIMIT 5;