# Supabase Migrations - Testing Checklist

Follow this checklist step-by-step to apply and test all database migrations.

---

## ✅ **Task 1: Apply Migration 001 - Performance Indexes**

### Steps:
1. Go to https://supabase.com/dashboard
2. Select your **Runaway iOS** project
3. Click **SQL Editor** in the left sidebar
4. Click **New Query** button
5. Open `001_add_performance_indexes.sql` from this directory
6. Copy ALL the SQL content
7. Paste into Supabase SQL Editor
8. Click **Run** button (or press Cmd+Enter)
9. Wait for "Success. No rows returned" message

### ⚠️ Expected Result:
- Success message (no errors)
- 5 indexes created

---

## ✅ **Task 2: Verify Indexes Were Created**

### Steps:
1. In Supabase SQL Editor, click **New Query**
2. Paste this verification query:
```sql
SELECT indexname, tablename
FROM pg_indexes
WHERE tablename IN ('activities', 'daily_commitments', 'running_goals', 'quick_wins')
AND indexname LIKE 'idx_%'
ORDER BY tablename, indexname;
```
3. Click **Run**
4. You should see **5 rows** with these indexes:
   - `idx_activities_athlete_date`
   - `idx_activities_athlete_type`
   - `idx_daily_commitments_athlete_date`
   - `idx_quick_wins_athlete_date`
   - `idx_running_goals_athlete_active`

### ⚠️ If you don't see all 5 indexes:
- Re-run migration 001
- Check for error messages in the SQL Editor

---

## ✅ **Task 3: Apply Migration 002 - Row Level Security**

### ⚠️ IMPORTANT - READ BEFORE RUNNING:
This migration will **restrict data access**. Make sure:
- You have a backup of your database (Supabase auto-backups, but verify)
- You understand that users will only see their own data after this
- Your `athletes` table has `auth_user_id` column populated correctly

### Steps:
1. Click **New Query** in SQL Editor
2. Open `002_add_row_level_security.sql`
3. Copy ALL the SQL content
4. Paste into Supabase SQL Editor
5. **REVIEW the SQL carefully** - this is critical for security
6. Click **Run** button
7. Wait for "Success" message

### ⚠️ Expected Result:
- Success message
- 20 policies created (4 per table × 5 tables)

---

## ✅ **Task 4: Verify RLS Policies and Test Data Access**

### Part A - Verify RLS is Enabled:
```sql
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
AND tablename IN ('athletes', 'activities', 'daily_commitments', 'running_goals', 'quick_wins');
```

**Expected:** All 5 tables should show `rowsecurity = true`

### Part B - Verify Policies Exist:
```sql
SELECT tablename, policyname, cmd
FROM pg_policies
WHERE tablename IN ('athletes', 'activities', 'daily_commitments', 'running_goals', 'quick_wins')
ORDER BY tablename, policyname;
```

**Expected:** 20 policies total (SELECT, INSERT, UPDATE, DELETE for each table)

### Part C - Test Data Access (CRITICAL):
1. Open your iOS app
2. Sign in with a test account
3. Navigate to Activities view
4. **Verify activities load correctly**
5. Try to create a new activity
6. **Verify it saves successfully**

### ⚠️ If activities don't load or you get auth errors:
1. Check Supabase Logs: Dashboard → Logs → Database
2. Verify `athletes.auth_user_id` matches the UUID from `auth.users` table
3. Make sure your app is using the **anon key** (NOT service role key)
4. Check that `auth.uid()` returns the correct user ID:
```sql
SELECT auth.uid();
```

---

## ✅ **Task 5: Apply Migration 003 - Aggregation Functions**

### Steps:
1. Click **New Query** in SQL Editor
2. Open `003_add_aggregation_functions.sql`
3. Copy ALL the SQL content
4. Paste into Supabase SQL Editor
5. Click **Run**
6. Wait for "Success" message

### ⚠️ Expected Result:
- Success message
- 4 functions created

---

