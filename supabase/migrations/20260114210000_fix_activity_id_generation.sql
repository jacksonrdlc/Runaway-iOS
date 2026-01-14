-- =====================================================
-- Migration: Fix Activity ID Generation
-- Purpose: Add a sequence for generating activity IDs
--          for manually recorded activities (non-Strava)
-- Date: 2026-01-14
-- =====================================================

-- Create a sequence starting at 2 billion to avoid conflicts with Strava activity IDs
-- (Strava IDs are typically 10-13 digit positive numbers)
CREATE SEQUENCE IF NOT EXISTS activities_id_seq
    START WITH 2000000001
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

-- Set the sequence as the default for the id column
-- Using COALESCE to allow explicit IDs (for Strava imports) while
-- defaulting to the sequence for manual activities
ALTER TABLE public.activities
    ALTER COLUMN id SET DEFAULT nextval('activities_id_seq');

-- Note: Existing activities with negative IDs from manual recording
-- can be left as-is or cleaned up separately. New manual activities
-- will get positive IDs from the sequence.
