# Runaway iOS - Setup Guide

This guide walks you through setting up the Runaway iOS app for local development.

## Prerequisites

- Xcode 16.2 or later
- iOS 18.2 SDK or later
- Active Supabase project
- (Optional) Firebase project for analytics

## Step 1: Clone and Open Project

```bash
git clone <repository-url>
cd "Runaway iOS"
open "Runaway iOS.xcworkspace"
```

## Step 2: Configure Supabase

Supabase credentials can be configured using either environment variables (recommended) or Info.plist.

### Option A: Environment Variables (Recommended)

Set the following environment variables in your shell:

```bash
export SUPABASE_URL="https://your-project.supabase.co"
export SUPABASE_KEY="your-anon-key-here"
```

**For Xcode:**
1. Edit your scheme: Product > Scheme > Edit Scheme
2. Select "Run" > "Arguments" tab
3. Add to "Environment Variables":
   - `SUPABASE_URL` = `https://your-project.supabase.co`
   - `SUPABASE_KEY` = `your-anon-key-here`

### Option B: Info.plist Configuration

1. Copy the template file:
   ```bash
   cp Runaway-iOS-Info.plist.template Runaway-iOS-Info.plist
   ```

2. Open `Runaway-iOS-Info.plist` and replace placeholders:
   - `SUPABASE_URL`: Your Supabase project URL
   - `SUPABASE_KEY`: Your Supabase **anon** key (NOT service role key)

3. **IMPORTANT**: Add `Runaway-iOS-Info.plist` to `.gitignore`:
   ```bash
   echo "Runaway-iOS-Info.plist" >> .gitignore
   ```

### Getting Your Supabase Credentials

1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project
3. Navigate to **Settings** > **API**
4. Copy:
   - **Project URL** → Use for `SUPABASE_URL`
   - **anon public** key → Use for `SUPABASE_KEY`

⚠️ **Security Note**: Never use the `service_role` key in client applications!

## Step 3: Configure Optional API Keys

### Runaway Coach API (Optional)
For AI-powered running analysis:

**Environment Variable:**
```bash
export RUNAWAY_API_KEY="your-api-key-here"
```

**OR in Info.plist:**
```xml
<key>RUNAWAY_API_KEY</key>
<string>your-api-key-here</string>
```

### MapBox Token (Optional)
For map features:

```xml
<key>MBXAccessToken</key>
<string>your-mapbox-token-here</string>
```

### NewsAPI (Optional)
For running news feed:

```xml
<key>NEWS_API_KEY</key>
<string>your-newsapi-key-here</string>
```

Get your key at: https://newsapi.org/

## Step 4: Configure Firebase

Firebase is required for the app to build and run properly.

### For Local Development

1. Download `GoogleService-Info.plist` from [Firebase Console](https://console.firebase.google.com/)
2. Add it to the `Runaway iOS/` directory
3. The file is gitignored for security

### For CI/CD

See [FIREBASE_SECRETS_SETUP.md](./FIREBASE_SECRETS_SETUP.md) for configuring GitHub Actions secrets.

**Note:** The CI workflows automatically generate a placeholder `GoogleService-Info.plist` if Firebase secrets aren't configured, allowing builds to complete.

## Step 5: Install Dependencies

Dependencies are managed via Swift Package Manager and should resolve automatically when you open the project.

**Current Dependencies:**
- Supabase SDK (v2.5.1+)
- Firebase Core, Analytics, Messaging (v11.10.0+)
- Polyline (GPS encoding)
- SwiftyJSON
- CoreGPX

If packages don't resolve automatically:
1. File > Packages > Reset Package Caches
2. File > Packages > Resolve Package Versions

## Step 6: Build and Run

1. Select the **Runaway iOS** scheme
2. Choose your target device or simulator (iPhone 15 or later recommended)
3. Press **Cmd+R** to build and run

## Verifying Configuration

When the app launches, check the Xcode console for:

```
✅ Supabase client initialized successfully
🔧 Supabase Configuration:
   URL Configured: ✅
   Key Configured: ✅
   Configuration Source: Environment Variable (or Info.plist)
   Supabase Domain: your-project.supabase.co
```

If you see an error, check:
1. Credentials are correctly set in environment variables or Info.plist
2. `Runaway-iOS-Info.plist` exists if using Info.plist method
3. Environment variables are set in Xcode scheme if using that method

## Widget Extension Setup

The app includes a home screen widget. To test it:

1. Build and run the main app first
2. Long-press on home screen
3. Tap "+" to add widget
4. Search for "Runaway"
5. Add the widget to your home screen

**Note**: Widget uses App Group `group.com.jackrudelic.runawayios` to share data.

## Troubleshooting

### "Failed to initialize Supabase client"
- Verify `SUPABASE_URL` and `SUPABASE_KEY` are set correctly
- Check for typos in environment variable names
- Ensure Info.plist file exists and contains valid values

### Widget not updating
- Ensure app group is properly configured
- Verify widget extension has proper entitlements
- Check that `WidgetCenter.shared.reloadAllTimelines()` is being called

### Build errors with packages
- Reset package caches: File > Packages > Reset Package Caches
- Clean build folder: Shift+Cmd+K
- Restart Xcode

### Firebase errors
- Ensure `GoogleService-Info.plist` is added to the main target
- Verify Firebase is properly initialized in `AppDelegate.swift`

## Security Best Practices

1. ✅ **DO**: Use environment variables for sensitive credentials
2. ✅ **DO**: Use anon keys for client-side Supabase access
3. ✅ **DO**: Add `Runaway-iOS-Info.plist` to `.gitignore`
4. ❌ **DON'T**: Commit API keys or credentials to source control
5. ❌ **DON'T**: Use service role keys in client applications
6. ❌ **DON'T**: Hardcode credentials in Swift files

## Next Steps

- Review [CLAUDE.md](./CLAUDE.md) for architecture overview
- Check [Architecture Documentation](./documentation/) for detailed system design
- Set up your Supabase database schema
- Configure Row Level Security (RLS) policies in Supabase

## Support

For issues or questions:
- Check existing issues in the repository
- Review Supabase logs in dashboard
- Use `SupabaseConfiguration.printConfiguration()` for debugging
