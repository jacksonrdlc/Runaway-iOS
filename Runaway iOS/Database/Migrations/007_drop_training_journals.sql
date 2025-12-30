-- Migration: Drop Training Journals Table
-- Description: Remove deprecated training_journals table (replaced by weekly_training_plans)
-- Run this in your Supabase SQL Editor

-- Drop the training_journals table if it exists
DROP TABLE IF EXISTS training_journals CASCADE;

-- Also drop the journal API views if they exist
DROP VIEW IF EXISTS journal_weekly_summary CASCADE;

-- Note: The training journal feature has been replaced with weekly training plans
-- The new feature generates forward-looking training plans instead of retrospective summaries