## ✅ **Task 6: Test Aggregation Functions**

### Find Your Athlete ID First:
```sql
-- Get your athlete ID (you'll need this for testing)
SELECT id, first_name, last_name, auth_user_id
FROM athletes
WHERE auth_user_id = auth.uid();
```

**Write down your `id` number** (e.g., 123)

### Test Each Function:

**Test 1 - Commitment Stats:**
```sql
-- Replace 123 with your athlete_id
SELECT * FROM get_commitment_stats(123, 30);
```

**Expected Output:**
```
total_commitments | fulfilled_commitments | fulfillment_rate | current_streak
------------------|----------------------|------------------|---------------
5                 | 3                    | 0.6000           | 2
```

**Test 2 - Current Streak:**
```sql
-- Replace 123 with your athlete_id
SELECT calculate_streak(123);
```

**Expected Output:** A number (e.g., `2`)

**Test 3 - Weekly Summary (Bonus):**
```sql
-- Replace 123 with your athlete_id
SELECT * FROM get_weekly_commitment_summary(123);
```

**Test 4 - Monthly Summary (Bonus):**
```sql
-- Replace 123 with your athlete_id
SELECT * FROM get_monthly_commitment_summary(123);
```

### ⚠️ If functions return errors:
- Verify your athlete_id is correct
- Check that you have commitment data in `daily_commitments` table
- Re-run migration 003

---

## ✅ **Task 7: Apply Migration 004 - Storage Buckets**

### Option A - Via SQL (Recommended):
1. Click **New Query** in SQL Editor
2. Open `004_setup_storage_buckets.sql`
3. Copy ALL the SQL content
4. Paste into Supabase SQL Editor
5. Click **Run**
6. Wait for "Success" message

### Option B - Via Supabase UI:
1. Click **Storage** in left sidebar (NOT SQL Editor)
2. Click **New bucket**
3. Create first bucket:
   - Name: `activity-maps`
   - Public: ✅ Yes
   - File size limit: 52428800 (50MB in bytes)
   - Allowed MIME types: `image/png, image/jpeg`
4. Click **Create bucket**
5. Repeat for second bucket:
   - Name: `activity-exports`
   - Public: ❌ No
   - File size limit: 10485760 (10MB in bytes)
   - Allowed MIME types: `application/gpx+xml, application/xml, text/xml`
6. Then go to SQL Editor and run ONLY the policy sections from `004_setup_storage_buckets.sql`

---

## ✅ **Task 8: Verify Storage Buckets**

### Part A - Check Buckets Exist:
1. Go to **Storage** in Supabase dashboard
2. You should see 2 buckets:
   - `activity-maps` (public)
   - `activity-exports` (private)

### Part B - Verify via SQL:
```sql
SELECT id, name, public, file_size_limit, allowed_mime_types
FROM storage.buckets
WHERE id IN ('activity-maps', 'activity-exports');
```

**Expected:**
- 2 rows returned
- `activity-maps`: public = true, size = 52428800
- `activity-exports`: public = false, size = 10485760

### Part C - Verify Policies:
```sql
SELECT policyname, cmd
FROM pg_policies
WHERE schemaname = 'storage'
AND tablename = 'objects'
AND policyname LIKE '%activity%'
ORDER BY policyname;
```

**Expected:** 8 policies (4 for maps, 4 for exports)

---

## ✅ **Task 9: Build and Run iOS App**

### Steps:
1. Open Xcode
2. Select your device/simulator
3. Press **Cmd+B** to build
4. Verify **Build Succeeded** message
5. Press **Cmd+R** to run the app
6. App should launch without crashes

### ⚠️ If build fails:
- Check error messages in Xcode
- All code changes are already implemented, so this should succeed
- Previous builds showed exit code 0 (success)

---

## ✅ **Task 10: Test Commitment Stats in App**

### Navigate to Commitment Features:
1. Sign in to the app
2. Go to any view that shows commitment stats
3. Look for streak counts, fulfillment rates, etc.

