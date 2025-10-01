-- Test script to manually create a goal and see what the iOS app should be sending
-- This helps debug the start_date vs deadline issue

-- First, let's see what the current running_goals table looks like
SELECT 'Current running_goals table structure:' as info;

\d running_goals

-- Manual test insert that matches what iOS should be sending
-- This should work if the table structure is correct
INSERT INTO running_goals (
    athlete_id,
    title,
    goal_type,
    target_value,
    deadline,
    is_active,
    is_completed,
    current_progress,
    created_at,
    updated_at
) VALUES (
    1, -- Replace with a valid athlete_id from your athletes table
    'Test Goal from SQL',
    'distance',
    5.0,
    NOW() + INTERVAL '30 days',
    true,
    false,
    0.0,
    NOW(),
    NOW()
);

-- Check if the insert worked
SELECT 'Test goal created successfully:' as result;
SELECT * FROM running_goals WHERE title = 'Test Goal from SQL';

-- Clean up the test
DELETE FROM running_goals WHERE title = 'Test Goal from SQL';