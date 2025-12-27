# CI/CD Pipeline Documentation

## Overview
This repository uses GitHub Actions for continuous integration and continuous deployment (CI/CD) to automatically build and test the iOS app on all pull requests and pushes.

## Workflow File
The main workflow is defined in `.github/workflows/ios-build.yml`

## Triggers
The workflow runs on:
- Pushes to `main` and `develop` branches
- Pull requests targeting `main` and `develop` branches
- Manual workflow dispatch (via GitHub UI)

## Jobs

### Build Job
The build job performs the following steps:
1. **Checkout code** - Clones the repository
2. **Setup Xcode 15.2** - Configures the build environment
3. **Cache dependencies** - Speeds up builds by caching Swift Package Manager dependencies
4. **Create placeholder plists** - Generates `Runaway-iOS-Info.plist` and `GoogleService-Info.plist` with placeholder values for CI
5. **Set environment variables** - Configures Supabase credentials from GitHub Secrets
6. **Resolve SPM dependencies** - Downloads and resolves Swift Package Manager packages
7. **Build main app** - Compiles the iOS app with code signing disabled
8. **Run tests** - Executes unit tests (continues on error to not block PRs)
9. **Build widget extension** - Compiles the RunawayWidgetExtension target (continues on error)
10. **Upload logs on failure** - Archives build logs for debugging if the workflow fails

### Lint Job
The lint job runs SwiftLint to check code quality:
- Installs SwiftLint via Homebrew
- Runs linting with GitHub Actions logging format
- Continues on error (non-blocking) to provide feedback without failing the build

## Configuration

### Required GitHub Secrets
To enable full functionality, configure the following secrets in your repository:
- `SUPABASE_URL` - Your Supabase project URL (e.g., `https://your-project.supabase.co`)
- `SUPABASE_KEY` - Your Supabase anon/public key

**Note:** The workflow uses placeholder values if secrets are not configured, allowing it to run in forks and public repositories.

### SwiftLint Configuration
Code quality rules are defined in `.swiftlint.yml` with:
- Reasonable defaults that don't block development
- Line length warnings at 150 characters, errors at 200
- Minimum identifier length of 2 characters
- Exclusion of build artifacts and dependencies

## Build Environment
- **Runner**: macOS 14
- **Xcode**: 15.2
- **Destination**: iPhone 15 Simulator (iOS 17.2)
- **Configuration**: Debug
- **Code Signing**: Disabled (for CI environment)

## Caching
Swift Package Manager dependencies are cached to speed up subsequent builds:
- Cache key based on `Package.resolved` hash
- Includes `.build` directory and Xcode DerivedData

## Troubleshooting

### Build Failures
If the build fails, check:
1. Build logs artifact uploaded by the workflow
2. Xcode and Swift version compatibility
3. Swift Package Manager dependency resolution
4. Missing required files or configuration

### Test Failures
Tests are configured to continue on error, so they won't block the workflow. Review test results in the Actions tab to identify and fix failing tests.

### Lint Warnings
SwiftLint warnings are non-blocking but should be addressed to maintain code quality. The workflow uses the `github-actions-logging` reporter for easy review in pull requests.

## Local Development
To run the same checks locally:

```bash
# Build the app
xcodebuild -project "Runaway iOS.xcodeproj" -scheme "Runaway iOS" \
  -destination "platform=iOS Simulator,name=iPhone 15" build

# Run tests
xcodebuild -project "Runaway iOS.xcodeproj" -scheme "Runaway iOS" \
  -destination "platform=iOS Simulator,name=iPhone 15" test

# Run SwiftLint
swiftlint lint
```

## Future Enhancements
Potential improvements to the CI/CD pipeline:
- Add code coverage reporting
- Implement automatic deployment to TestFlight
- Add performance testing
- Include UI testing in the pipeline
- Add security scanning (e.g., dependency vulnerability checks)