### What Should Happen:
- ✅ Stats load successfully
- ✅ No error messages
- ✅ Data displays correctly
- ✅ Performance should feel faster (60-70% improvement)

### Debug if Stats Don't Load:
1. Check Xcode console for errors
2. Look for any RPC call failures
3. Verify migration 003 was applied correctly
4. Test the RPC functions directly in Supabase (Task 6)

---

## 🎯 **BONUS: Test Storage Service (Optional)**

You can now use the new `StorageService.swift` to upload activity maps:

```swift
// Example usage (add to any activity detail view):
import UIKit

// Upload a map snapshot
if let mapImage = activityMapView.snapshot(), // Your map view
   let imageData = StorageService.imageToData(mapImage),
   let userId = await APIConfiguration.RunawayCoach.getCurrentAuthUserId() {

    do {
        let url = try await StorageService.uploadActivityMap(
            userId: userId,
            activityId: activity.id,
            imageData: imageData
        )
        print("✅ Map uploaded: \(url)")
    } catch {
        print("❌ Upload failed: \(error)")
    }
}
```

---

## 📊 **Performance Testing (Optional)**

### Test Query Speed Before/After Indexes:

**Activity Query:**
```sql
EXPLAIN ANALYZE
SELECT * FROM activities
WHERE athlete_id = 123  -- Replace with your athlete_id
ORDER BY activity_date DESC
LIMIT 20;
```

**Look for:**
- Index Scan using `idx_activities_athlete_date` (good!)
- Execution time should be < 20ms (fast!)

**Commitment Query:**
```sql
EXPLAIN ANALYZE
SELECT COUNT(*) as total,
       SUM(CASE WHEN is_fulfilled THEN 1 ELSE 0 END) as fulfilled
FROM daily_commitments
WHERE athlete_id = 123  -- Replace with your athlete_id
AND commitment_date >= CURRENT_DATE - INTERVAL '30 days';
```

**Look for:**
- Index Scan using `idx_daily_commitments_athlete_date`
- Execution time should be < 15ms

---

## 🆘 **Troubleshooting Guide**

### Issue: RLS Policies Block All Access
**Solution:**
```sql
-- Temporarily disable RLS for testing (development only!)
ALTER TABLE activities DISABLE ROW LEVEL SECURITY;

-- Re-enable after fixing auth_user_id:
ALTER TABLE activities ENABLE ROW LEVEL SECURITY;
```

### Issue: Functions Not Found
**Solution:**
- Re-run migration 003
- Check function exists:
```sql
SELECT routine_name FROM information_schema.routines
WHERE routine_name = 'get_commitment_stats';
```

### Issue: Storage Upload Fails
**Solution:**
- Verify buckets exist (Task 8)
- Check storage policies were created
- Ensure user is authenticated
- Verify file size is under limit

---

## ✅ **Completion Checklist**

Mark each when done:

- [ ] Migration 001 applied and verified (5 indexes)
- [ ] Migration 002 applied and verified (20 policies)
- [ ] RLS tested - app still loads data correctly
- [ ] Migration 003 applied and verified (4 functions)
- [ ] Aggregation functions tested with your athlete_id
- [ ] Migration 004 applied and verified (2 buckets)
- [ ] Storage policies verified (8 policies)
- [ ] iOS app builds successfully
- [ ] iOS app runs without crashes
- [ ] Commitment stats load correctly in app
- [ ] Performance improvement observed

---

## 🎉 **Success Criteria**

You're done when:
1. All 4 migrations are applied in Supabase
2. All verification queries return expected results
3. iOS app builds and runs without errors
4. Commitment stats load faster in the app
5. RLS policies protect user data (users only see their own activities)

---

## 📞 **Need Help?**

If you encounter issues:
1. Check Supabase Logs: Dashboard → Logs → Database
2. Review migration files for comments and troubleshooting tips
3. Test RPC functions directly in SQL Editor before testing in app
4. Verify `auth_user_id` is correctly set in `athletes` table
