# Firebase Secrets Setup for CI/CD

This document explains how to configure Firebase secrets for GitHub Actions workflows.

## Required Secrets for Production Release

The release workflow (`release.yml`) needs the following GitHub repository secrets configured for production builds:

### Firebase Configuration Secrets

1. **FIREBASE_API_KEY**
   - Found in: Firebase Console → Project Settings → General → Web API Key
   - Example: `AIzaSyA...xyz`

2. **FIREBASE_PROJECT_ID**
   - Found in: Firebase Console → Project Settings → General → Project ID
   - Example: `runaway-ios-prod`

3. **FIREBASE_APP_ID**
   - Found in: Firebase Console → Project Settings → General → Your apps → iOS app → App ID
   - Example: `1:123456789:ios:abc123def456`

4. **FIREBASE_GCM_SENDER_ID**
   - Found in: Firebase Console → Project Settings → Cloud Messaging → Sender ID
   - Example: `123456789`

5. **FIREBASE_STORAGE_BUCKET**
   - Found in: Firebase Console → Project Settings → General → Storage bucket
   - Example: `runaway-ios-prod.appspot.com`

## How to Add Secrets to GitHub

1. Go to your repository on GitHub
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add each secret with the name exactly as shown above
5. Paste the value from your Firebase Console

## Fallback Behavior

If Firebase secrets are not configured:
- **Release builds**: Will use placeholder values (build will succeed but Firebase features won't work)
- **CI builds** (`build.yml`): Always use placeholder values (Firebase not needed for compile-time checks)

## Getting Firebase Configuration

To get your Firebase configuration values:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project (or create a new one)
3. Click the gear icon ⚙️ → **Project settings**
4. Scroll to **Your apps** section
5. If you haven't added an iOS app yet:
   - Click **Add app** → **iOS**
   - Enter bundle ID: `com.jackrudelic.labs.Runaway-iOS`
   - Follow the setup wizard
6. Download `GoogleService-Info.plist` (for local development)
7. Copy the individual values to GitHub Secrets (for CI/CD)

## Local Development

For local development, download `GoogleService-Info.plist` from Firebase Console and place it in the `Runaway iOS/` directory. The file is gitignored for security.

## Verification

After adding secrets, trigger a release workflow run to verify:
1. Go to **Actions** tab
2. Select **Release to App Store** workflow
3. Click **Run workflow**
4. Monitor the "Create GoogleService-Info.plist" step
5. It should show "✓ GoogleService-Info.plist created"

## Security Notes

- Never commit `GoogleService-Info.plist` to the repository
- Firebase configuration values are client-side and safe to use in CI/CD
- These are not secret API keys - they identify your app to Firebase services
- **Real security** comes from Firebase Security Rules configured in your Firebase Console
- Configure proper domain restrictions and Security Rules to protect your Firebase services
- Rotate Firebase configuration if accidentally exposed publicly
