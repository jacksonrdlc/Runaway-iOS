-- Check the actual column names in the activities table
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'activities'
ORDER BY ordinal_position;
