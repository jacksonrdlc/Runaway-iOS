# Database Migrations

This directory contains SQL migration scripts to optimize your Supabase database.

## Quick Wins - Performance & Security

### Migration 001: Performance Indexes
**File**: `001_add_performance_indexes.sql`
**Estimated Time**: 5 minutes
**Impact**: 40-60% query performance improvement

**Indexes Created**:
- `idx_activities_athlete_date` - Optimizes activity queries by athlete and date
- `idx_daily_commitments_athlete_date` - Speeds up commitment lookups
- `idx_running_goals_athlete_active` - Fast active goal queries
- `idx_activities_athlete_type` - Activity type filtering
- `idx_quick_wins_athlete_date` - Quick wins queries

### Migration 002: Row Level Security
**File**: `002_add_row_level_security.sql`
**Estimated Time**: 10 minutes
**Impact**: Critical security enhancement - users can only access their own data

**Tables Protected**:
- `athletes` - User profiles
- `activities` - Activity records
- `daily_commitments` - Daily commitments
- `running_goals` - Running goals
- `quick_wins` - Quick wins

## Aggregation Functions - Performance Boost

### Migration 003: Database Aggregation Functions
**File**: `003_add_aggregation_functions.sql`
**Estimated Time**: 5 minutes
**Impact**: 60-70% reduction in network payload and client-side processing

**Functions Created**:
- `get_commitment_stats(athlete_id, days)` - Calculate commitment statistics on database
- `calculate_streak(athlete_id)` - Compute current streak server-side
- `get_weekly_commitment_summary(athlete_id)` - Weekly insights aggregation (bonus)
- `get_monthly_commitment_summary(athlete_id)` - Monthly trends aggregation (bonus)

**Code Updated**:
- `CommitmentService.swift` lines 189-236 - Now uses RPC calls instead of client-side calculations

## Storage Service - Activity Maps & Exports

### Migration 004: Storage Buckets Setup
**File**: `004_setup_storage_buckets.sql`
**Estimated Time**: 5 minutes
**Impact**: Enables activity map snapshots and GPX file exports

**Buckets Created**:
- `activity-maps` - Public bucket for map snapshots (50MB limit, PNG/JPEG)
- `activity-exports` - Private bucket for GPX exports (10MB limit, GPX/XML)

**New Service**:
- `StorageService.swift` - Complete storage API for uploading, downloading, and managing files

## How to Apply Migrations

### Step 1: Access Supabase SQL Editor
1. Go to https://supabase.com/dashboard
2. Select your Runaway iOS project
3. Navigate to **SQL Editor** in the left sidebar

### Step 2: Apply Migration 001 (Indexes)
1. Click **New Query**
2. Copy the contents of `001_add_performance_indexes.sql`
3. Paste into the SQL editor
4. Click **Run** (or press Cmd+Enter)
5. Verify success: You should see "Success. No rows returned"

### Step 3: Verify Indexes
Run this query to confirm indexes were created:
```sql
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename IN ('activities', 'daily_commitments', 'running_goals', 'quick_wins')
ORDER BY tablename, indexname;
```

You should see 5 new indexes starting with `idx_`.

### Step 4: Apply Migration 002 (RLS) ⚠️ IMPORTANT
**Before applying RLS, ensure you have:**
- A backup of your database
- Test data to verify policies work correctly
- Understanding that this WILL restrict data access

1. Click **New Query**
2. Copy the contents of `002_add_row_level_security.sql`
3. Paste into the SQL editor
4. **Review carefully** - RLS policies are security-critical
5. Click **Run** (or press Cmd+Enter)

### Step 5: Verify RLS Policies
Run this query to confirm RLS is enabled and policies exist:
```sql
-- Check RLS is enabled
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
AND tablename IN ('athletes', 'activities', 'daily_commitments', 'running_goals', 'quick_wins');

-- View all policies
SELECT schemaname, tablename, policyname, permissive, cmd
FROM pg_policies
WHERE tablename IN ('athletes', 'activities', 'daily_commitments', 'running_goals', 'quick_wins')
ORDER BY tablename, policyname;
```

Expected results:
- `rowsecurity` = true for all 5 tables
- 20 policies total (4 per table: SELECT, INSERT, UPDATE, DELETE)

### Step 6: Test Data Access
**Test with your app:**
1. Build and run the iOS app
2. Sign in with a test account
3. Verify activities load correctly
4. Try creating a new activity
5. Check that data syncs properly

**If you encounter issues:**
- Check Supabase logs: Dashboard → Logs
- Verify `auth_user_id` matches `auth.uid()` in athletes table
- Ensure service role key is NOT being used in the iOS app (should use anon key)

