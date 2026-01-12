-- =====================================================
-- Migration: Add Micro-Commitment Support
-- Purpose: Extend daily_commitments with micro-commitment fields
-- Date: 2026-01-12
-- =====================================================

-- Add new columns for micro-commitment support
ALTER TABLE daily_commitments
ADD COLUMN IF NOT EXISTS commitment_level VARCHAR(20) DEFAULT 'standard',
ADD COLUMN IF NOT EXISTS micro_commitment_type VARCHAR(30),
ADD COLUMN IF NOT EXISTS progression_step INTEGER DEFAULT 0;

-- Add index for querying by commitment level
CREATE INDEX IF NOT EXISTS idx_commitments_level
ON daily_commitments(athlete_id, commitment_level);

-- Add index for micro-commitment type queries
CREATE INDEX IF NOT EXISTS idx_commitments_micro_type
ON daily_commitments(athlete_id, micro_commitment_type)
WHERE micro_commitment_type IS NOT NULL;

-- =====================================================
-- Verification Queries
-- =====================================================
-- Check columns were added:
-- SELECT column_name, data_type, column_default
-- FROM information_schema.columns
-- WHERE table_name = 'daily_commitments'
-- AND column_name IN ('commitment_level', 'micro_commitment_type', 'progression_step');
