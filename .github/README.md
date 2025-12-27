# GitHub Actions Workflows

This directory contains automated workflows for the Runaway iOS project.

## Available Workflows

### iOS CI/CD (`ios-build.yml`)
Automatically builds and tests the iOS app on every push and pull request.

**Status Badge:**
```markdown
[![iOS CI/CD](https://github.com/jacksonrdlc/Runaway-iOS/actions/workflows/ios-build.yml/badge.svg)](https://github.com/jacksonrdlc/Runaway-iOS/actions/workflows/ios-build.yml)
```

**What it does:**
- ✅ Builds the iOS app with Xcode 15.2
- ✅ Runs unit tests
- ✅ Builds the widget extension
- ✅ Performs SwiftLint code quality checks
- ✅ Uploads build logs on failure

**When it runs:**
- On push to `main` or `develop` branches
- On pull requests to `main` or `develop` branches
- Manually via workflow dispatch

See [CI_CD_DOCUMENTATION.md](CI_CD_DOCUMENTATION.md) for detailed information.
