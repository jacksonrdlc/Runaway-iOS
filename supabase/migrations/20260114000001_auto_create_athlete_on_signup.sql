-- =====================================================
-- Migration: Auto-create Athlete on User Signup
-- Purpose: Automatically create athlete record when
--          a new user signs up via Supabase Auth
-- Date: 2026-01-14
-- =====================================================

-- =====================================================
-- Function: Create athlete profile for new auth user
-- =====================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    new_athlete_id INTEGER;
BEGIN
    -- Insert new athlete record
    INSERT INTO public.athletes (
        auth_user_id,
        email,
        first_name,
        last_name,
        strava_connected,
        created_at,
        updated_at
    ) VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'first_name', split_part(NEW.email, '@', 1)),
        NEW.raw_user_meta_data->>'last_name',
        FALSE,
        NOW(),
        NOW()
    )
    RETURNING id INTO new_athlete_id;

    -- Initialize athlete stats with zeros
    INSERT INTO public.athlete_stats (
        athlete_id,
        count,
        distance,
        moving_time,
        elapsed_time,
        elevation_gain,
        achievement_count,
        ytd_distance
    ) VALUES (
        new_athlete_id,
        0,
        0,
        0,
        0,
        0,
        0,
        0
    );

    -- Initialize onboarding record
    INSERT INTO public.athlete_onboarding (
        athlete_id,
        is_completed,
        current_step,
        created_at,
        updated_at
    ) VALUES (
        new_athlete_id,
        FALSE,
        0,
        NOW(),
        NOW()
    );

    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        -- Log error but don't fail the signup
        RAISE WARNING 'Failed to create athlete for user %: %', NEW.id, SQLERRM;
        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- Trigger: Run after new user is created in auth.users
-- =====================================================
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- =====================================================
-- Function: Ensure athlete exists for user (fallback)
-- Called from client if trigger didn't fire
-- =====================================================
CREATE OR REPLACE FUNCTION public.ensure_athlete_exists(p_auth_user_id UUID, p_email TEXT DEFAULT NULL)
RETURNS INTEGER AS $$
DECLARE
    v_athlete_id INTEGER;
BEGIN
    -- Check if athlete already exists
    SELECT id INTO v_athlete_id
    FROM public.athletes
    WHERE auth_user_id = p_auth_user_id;

    -- If exists, return the ID
    IF v_athlete_id IS NOT NULL THEN
        RETURN v_athlete_id;
    END IF;

    -- Create new athlete
    INSERT INTO public.athletes (
        auth_user_id,
        email,
        first_name,
        strava_connected,
        created_at,
        updated_at
    ) VALUES (
        p_auth_user_id,
        p_email,
        COALESCE(split_part(p_email, '@', 1), 'Runner'),
        FALSE,
        NOW(),
        NOW()
    )
    RETURNING id INTO v_athlete_id;

    -- Initialize stats
    INSERT INTO public.athlete_stats (
        athlete_id,
        count,
        distance,
        moving_time,
        elapsed_time,
        elevation_gain,
        achievement_count,
        ytd_distance
    ) VALUES (
        v_athlete_id,
        0, 0, 0, 0, 0, 0, 0
    );

    -- Initialize onboarding
    INSERT INTO public.athlete_onboarding (
        athlete_id,
        is_completed,
        current_step,
        created_at,
        updated_at
    ) VALUES (
        v_athlete_id,
        FALSE,
        0,
        NOW(),
        NOW()
    );

    RETURN v_athlete_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- Grant execute permission on the function
-- =====================================================
GRANT EXECUTE ON FUNCTION public.ensure_athlete_exists(UUID, TEXT) TO authenticated;

-- =====================================================
-- Verification Queries
-- =====================================================
-- Test the function:
-- SELECT ensure_athlete_exists('your-auth-user-uuid', 'test@example.com');
--
-- Check trigger exists:
-- SELECT * FROM pg_trigger WHERE tgname = 'on_auth_user_created';
--
-- Check function exists:
-- SELECT proname FROM pg_proc WHERE proname = 'handle_new_user';
