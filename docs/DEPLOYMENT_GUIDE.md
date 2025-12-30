# 🚀 Edge Functions Deployment Guide
**Status:** ✅ READY FOR DEPLOYMENT
**Date:** December 16, 2025

---

## ✅ IMPLEMENTATION COMPLETE - 100%

All 6 Edge Functions have been implemented and iOS app has been updated!

### Edge Functions Implemented:

| Function | Status | File Path | iOS Integration |
|----------|--------|-----------|-----------------|
| **chat** | ✅ Complete | `/runaway-edge/supabase/functions/chat/index.ts` | ✅ Ready |
| **journal** | ✅ Complete | `/runaway-edge/supabase/functions/journal/index.ts` | ✅ Ready |
| **oauth-callback** | ✅ Complete | `/runaway-edge/supabase/functions/oauth-callback/index.ts` | ✅ Ready |
| **sync-beta** | ✅ Complete | `/runaway-edge/supabase/functions/sync-beta/index.ts` | ✅ Ready |
| **disconnect** | ✅ Complete | `/runaway-edge/supabase/functions/disconnect/index.ts` | ✅ Fixed |
| **job-status** | ✅ Complete | `/runaway-edge/supabase/functions/job-status/index.ts` | ✅ Fixed |

### iOS App Updates:

| File | Changes | Status |
|------|---------|--------|
| **StravaService.swift** | Updated disconnect URL to `/functions/v1/disconnect` | ✅ Complete |
| **StravaService.swift** | Updated job status URLs to `/functions/v1/job-status/{id}` | ✅ Complete |
| **ChatService.swift** | Already pointing to `/functions/v1/chat` | ✅ Ready |
| **JournalService.swift** | Already pointing to `/functions/v1/journal` | ✅ Ready |

---

## 📋 PRE-DEPLOYMENT CHECKLIST

### 1. Set Supabase Secrets ⚠️ REQUIRED

```bash
cd /Users/jack.rudelic/projects/labs/runaway-edge

# Set secrets
supabase secrets set ANTHROPIC_API_KEY="your_anthropic_key_here"
supabase secrets set STRAVA_CLIENT_ID="118220"
supabase secrets set STRAVA_CLIENT_SECRET="your_strava_secret_here"

# Verify secrets are set
supabase secrets list
```

**Where to get these:**
- **ANTHROPIC_API_KEY**: https://console.anthropic.com/settings/keys
- **STRAVA_CLIENT_ID**: Already set to `118220`
- **STRAVA_CLIENT_SECRET**: https://www.strava.com/settings/api (Your Strava app settings)

---

### 2. Link Supabase Project

```bash
cd /Users/jack.rudelic/projects/labs/runaway-edge

# Link to your Supabase project
supabase link --project-ref nkxvjcdxiyjbndjvfmqy

# Verify connection
supabase projects list
```

---

### 3. Verify Database Tables Exist

Ensure these tables exist in your Supabase database:

```sql
-- Check required tables
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name IN ('athletes', 'activities', 'training_journal', 'sync_jobs');
```

**Required tables:**
- ✅ `athletes` - Stores athlete profiles and OAuth tokens
- ✅ `activities` - Stores Strava activities
- ✅ `training_journal` - Stores AI-generated training journals
- ✅ `sync_jobs` - Tracks sync job status

---

## 🚀 DEPLOYMENT STEPS

### Step 1: Deploy All Edge Functions

```bash
cd /Users/jack.rudelic/projects/labs/runaway-edge

# Deploy all functions at once
supabase functions deploy chat
supabase functions deploy journal
supabase functions deploy oauth-callback
supabase functions deploy sync-beta
supabase functions deploy disconnect
supabase functions deploy job-status

echo "✅ All Edge Functions deployed!"
```

**Expected output:**
```
Deploying chat (project ref: nkxvjcdxiyjbndjvfmqy)
✓ Deployed chat
Deploying journal (project ref: nkxvjcdxiyjbndjvfmqy)
✓ Deployed journal
...
```

