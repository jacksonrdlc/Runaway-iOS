# GitHub Copilot Instructions for Runaway iOS

This file provides comprehensive guidance for GitHub Copilot when working with the Runaway iOS fitness tracking application.

## Project Overview

Runaway iOS is a SwiftUI-based fitness tracking application for iOS that integrates with Supabase for backend services and includes a home screen widget for quick activity access.

**Tech Stack:**
- Swift 5 / SwiftUI
- iOS 16.0+
- Xcode 15.0+
- Supabase (Backend, Auth, Real-time sync)
- Firebase (Analytics)
- WidgetKit (Home screen widget)

## Build Commands

### Quick Start
```bash
# Build the project (no workspace - uses Swift Package Manager)
xcodebuild -project "Runaway iOS.xcodeproj" -scheme "Runaway iOS" -destination "platform=iOS Simulator,name=iPhone 15" build

# Run tests
xcodebuild -project "Runaway iOS.xcodeproj" -scheme "Runaway iOS" -destination "platform=iOS Simulator,name=iPhone 15" test

# Build widget extension
xcodebuild -project "Runaway iOS.xcodeproj" -scheme "RunawayWidgetExtension" -destination "platform=iOS Simulator,name=iPhone 15" build
```

### Running the App
```bash
# Open in Xcode (preferred for development)
open "Runaway iOS.xcodeproj"
```

## Project Structure

```
Runaway iOS/
├── Models/              # Data models (Activity, Athlete, Goals, etc.)
├── Views/               # SwiftUI views and screens
├── Services/            # Service layer (API, Supabase, Location, etc.)
├── Managers/            # Singleton managers (Data, Auth, User)
├── Utils/               # Helper utilities and extensions
└── Assets.xcassets/     # Images and color assets

RunawayWidget/           # Widget extension target
Runaway iOSTests/        # Unit tests
Runaway iOSUITests/      # UI tests
```

## Architecture Patterns

### Singleton Managers (Single Source of Truth)
The app uses centralized singleton managers - **always** interact with these rather than direct Supabase calls:

- `DataManager.shared` - Central data store for activities, athlete info, commitments
- `AuthManager.shared` - User authentication and session management  
- `UserManager.shared` - User profile and preferences
- `RealtimeService.shared` - Real-time data synchronization with Supabase
- `LocationManager.shared` - GPS and location services

### Data Flow
```
Supabase → RealtimeService → DataManager → Views (via @EnvironmentObject)
```

### Service Layer Organization

**Core Services** (`Services/`):
- `ActivityService.swift` - Activity CRUD operations
- `AthleteService.swift` - Athlete profile management
- `CommitmentService.swift` - Daily commitment tracking
- `GoalService.swift` - Running goals and progress
- `RealtimeService.swift` - Real-time data sync

**API Integration**:
- `RunawayCoachAPIService.swift` - AI-powered analysis API
- `EnhancedAnalysisService.swift` - Hybrid local/API analysis (use this for new features)
- `APIConfiguration.swift` - API endpoints and authentication

**Specialized Services**:
- `GPSTrackingService.swift` - Live activity recording
- `ActivityRecordingService.swift` - Activity capture
- `WidgetRefreshService.swift` - Widget data management

### Widget Integration
The app shares data with its widget through:
- **App Group**: `group.com.jackrudelic.runawayios`
- **Shared Data**: UserDefaults suite with JSON-encoded activities
- **Auto-refresh**: `WidgetCenter.shared.reloadAllTimelines()` called after data updates

## Development Guidelines

### When Adding New Features

1. **Models**: Define data structures in `Models/`
2. **Services**: Create service class with Supabase integration
3. **Views**: Build SwiftUI views that observe DataManager via `@EnvironmentObject`
4. **DataManager**: Update to handle new data type and trigger widget updates
5. **Tests**: Add unit tests in `Runaway iOSTests/`

### State Management Rules

✅ **DO:**
- Use DataManager as single source of truth
- Observe DataManager via `@EnvironmentObject` or `@StateObject`
- Call service methods for data operations
- Update widgets via DataManager after changes

❌ **DON'T:**
- Make direct Supabase calls from views
- Create multiple sources of truth
- Bypass the service layer
- Forget to update widget data after changes

### API Integration Pattern

Always use the hybrid approach (API first, local fallback):

```swift
let enhancedService = EnhancedAnalysisService()
let result = await enhancedService.performAnalysis(data: activityData)
// Automatically falls back to local analysis if API unavailable
```

## Configuration & Security

### API Keys and Credentials

⚠️ **CRITICAL SECURITY RULES:**
- **NEVER** commit API keys or credentials to source control
- **ALWAYS** use template files: `Runaway-iOS-Info.plist.template`
- **ALWAYS** add sensitive files to `.gitignore`

