# API Configuration Setup

## For Development and Production Builds

### Setup Instructions

1. **Copy the template file:**
   ```bash
   cp Runaway-iOS-Info.plist.template Runaway-iOS-Info.plist
   ```

2. **Add your API keys to `Runaway-iOS-Info.plist`:**
   - Replace `YOUR_RUNAWAY_API_KEY_HERE` with your actual Runaway Coach API key
   - Replace `YOUR_YOUTUBE_API_KEY_HERE` with your YouTube API key
   - Replace `YOUR_MAPBOX_TOKEN_HERE` with your Mapbox access token

3. **For development (optional):**
   - You can also set environment variables in Xcode:
     - Go to Product → Scheme → Edit Scheme
     - Select "Run" → "Arguments" → "Environment Variables"
     - Add `RUNAWAY_API_KEY` with your API key
   - Environment variables take precedence over Info.plist

### How it works

The API configuration follows this priority order:
1. **Environment Variable** (`RUNAWAY_API_KEY`) - Development only
2. **Info.plist** (`RUNAWAY_API_KEY`) - Works for both development and production
3. **Hardcoded value** - Not recommended, currently set to `nil`

### Security Notes

- The `Runaway-iOS-Info.plist` file is ignored by git to prevent API keys from being committed
- Use the template file for version control
- Never commit actual API keys to the repository
- For CI/CD, inject API keys during the build process

### Archive Builds

For archive builds (TestFlight, App Store), the API key **must** be in the Info.plist file, as environment variables are not available in archived builds.