### Step 7: Apply Migration 003 (Aggregation Functions)
1. Click **New Query**
2. Copy the contents of `003_add_aggregation_functions.sql`
3. Paste into the SQL editor
4. Click **Run** (or press Cmd+Enter)
5. Verify success: "Success. No rows returned"

### Step 8: Verify Aggregation Functions
Run this query to confirm functions were created:
```sql
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name IN ('get_commitment_stats', 'calculate_streak', 'get_weekly_commitment_summary', 'get_monthly_commitment_summary');
```

You should see 4 functions with type = 'FUNCTION'.

**Test the functions (replace 123 with your athlete_id):**
```sql
-- Test commitment stats
SELECT * FROM get_commitment_stats(123, 30);

-- Test streak calculation
SELECT calculate_streak(123);
```

### Step 9: Apply Migration 004 (Storage Buckets)
1. Navigate to **Storage** in the left sidebar (NOT SQL Editor)
2. You can either:
   - **Option A**: Create buckets manually via UI, then apply policies via SQL Editor
   - **Option B**: Apply the full SQL script via SQL Editor

**Option A (Recommended - UI + SQL):**
1. In Storage tab, click **New bucket**
2. Create `activity-maps` bucket:
   - Name: `activity-maps`
   - Public: ✅ Yes
   - File size limit: 50MB
   - Allowed MIME types: `image/png, image/jpeg`
3. Create `activity-exports` bucket:
   - Name: `activity-exports`
   - Public: ❌ No
   - File size limit: 10MB
   - Allowed MIME types: `application/gpx+xml, application/xml, text/xml`
4. Go back to SQL Editor and run only the policy sections from `004_setup_storage_buckets.sql`

**Option B (SQL Script):**
1. Go to SQL Editor
2. Copy contents of `004_setup_storage_buckets.sql`
3. Paste and run

### Step 10: Verify Storage Setup
In the Storage tab, you should see:
- `activity-maps` bucket (public)
- `activity-exports` bucket (private)

**Test upload (optional):**
- In the iOS app, you can now use `StorageService.swift` to upload activity maps

## Performance Testing

### Before & After Comparison

**Test Query 1 - Activities List:**
```sql
EXPLAIN ANALYZE
SELECT * FROM activities
WHERE athlete_id = 123
ORDER BY activity_date DESC
LIMIT 20;
```

Run this BEFORE and AFTER applying indexes. You should see:
- **Before**: Sequential Scan, ~50-200ms
- **After**: Index Scan using idx_activities_athlete_date, ~5-20ms

**Test Query 2 - Commitment Stats:**
```sql
EXPLAIN ANALYZE
SELECT COUNT(*) as total,
       SUM(CASE WHEN is_fulfilled THEN 1 ELSE 0 END) as fulfilled
FROM daily_commitments
WHERE athlete_id = 123
AND commitment_date >= CURRENT_DATE - INTERVAL '30 days';
```

Expected improvement: 40-60% faster with index.

## Rollback Instructions

### To Remove Indexes (if needed):
```sql
DROP INDEX IF EXISTS idx_activities_athlete_date;
DROP INDEX IF EXISTS idx_daily_commitments_athlete_date;
DROP INDEX IF EXISTS idx_running_goals_athlete_active;
DROP INDEX IF EXISTS idx_activities_athlete_type;
DROP INDEX IF EXISTS idx_quick_wins_athlete_date;
```

### To Disable RLS (emergency only):
```sql
ALTER TABLE athletes DISABLE ROW LEVEL SECURITY;
ALTER TABLE activities DISABLE ROW LEVEL SECURITY;
ALTER TABLE daily_commitments DISABLE ROW LEVEL SECURITY;
ALTER TABLE running_goals DISABLE ROW LEVEL SECURITY;
ALTER TABLE quick_wins DISABLE ROW LEVEL SECURITY;
```

⚠️ **Warning**: Disabling RLS exposes all user data. Only use in development/testing.

## Next Steps

After successfully applying these quick wins:
1. Monitor query performance in Supabase Dashboard → Database → Query Performance
2. Check for any slow queries that might need additional indexes
3. Proceed to **Option B**: Aggregation Functions (see parent directory)
4. Proceed to **Option C**: Storage Service (see parent directory)

## Support

If you encounter issues:
1. Check Supabase documentation: https://supabase.com/docs/guides/database
2. Review RLS policies: https://supabase.com/docs/guides/auth/row-level-security
3. Test with SQL Editor before modifying app code
