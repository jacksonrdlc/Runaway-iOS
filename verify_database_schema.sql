-- Supabase Database Schema Verification Script
-- Run this in your Supabase SQL Editor to verify all required tables exist

-- =============================================================================
-- VERIFICATION SCRIPT FOR RUNAWAY iOS DATABASE SCHEMA
-- =============================================================================

DO $$
DECLARE
    table_count INTEGER;
    missing_tables TEXT[] := ARRAY[]::TEXT[];
    existing_tables TEXT[] := ARRAY[]::TEXT[];
    tbl_name TEXT;
    required_tables TEXT[] := ARRAY[
        'athletes',
        'activity_types',
        'activities',
        'brands',
        'models',
        'gear',
        'routes',
        'segments',
        'starred_routes',
        'starred_segments',
        'follows',
        'comments',
        'reactions',
        'clubs',
        'memberships',
        'challenges',
        'challenge_participations',
        'goals',
        'running_goals',
        'daily_commitments',
        'media',
        'connected_apps',
        'logins',
        'contacts'
    ];
BEGIN
    RAISE NOTICE '=== RUNAWAY IOS DATABASE VERIFICATION ===';
    RAISE NOTICE 'Timestamp: %', NOW();
    RAISE NOTICE '';

    -- Check each required table
    FOREACH tbl_name IN ARRAY required_tables
    LOOP
        SELECT COUNT(*)
        INTO table_count
        FROM information_schema.tables
        WHERE table_schema = 'public'
        AND table_name = tbl_name;

        IF table_count > 0 THEN
            existing_tables := array_append(existing_tables, tbl_name);
        ELSE
            missing_tables := array_append(missing_tables, tbl_name);
        END IF;
    END LOOP;

    -- Report results
    RAISE NOTICE '✅ EXISTING TABLES (% found):', array_length(existing_tables, 1);
    FOREACH tbl_name IN ARRAY existing_tables
    LOOP
        RAISE NOTICE '   ✓ %', tbl_name;
    END LOOP;

    IF array_length(missing_tables, 1) > 0 THEN
        RAISE NOTICE '';
        RAISE NOTICE '❌ MISSING TABLES (% missing):', array_length(missing_tables, 1);
        FOREACH tbl_name IN ARRAY missing_tables
        LOOP
            RAISE NOTICE '   ✗ %', tbl_name;
        END LOOP;
    ELSE
        RAISE NOTICE '';
        RAISE NOTICE '🎉 ALL REQUIRED TABLES FOUND!';
    END IF;
END $$;

-- =============================================================================
-- DETAILED TABLE STRUCTURE VERIFICATION
-- =============================================================================

-- Check critical columns in key tables
SELECT
    '=== ATHLETES TABLE STRUCTURE ===' as check_type,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'athletes'
ORDER BY ordinal_position;

-- Check if auth_user_id exists in athletes table
SELECT
    CASE
        WHEN COUNT(*) > 0 THEN '✅ auth_user_id column exists in athletes table'
        ELSE '❌ auth_user_id column MISSING in athletes table'
    END as auth_column_check
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'athletes'
AND column_name = 'auth_user_id';

-- Check running_goals table structure
SELECT
    '=== RUNNING_GOALS TABLE STRUCTURE ===' as check_type,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'running_goals'
ORDER BY ordinal_position;

-- Check daily_commitments table structure
SELECT
    '=== DAILY_COMMITMENTS TABLE STRUCTURE ===' as check_type,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'daily_commitments'
ORDER BY ordinal_position;

-- =============================================================================
-- FOREIGN KEY CONSTRAINTS VERIFICATION
-- =============================================================================

SELECT
    '=== FOREIGN KEY CONSTRAINTS ===' as check_type,
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
AND tc.table_schema = 'public'
AND tc.table_name IN ('athletes', 'activities', 'running_goals', 'daily_commitments')
ORDER BY tc.table_name, tc.constraint_name;

-- =============================================================================
-- ROW LEVEL SECURITY (RLS) CHECK
-- =============================================================================

SELECT
    '=== ROW LEVEL SECURITY STATUS ===' as check_type,
    schemaname,
    tablename,
    rowsecurity as rls_enabled,
    CASE
        WHEN rowsecurity THEN '✅ RLS Enabled'
        ELSE '⚠️  RLS Disabled'
    END as rls_status
FROM pg_tables
WHERE schemaname = 'public'
AND tablename IN ('athletes', 'activities', 'running_goals', 'daily_commitments')
ORDER BY tablename;

-- =============================================================================
-- INDEX VERIFICATION
-- =============================================================================

SELECT
    '=== IMPORTANT INDEXES ===' as check_type,
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
AND tablename IN ('athletes', 'activities', 'running_goals', 'daily_commitments')
AND indexname NOT LIKE '%_pkey'  -- Exclude primary key indexes
ORDER BY tablename, indexname;

-- =============================================================================
-- FINAL SUMMARY
-- =============================================================================

DO $$
DECLARE
    total_tables INTEGER;
    total_constraints INTEGER;
    total_indexes INTEGER;
BEGIN
    -- Count tables
    SELECT COUNT(*) INTO total_tables
    FROM information_schema.tables
    WHERE table_schema = 'public';

    -- Count foreign key constraints
    SELECT COUNT(*) INTO total_constraints
    FROM information_schema.table_constraints
    WHERE table_schema = 'public'
    AND constraint_type = 'FOREIGN KEY';

    -- Count indexes
    SELECT COUNT(*) INTO total_indexes
    FROM pg_indexes
    WHERE schemaname = 'public';

    RAISE NOTICE '';
    RAISE NOTICE '=== SUMMARY ===';
    RAISE NOTICE 'Total tables in public schema: %', total_tables;
    RAISE NOTICE 'Total foreign key constraints: %', total_constraints;
    RAISE NOTICE 'Total indexes: %', total_indexes;
    RAISE NOTICE '';
    RAISE NOTICE 'Verification complete! Check output above for any missing tables or issues.';
END $$;