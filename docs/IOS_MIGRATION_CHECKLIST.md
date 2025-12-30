# iOS App Migration to Supabase Edge Functions - Checklist

## ✅ Completed Changes

### Updated Service Files
Three service files have been updated to point to Supabase Edge Functions:

**1. ChatService.swift** ✅
- **OLD**: `https://strava-sync-a2xd4ppmsq-uc.a.run.app/api/chat`
- **NEW**: `https://YOUR-PROJECT-REF.supabase.co/functions/v1/chat`
- **DEBUG**: `http://localhost:54321/functions/v1/chat`

**2. JournalService.swift** ✅
- **OLD**: `https://strava-sync-203308554831.us-central1.run.app/api/journal`
- **NEW**: `https://YOUR-PROJECT-REF.supabase.co/functions/v1/journal`
- **DEBUG**: `http://localhost:54321/functions/v1/journal`

**3. StravaService.swift** ✅
- **OAuth Callback**:
  - **OLD**: `https://strava-sync-a2xd4ppmsq-uc.a.run.app/api/oauth/callback`
  - **NEW**: `https://YOUR-PROJECT-REF.supabase.co/functions/v1/oauth-callback`
- **Sync Beta**:
  - **OLD**: `https://strava-sync-a2xd4ppmsq-uc.a.run.app/api/sync-beta`
  - **NEW**: `https://YOUR-PROJECT-REF.supabase.co/functions/v1/sync-beta`
- **DEBUG**: `http://localhost:54321/functions/v1/...`

## ⚠️ Important: Replace Placeholder URL

All three files now contain this placeholder:
```swift
private let baseURL = "https://YOUR-PROJECT-REF.supabase.co"
```

**You MUST replace `YOUR-PROJECT-REF` with your actual Supabase project reference!**

### How to Find Your Project Reference:
1. Go to https://supabase.com/dashboard
2. Select your project
3. Go to Settings > API
4. Your Project URL will look like: `https://abcdefghijklmnop.supabase.co`
5. The project ref is: `abcdefghijklmnop`

### Quick Replace Command:
```bash
cd "/Users/jack.rudelic/projects/labs/Runaway iOS"

# Replace YOUR-PROJECT-REF with your actual project ref (e.g., abcdefghijklmnop)
find "Runaway iOS/Services" -name "*.swift" -type f -exec sed -i '' 's/YOUR-PROJECT-REF/your-actual-ref/g' {} +
```

## 📋 Deployment Checklist

### Step 1: Deploy Edge Functions ⏳
```bash
cd /Users/jack.rudelic/projects/labs/runaway-edge

# Link Supabase project
supabase link --project-ref your-project-ref

# Run migrations
supabase db push

# Set secrets
supabase secrets set ANTHROPIC_API_KEY=your_key
supabase secrets set STRAVA_CLIENT_ID=118220
supabase secrets set STRAVA_CLIENT_SECRET=your_secret

# Deploy functions
supabase functions deploy chat
supabase functions deploy journal
supabase functions deploy oauth-callback
supabase functions deploy sync-beta
supabase functions deploy sync-processor
```

### Step 2: Update pg_cron ⏳
After deployment, update the sync-processor cron job with your actual URL:
```sql
-- In Supabase Dashboard > SQL Editor
SELECT cron.unschedule('process-sync-jobs');

SELECT cron.schedule(
  'process-sync-jobs',
  '*/5 * * * *',
  $$
  SELECT
    net.http_post(
      url := 'https://YOUR-ACTUAL-REF.supabase.co/functions/v1/sync-processor',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer YOUR_SERVICE_ROLE_KEY'
      ),
      body := '{}'::jsonb
    ) AS request_id;
  $$
);
```

### Step 3: Update iOS App URLs ⏳
Replace `YOUR-PROJECT-REF` in these files:
- [ ] ChatService.swift (line 18)
- [ ] JournalService.swift (line 18)
- [ ] StravaService.swift (line 21)

### Step 4: Test Edge Functions ⏳
Test each function before running iOS app:

**Chat Function:**
```bash
curl -X POST https://your-ref.supabase.co/functions/v1/chat \
  -H "Content-Type: application/json" \
  -d '{"athlete_id": 94451852, "message": "Hello"}'
```

