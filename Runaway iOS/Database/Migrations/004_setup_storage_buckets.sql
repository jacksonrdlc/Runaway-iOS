-- =====================================================
-- Migration: Setup Storage Buckets
-- Purpose: Create Supabase Storage buckets for activity maps and exports
-- Date: 2025-11-26
-- =====================================================

-- =====================================================
-- 1. CREATE STORAGE BUCKETS
-- =====================================================

-- Create bucket for activity map snapshots (public)
INSERT INTO storage.buckets (id, name, public)
VALUES ('activity-maps', 'activity-maps', true)
ON CONFLICT (id) DO NOTHING;

-- Create bucket for activity GPX exports (private)
INSERT INTO storage.buckets (id, name, public)
VALUES ('activity-exports', 'activity-exports', false)
ON CONFLICT (id) DO NOTHING;

-- =====================================================
-- 2. STORAGE POLICIES - ACTIVITY MAPS (PUBLIC)
-- =====================================================

-- Policy: Users can upload their own activity maps
CREATE POLICY "Users can upload own activity maps"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'activity-maps'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy: Anyone can view activity maps (public bucket)
CREATE POLICY "Activity maps are publicly accessible"
ON storage.objects FOR SELECT
USING (bucket_id = 'activity-maps');

-- Policy: Users can update their own activity maps
CREATE POLICY "Users can update own activity maps"
ON storage.objects FOR UPDATE
USING (
    bucket_id = 'activity-maps'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy: Users can delete their own activity maps
CREATE POLICY "Users can delete own activity maps"
ON storage.objects FOR DELETE
USING (
    bucket_id = 'activity-maps'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- =====================================================
-- 3. STORAGE POLICIES - ACTIVITY EXPORTS (PRIVATE)
-- =====================================================

-- Policy: Users can upload their own GPX exports
CREATE POLICY "Users can upload own GPX exports"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'activity-exports'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy: Users can only view their own GPX exports
CREATE POLICY "Users can view own GPX exports"
ON storage.objects FOR SELECT
USING (
    bucket_id = 'activity-exports'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy: Users can update their own GPX exports
CREATE POLICY "Users can update own GPX exports"
ON storage.objects FOR UPDATE
USING (
    bucket_id = 'activity-exports'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy: Users can delete their own GPX exports
CREATE POLICY "Users can delete own GPX exports"
ON storage.objects FOR DELETE
USING (
    bucket_id = 'activity-exports'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- =====================================================
-- 4. BUCKET CONFIGURATION
-- =====================================================

-- Set file size limits (50MB for maps, 10MB for GPX files)
UPDATE storage.buckets
SET file_size_limit = 52428800  -- 50MB
WHERE id = 'activity-maps';

UPDATE storage.buckets
SET file_size_limit = 10485760  -- 10MB
WHERE id = 'activity-exports';

-- Set allowed MIME types
UPDATE storage.buckets
SET allowed_mime_types = ARRAY['image/png', 'image/jpeg']
WHERE id = 'activity-maps';

UPDATE storage.buckets
SET allowed_mime_types = ARRAY['application/gpx+xml', 'application/xml', 'text/xml']
WHERE id = 'activity-exports';

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================

-- Verify buckets were created:
-- SELECT id, name, public, file_size_limit, allowed_mime_types
-- FROM storage.buckets
-- WHERE id IN ('activity-maps', 'activity-exports');

-- Verify policies were created:
-- SELECT policyname, cmd, qual
-- FROM pg_policies
-- WHERE schemaname = 'storage'
-- AND tablename = 'objects'
-- AND policyname LIKE '%activity%'
-- ORDER BY policyname;

-- =====================================================
-- CLEANUP (if needed)
-- =====================================================

-- To remove buckets and policies (WARNING: deletes all files):
-- DELETE FROM storage.objects WHERE bucket_id IN ('activity-maps', 'activity-exports');
-- DELETE FROM storage.buckets WHERE id IN ('activity-maps', 'activity-exports');