---

### Step 2: Test Each Endpoint

#### Test Chat Function:
```bash
curl -X POST https://nkxvjcdxiyjbndjvfmqy.supabase.co/functions/v1/chat \
  -H "Content-Type: application/json" \
  -d '{
    "athlete_id": 94451852,
    "message": "How am I doing with my training?"
  }'
```

**Expected response:**
```json
{
  "answer": "Based on your recent activities...",
  "conversation_id": "uuid-here",
  "context": {
    "activities_count": 5,
    "athlete_name": "Your Name"
  }
}
```

#### Test Journal Generation:
```bash
curl -X POST https://nkxvjcdxiyjbndjvfmqy.supabase.co/functions/v1/journal/generate \
  -H "Content-Type: application/json" \
  -d '{
    "athlete_id": 94451852
  }'
```

**Expected response:**
```json
{
  "success": true,
  "journal": {
    "content": "This week you completed...",
    "total_distance": 25.5,
    "activity_count": 4
  }
}
```

#### Test OAuth Callback (in browser):
```bash
# Visit this URL in a browser (replace test-user-id with real auth_user_id):
open "https://www.strava.com/oauth/authorize?client_id=118220&response_type=code&redirect_uri=https://nkxvjcdxiyjbndjvfmqy.supabase.co/functions/v1/oauth-callback&approval_prompt=force&scope=activity:read_all,profile:read_all&state=test-user-id"
```

**Expected:** Beautiful HTML page with success message and deep link back to app

#### Test Sync-Beta:
```bash
curl -X POST https://nkxvjcdxiyjbndjvfmqy.supabase.co/functions/v1/sync-beta \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": 94451852,
    "sync_type": "incremental"
  }'
```

**Expected response:**
```json
{
  "job_id": "uuid-here",
  "status": "pending",
  "sync_type": "incremental",
  "user_id": 94451852,
  "max_activities": 20
}
```

#### Test Job Status:
```bash
# Use job_id from sync-beta response
curl https://nkxvjcdxiyjbndjvfmqy.supabase.co/functions/v1/job-status/YOUR_JOB_ID_HERE
```

**Expected response:**
```json
{
  "job_id": "uuid-here",
  "status": "pending",
  "progress": 0,
  "activities_processed": 0
}
```

#### Test Disconnect:
```bash
curl -X POST https://nkxvjcdxiyjbndjvfmqy.supabase.co/functions/v1/disconnect \
  -H "Content-Type: application/json" \
  -d '{
    "athlete_id": 94451852
  }'
```

**Expected response:**
```json
{
  "success": true,
  "message": "Disconnected from Strava successfully",
  "athlete_id": 94451852
}
```

---

### Step 3: Build & Test iOS App

```bash
cd "/Users/jack.rudelic/projects/labs/Runaway iOS"

# Build the app
xcodebuild -project "Runaway iOS.xcodeproj" \
  -scheme "Runaway iOS" \
  -destination "platform=iOS Simulator,name=iPhone 15" \
  build

# Or open in Xcode
open "Runaway iOS.xcworkspace"
```

**Test these features in the iOS app:**
- [ ] Chat with AI coach
- [ ] Generate training journal
- [ ] Connect Strava account (OAuth flow)
- [ ] Trigger activity sync
- [ ] Check sync job status
- [ ] Disconnect Strava account
- [ ] Verify activities appear after sync

---

## 📊 MONITORING & DEBUGGING

### View Edge Function Logs:

```bash
# View logs for specific function (real-time)
supabase functions logs chat --tail
supabase functions logs journal --tail
supabase functions logs oauth-callback --tail
supabase functions logs sync-beta --tail
supabase functions logs disconnect --tail
supabase functions logs job-status --tail

# View recent logs
supabase functions logs chat --limit 50
```

### Check Database:

