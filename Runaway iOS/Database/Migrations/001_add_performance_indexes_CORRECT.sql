-- =====================================================
-- Migration: Add Performance Indexes (CORRECT VERSION)
-- Purpose: Optimize query performance for common access patterns
-- Date: 2025-11-26
-- =====================================================

-- Index for activities queries by athlete and date (most common query pattern)
-- Used in: ActivityService.swift fetchActivities(), DataManager.swift refreshActivities()
CREATE INDEX IF NOT EXISTS idx_activities_athlete_date
ON activities(athlete_id, activity_date DESC);

-- Index for commitment queries by athlete and date
-- Used in: CommitmentService.swift fetchCommitments(), getCommitmentStats()
CREATE INDEX IF NOT EXISTS idx_daily_commitments_athlete_date
ON daily_commitments(athlete_id, commitment_date DESC);

-- Index for active running goals lookup
-- Used in: GoalService queries, RunningGoalComponents.swift
CREATE INDEX IF NOT EXISTS idx_running_goals_athlete_active
ON running_goals(athlete_id, is_active)
WHERE is_active = true;

-- Index for activity type filtering (using activity_type_id)
-- Used in: EnhancedAnalysisService.swift, AnalysisView.swift
CREATE INDEX IF NOT EXISTS idx_activities_athlete_type
ON activities(athlete_id, activity_type_id);

-- Index for quick wins queries
-- Used in: QuickWinsService.swift
CREATE INDEX IF NOT EXISTS idx_quick_wins_athlete_date
ON quick_wins(athlete_id, created_at DESC);

-- =====================================================
-- Verification Queries
-- =====================================================
-- Run these to verify indexes were created:
-- SELECT indexname, indexdef FROM pg_indexes WHERE tablename IN ('activities', 'daily_commitments', 'running_goals', 'quick_wins') ORDER BY tablename, indexname;
