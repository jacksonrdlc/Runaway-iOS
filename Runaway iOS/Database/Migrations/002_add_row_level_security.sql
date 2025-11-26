-- =====================================================
-- Migration: Add Row Level Security (RLS) Policies
-- Purpose: Secure data access - users can only access their own data
-- Date: 2025-11-26
-- IMPORTANT: Review and test thoroughly before applying to production
-- =====================================================

-- =====================================================
-- 1. ATHLETES TABLE
-- =====================================================
-- Enable RLS on athletes table
ALTER TABLE athletes ENABLE ROW LEVEL SECURITY;

-- Policy: Users can read their own athlete profile
CREATE POLICY "Users can read own athlete profile"
ON athletes FOR SELECT
USING (auth_user_id = auth.uid());

-- Policy: Users can update their own athlete profile
CREATE POLICY "Users can update own athlete profile"
ON athletes FOR UPDATE
USING (auth_user_id = auth.uid());

-- Policy: Users can insert their own athlete profile
CREATE POLICY "Users can insert own athlete profile"
ON athletes FOR INSERT
WITH CHECK (auth_user_id = auth.uid());

-- =====================================================
-- 2. ACTIVITIES TABLE
-- =====================================================
-- Enable RLS on activities table
ALTER TABLE activities ENABLE ROW LEVEL SECURITY;

-- Policy: Users can read their own activities
CREATE POLICY "Users can read own activities"
ON activities FOR SELECT
USING (
  athlete_id IN (
    SELECT id FROM athletes WHERE auth_user_id = auth.uid()
  )
);

-- Policy: Users can insert their own activities
CREATE POLICY "Users can insert own activities"
ON activities FOR INSERT
WITH CHECK (
  athlete_id IN (
    SELECT id FROM athletes WHERE auth_user_id = auth.uid()
  )
);

-- Policy: Users can update their own activities
CREATE POLICY "Users can update own activities"
ON activities FOR UPDATE
USING (
  athlete_id IN (
    SELECT id FROM athletes WHERE auth_user_id = auth.uid()
  )
);

-- Policy: Users can delete their own activities
CREATE POLICY "Users can delete own activities"
ON activities FOR DELETE
USING (
  athlete_id IN (
    SELECT id FROM athletes WHERE auth_user_id = auth.uid()
  )
);

-- =====================================================
-- 3. DAILY_COMMITMENTS TABLE
-- =====================================================
-- Enable RLS on daily_commitments table
ALTER TABLE daily_commitments ENABLE ROW LEVEL SECURITY;

-- Policy: Users can read their own commitments
CREATE POLICY "Users can read own commitments"
ON daily_commitments FOR SELECT
USING (
  athlete_id IN (
    SELECT id FROM athletes WHERE auth_user_id = auth.uid()
  )
);

-- Policy: Users can insert their own commitments
CREATE POLICY "Users can insert own commitments"
ON daily_commitments FOR INSERT
WITH CHECK (
  athlete_id IN (
    SELECT id FROM athletes WHERE auth_user_id = auth.uid()
  )
);

-- Policy: Users can update their own commitments
CREATE POLICY "Users can update own commitments"
ON daily_commitments FOR UPDATE
USING (
  athlete_id IN (
    SELECT id FROM athletes WHERE auth_user_id = auth.uid()
  )
);

-- Policy: Users can delete their own commitments
CREATE POLICY "Users can delete own commitments"
ON daily_commitments FOR DELETE
USING (
  athlete_id IN (
    SELECT id FROM athletes WHERE auth_user_id = auth.uid()
  )
);

-- =====================================================
-- 4. RUNNING_GOALS TABLE
-- =====================================================
-- Enable RLS on running_goals table
ALTER TABLE running_goals ENABLE ROW LEVEL SECURITY;

-- Policy: Users can read their own goals
CREATE POLICY "Users can read own goals"
ON running_goals FOR SELECT
USING (
  athlete_id IN (
    SELECT id FROM athletes WHERE auth_user_id = auth.uid()
  )
);

-- Policy: Users can insert their own goals
CREATE POLICY "Users can insert own goals"
ON running_goals FOR INSERT
WITH CHECK (
  athlete_id IN (
    SELECT id FROM athletes WHERE auth_user_id = auth.uid()
  )
);

-- Policy: Users can update their own goals
CREATE POLICY "Users can update own goals"
ON running_goals FOR UPDATE
USING (
  athlete_id IN (
    SELECT id FROM athletes WHERE auth_user_id = auth.uid()
  )
);

-- Policy: Users can delete their own goals
CREATE POLICY "Users can delete own goals"
ON running_goals FOR DELETE
USING (
  athlete_id IN (
    SELECT id FROM athletes WHERE auth_user_id = auth.uid()
  )
);

-- =====================================================
-- 5. QUICK_WINS TABLE
-- =====================================================
-- Enable RLS on quick_wins table
ALTER TABLE quick_wins ENABLE ROW LEVEL SECURITY;

-- Policy: Users can read their own quick wins
CREATE POLICY "Users can read own quick wins"
ON quick_wins FOR SELECT
USING (
  athlete_id IN (
    SELECT id FROM athletes WHERE auth_user_id = auth.uid()
  )
);

-- Policy: Users can insert their own quick wins
CREATE POLICY "Users can insert own quick wins"
ON quick_wins FOR INSERT
WITH CHECK (
  athlete_id IN (
    SELECT id FROM athletes WHERE auth_user_id = auth.uid()
  )
);

-- Policy: Users can update their own quick wins
CREATE POLICY "Users can update own quick wins"
ON quick_wins FOR UPDATE
USING (
  athlete_id IN (
    SELECT id FROM athletes WHERE auth_user_id = auth.uid()
  )
);

-- Policy: Users can delete their own quick wins
CREATE POLICY "Users can delete own quick wins"
ON quick_wins FOR DELETE
USING (
  athlete_id IN (
    SELECT id FROM athletes WHERE auth_user_id = auth.uid()
  )
);

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================
-- Run these to verify RLS policies were created:
-- SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
-- FROM pg_policies
-- WHERE tablename IN ('athletes', 'activities', 'daily_commitments', 'running_goals', 'quick_wins')
-- ORDER BY tablename, policyname;

-- Test that RLS is enabled:
-- SELECT tablename, rowsecurity
-- FROM pg_tables
-- WHERE schemaname = 'public'
-- AND tablename IN ('athletes', 'activities', 'daily_commitments', 'running_goals', 'quick_wins');