```sql
-- Check recent sync jobs
SELECT * FROM sync_jobs ORDER BY created_at DESC LIMIT 10;

-- Check athletes with Strava connected
SELECT id, first_name, last_name, strava_connected, strava_connected_at
FROM athletes
WHERE strava_connected = true;

-- Check recent training journals
SELECT * FROM training_journal ORDER BY created_at DESC LIMIT 10;

-- Check recent activities
SELECT * FROM activities ORDER BY activity_date DESC LIMIT 10;
```

---

## 🐛 TROUBLESHOOTING

### Issue: "ANTHROPIC_API_KEY not set" error

**Solution:**
```bash
supabase secrets set ANTHROPIC_API_KEY="your_key_here"
supabase functions deploy chat  # Redeploy after setting secret
```

### Issue: OAuth callback fails with 500 error

**Possible causes:**
1. `STRAVA_CLIENT_SECRET` not set correctly
2. `athletes` table doesn't exist
3. Incorrect Strava app redirect URI

**Solution:**
```bash
# Verify secrets
supabase secrets list

# Check Strava app settings
open "https://www.strava.com/settings/api"
# Ensure Authorization Callback Domain includes: nkxvjcdxiyjbndjvfmqy.supabase.co
```

### Issue: Chat returns no context

**Possible causes:**
1. No activities in database for athlete
2. `activities` table missing or empty

**Solution:**
```sql
-- Check if athlete has activities
SELECT COUNT(*) FROM activities WHERE athlete_id = 94451852;

-- If zero, connect Strava and sync first
```

### Issue: iOS app can't connect to Edge Functions

**Possible causes:**
1. Edge Functions not deployed
2. iOS app still pointing to old URLs
3. CORS issue

**Solution:**
```bash
# Verify deployment
supabase functions list

# Check iOS service files have correct URLs
grep -r "functions/v1" "Runaway iOS/Services/"

# Should show:
# ChatService.swift:    private static let chatEndpoint = "/functions/v1/chat"
# JournalService.swift: private static let journalEndpoint = "/functions/v1/journal"
# StravaService.swift:  (multiple functions/v1/ references)
```

---

## ✅ POST-DEPLOYMENT CHECKLIST

After successful deployment:

- [ ] All 6 Edge Functions deployed successfully
- [ ] Chat function returns AI responses
- [ ] Journal generation works
- [ ] OAuth flow completes successfully
- [ ] Sync job creation works
- [ ] Job status polling works
- [ ] Disconnect works
- [ ] iOS app connects successfully
- [ ] No errors in Edge Function logs
- [ ] Database tables populated correctly

---

## 💰 COST SAVINGS

**Before Migration:**
- Cloud Run: ~$60/month
- Total: $60/month

**After Migration:**
- Supabase Edge Functions: $0/month (free tier)
- Total: $0/month

**Annual Savings: $720** 🎉

---

## 🎉 SUCCESS CRITERIA

Your migration is successful when:

1. ✅ All Edge Functions respond without errors
2. ✅ iOS app can chat with AI coach
3. ✅ Training journals generate successfully
4. ✅ Strava OAuth flow works end-to-end
5. ✅ Activity sync creates jobs
6. ✅ No 500 errors in logs
7. ✅ Response times < 2 seconds
8. ✅ Old Cloud Run can be deprecated

---

## 📞 NEED HELP?

**View logs in Supabase Dashboard:**
1. Go to https://supabase.com/dashboard
2. Select project: `nkxvjcdxiyjbndjvfmqy`
3. Navigate to Edge Functions → Logs
4. View real-time logs for each function

**Common issues:**
- Missing secrets → Set them with `supabase secrets set`
- CORS errors → Already handled in all functions with corsHeaders
- Database errors → Check table schemas match expected format
- Strava API errors → Verify credentials and token validity

---

**Ready to deploy?** Run the commands in Step 1 above! 🚀

**Last Updated:** December 16, 2025
**Implementation Status:** 100% Complete ✅