### Supabase Configuration

**Priority Order**: Environment variables → Info.plist → hardcoded (null)

**Environment Variables (Recommended):**
```bash
export SUPABASE_URL="https://your-project.supabase.co"
export SUPABASE_KEY="your-anon-key-here"
```

**Info.plist Setup:**
1. Copy `Runaway-iOS-Info.plist.template` to `Runaway-iOS-Info.plist`
2. Replace `SUPABASE_URL` and `SUPABASE_KEY` placeholders
3. Use ANON key only (NOT service role key)

### Required Setup Files
- `Runaway-iOS-Info.plist` - API keys and Supabase credentials (from template)
- `GoogleService-Info.plist` - Firebase configuration

## Dependencies

### Swift Package Manager
The project uses SPM for dependencies (managed in Xcode):
- **Supabase SDK** - Backend services and real-time sync
- **Firebase** - Analytics
- **SwiftyJSON** - JSON parsing
- **Alamofire** - HTTP networking
- **Polyline** - GPS route encoding/decoding
- **CoreGPX** - GPX file handling

**To add/update dependencies:** Use Xcode > File > Add Package Dependencies

## Testing

### Running Tests
```bash
# All tests
xcodebuild -project "Runaway iOS.xcodeproj" -scheme "Runaway iOS" \
  -destination "platform=iOS Simulator,name=iPhone 15" test

# Specific test target
xcodebuild -project "Runaway iOS.xcodeproj" -scheme "Runaway iOS" \
  -destination "platform=iOS Simulator,name=iPhone 15" \
  -only-testing:"Runaway iOSTests" test
```

### Widget Testing
1. Add test activities to DataManager
2. Call `dataManager.updateWidgetData()`
3. Verify widget display in simulator

## Code Style Guidelines

### Swift/SwiftUI Best Practices

**DO:**
- Use meaningful variable names (`activityDate` not `ad`)
- Prefer `async/await` over completion handlers
- Use SwiftUI property wrappers appropriately (`@State`, `@StateObject`, `@EnvironmentObject`)
- Follow existing naming conventions in the codebase

**DON'T:**
- Add comments unless they match existing style or explain complex logic
- Create new libraries/dependencies unless absolutely necessary
- Modify working code unnecessarily

### File Organization
- One model/service/manager per file
- Group related functionality together
- Use MARK comments for section organization:
  ```swift
  // MARK: - Properties
  // MARK: - Initialization
  // MARK: - Public Methods
  // MARK: - Private Methods
  ```

## Common Patterns & Solutions

### Real-time Updates
```swift
// Subscribe to changes in RealtimeService
// DataManager handles this automatically - check existing implementation
```

### Widget Updates
```swift
// After updating data in DataManager:
dataManager.updateWidgetData()
WidgetCenter.shared.reloadAllTimelines()
```

### Location Tracking
```swift
// Use LocationManager for GPS functionality
let locationManager = LocationManager.shared
// Check existing usage in GPSTrackingService
```

## Common Issues

### Widget Not Updating
- Verify app group: `group.com.jackrudelic.runawayios`
- Check `WidgetCenter.shared.reloadAllTimelines()` is called
- Ensure UserDefaults suite accessibility

### API Integration Issues
- Verify configuration in `APIConfiguration.swift`
- Use `APIConfiguration.RunawayCoach.printCurrentConfiguration()` for debugging
- Check authentication headers

### Real-time Sync Problems
- Verify Supabase credentials (use `SupabaseConfiguration.printConfiguration()`)
- Check RealtimeService subscription status
- Confirm network connectivity

## Privacy & Data Security

- All user data stored in Supabase with Row Level Security (RLS)
- Widget data shared only through app group container
- Location services require explicit user permission
- Use ANON key for client apps (never service role key)

## Additional Resources

- Main README: `README.md`
- Setup Guide: `SETUP.md`
- API Setup: `API_SETUP.md`, `API_KEY_SETUP.md`
- Goals Feature: `README_GOALS_SETUP.md`
- Claude AI Instructions: `CLAUDE.md` (comprehensive technical details)

## Working with This Repository

When assigned an issue or task:

1. **Understand** - Read the issue description and acceptance criteria
2. **Explore** - Review relevant files and existing patterns
3. **Build** - Make minimal, focused changes
4. **Test** - Run tests and verify functionality
5. **Validate** - Build the app and test in simulator if UI changes
6. **Document** - Update docs if changing public APIs or architecture

**Remember:** Make the smallest possible changes to achieve the goal. Prefer modifying existing code patterns over introducing new approaches.