**Journal Function:**
```bash
curl -X POST https://your-ref.supabase.co/functions/v1/journal/generate \
  -H "Content-Type: application/json" \
  -d '{"athlete_id": 94451852}'
```

**OAuth Flow:**
1. Visit OAuth URL in browser
2. Authorize with Strava
3. Verify redirect to oauth-callback works
4. Check tokens stored in Supabase

**Sync Beta:**
```bash
curl -X POST https://your-ref.supabase.co/functions/v1/sync-beta \
  -H "Content-Type: application/json" \
  -d '{"user_id": 94451852}'
```

### Step 5: Build & Test iOS App ⏳
```bash
cd "/Users/jack.rudelic/projects/labs/Runaway iOS"

# Build for simulator
xcodebuild -project "Runaway iOS.xcodeproj" \
  -scheme "Runaway iOS" \
  -destination "platform=iOS Simulator,name=iPhone 15" \
  build

# Or open in Xcode and run
open "Runaway iOS.xcworkspace"
```

### Step 6: Test iOS Features ⏳
- [ ] Chat with AI coach
- [ ] Generate training journal
- [ ] Connect Strava account (OAuth)
- [ ] Trigger activity sync
- [ ] Verify activities appear in app

### Step 7: Monitor & Debug ⏳
```bash
# Watch Edge Function logs
supabase functions logs chat --tail
supabase functions logs journal --tail
supabase functions logs sync-processor --tail

# Check sync job status
# In Supabase Dashboard > SQL Editor:
SELECT * FROM sync_jobs ORDER BY created_at DESC LIMIT 10;

# Check job statistics
SELECT * FROM get_sync_job_stats();
```

## ⚠️ Known Issues & Notes

### 1. Disconnect Endpoint Missing
**Issue**: StravaService.swift still references `/api/disconnect` (line 64), but this Edge Function doesn't exist yet.

**Options**:
1. **Create disconnect Edge Function** (recommended)
2. **Handle disconnect in iOS app directly** by calling Supabase to delete tokens
3. **Keep Cloud Run disconnect endpoint** temporarily

**TODO**: Decide on approach and implement.

### 2. Local Development URLs
All services now point to `http://localhost:54321` for DEBUG builds. This is the default Supabase local dev server port.

**To test locally:**
```bash
cd /Users/jack.rudelic/projects/labs/runaway-edge
supabase start
supabase functions serve chat --env-file .env.local
```

### 3. Authentication Headers
ChatService.swift still includes auth headers from `APIConfiguration`. Verify these are still needed for Edge Functions or can be removed.

### 4. Response Format Compatibility
Edge Functions return the same JSON format as Cloud Run APIs, so no changes needed to response parsing. Verified:
- Chat: `{ "answer": "...", "conversation_id": "...", "context": {...} }`
- Journal: `{ "success": true, "entries": [...] }` and `{ "success": true, "journal": {...} }`
- Sync: `{ "job_id": "...", "status": "...", "user_id": ... }`

## 📊 Migration Progress

- ✅ Phase 1-6: Edge Functions & Database (COMPLETE)
- ✅ iOS Service Files Updated (COMPLETE)
- ⏳ Phase 7: Testing & Deployment (IN PROGRESS)
  - [ ] Deploy Edge Functions
  - [ ] Replace placeholder URLs in iOS
  - [ ] Test all endpoints
  - [ ] Test iOS app end-to-end
  - [ ] Monitor for 48 hours
  - [ ] Deprecate Cloud Run

## 🎯 Success Criteria

- [ ] All Edge Functions deployed and responding
- [ ] iOS app successfully connects to Edge Functions
- [ ] Chat feature works
- [ ] Journal generation works
- [ ] Strava OAuth works
- [ ] Activity sync works
- [ ] No errors in Edge Function logs
- [ ] Response times < 500ms
- [ ] Zero crashes in iOS app

## 📞 Support

If you encounter issues:
1. Check Edge Function logs: `supabase functions logs <function-name>`
2. Check database logs in Supabase Dashboard
3. Check iOS debug console for error messages
4. Verify placeholder URLs are replaced
5. Verify secrets are set correctly

## 💰 Cost Savings

Once fully migrated and Cloud Run deprecated:
- **Before**: ~$60/month (Cloud Run)
- **After**: $0/month (Supabase free tier)
- **Savings**: $60/month = $720/year 🎉
