# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

### Development Build
```bash
# Open the Xcode workspace (required for SPM dependencies)
open "Runaway iOS.xcworkspace"

# Build from command line (if workspace exists)
xcodebuild -workspace "Runaway iOS.xcworkspace" -scheme "Runaway iOS" -destination "platform=iOS Simulator,name=iPhone 15" build

# If no workspace exists, use project file
xcodebuild -project "Runaway iOS.xcodeproj" -scheme "Runaway iOS" -destination "platform=iOS Simulator,name=iPhone 15" build
```

### Running Tests
```bash
# Run tests for the main target
xcodebuild -project "Runaway iOS.xcodeproj" -scheme "Runaway iOS" -destination "platform=iOS Simulator,name=iPhone 15" test

# Run UI tests
xcodebuild -project "Runaway iOS.xcodeproj" -scheme "Runaway iOS" -destination "platform=iOS Simulator,name=iPhone 15" -only-testing:"Runaway iOSUITests" test
```

### Widget Extension
```bash
# Build the widget extension specifically
xcodebuild -project "Runaway iOS.xcodeproj" -scheme "RunawayWidgetExtension" -destination "platform=iOS Simulator,name=iPhone 15" build
```

## Project Architecture

### Core App Structure
- **Main App**: `Runaway iOS/` - SwiftUI-based fitness tracking application
- **Widget Extension**: `RunawayWidget/` - iOS home screen widget for activity display
- **Backend**: Supabase for real-time data, authentication, and storage
- **External APIs**: Runaway Coach AI API for enhanced analysis

### Key Architectural Patterns

#### Singleton Managers (Centralized State)
The app uses several singleton managers that should be treated as the single source of truth:
- `DataManager.shared` - Central data store for activities, athlete info, commitments
- `AuthManager.shared` - User authentication and session management
- `UserManager.shared` - User profile and preferences
- `RealtimeService.shared` - Real-time data synchronization with Supabase
- `LocationManager.shared` - GPS and location services

#### Data Flow Architecture
1. **RealtimeService** receives live updates from Supabase
2. **DataManager** processes and caches data, triggers widget updates
3. **Views** observe DataManager via `@EnvironmentObject` or `@StateObject`
4. **API Services** handle external data fetching and synchronization

#### Widget Integration
The app shares data with its widget through:
- **App Group**: `group.com.jackrudelic.runawayios` (UserDefaults suite)
- **Widget Data Format**: Activities encoded as `RAActivity` JSON strings
- **Auto-refresh**: `WidgetCenter.shared.reloadAllTimelines()` called after data updates

### Service Layer Organization

#### Core Services (`Services/`)
- `ActivityService.swift` - Activity CRUD operations with Supabase
- `AthleteService.swift` - Athlete profile management
- `CommitmentService.swift` - Daily commitment tracking and fulfillment
- `GoalService.swift` - Running goals and progress tracking
- `RealtimeService.swift` - Real-time data synchronization

#### API Integration (`Services/`)
- `RunawayCoachAPIService.swift` - AI-powered analysis API integration
- `EnhancedAnalysisService.swift` - Hybrid local/API analysis service
- `APIConfiguration.swift` - API endpoints and authentication

#### Specialized Services
- `GPSTrackingService.swift` - Live activity recording
- `ActivityRecordingService.swift` - Activity capture and processing
- `WidgetRefreshService.swift` - Widget data management

### Model Architecture (`Models/`)

#### Core Data Models
- `Activity.swift` - Individual workout/activity records
- `Athlete.swift` - User profile and performance metrics
- `DailyCommitment.swift` - Daily activity commitments
- `GoalModels.swift` - Running goals and progress tracking

#### API Models
- `APIModels.swift` - Request/response models for external APIs
- `ActivityModels.swift` - Activity-specific data structures

### Configuration Management

#### API Configuration
- Production API: `APIConfiguration.RunawayCoach.baseURL`
- Development fallback: Available but uses production by default
- Authentication: Environment variables > Info.plist > hardcoded (null)

#### Required Setup Files
- `Config.xcconfig` - Supabase credentials (not in repo)
- `Runaway-iOS-Info.plist` - API keys (generated from template)
- `GoogleService-Info.plist` - Firebase configuration

## Development Workflow

### Adding New Features
1. **Models**: Define data structures in appropriate `Models/` file
2. **Services**: Create service class in `Services/` with Supabase integration
3. **Views**: Build SwiftUI views that observe DataManager
4. **Integration**: Update DataManager to handle new data type
5. **Widget**: Update widget data format if relevant for home screen display

### API Integration Pattern
```swift
// Always use hybrid approach: API first, local fallback
let enhancedService = EnhancedAnalysisService()
let result = await enhancedService.performAnalysis(data: activityData)
// EnhancedAnalysisService automatically falls back to local analysis
```

### Real-time Updates
- New data flows: Supabase → RealtimeService → DataManager → Views
- Widget updates happen automatically via DataManager
- Background sync continues when app is backgrounded

### State Management Guidelines
- Use DataManager as single source of truth for core app data
- Views should observe DataManager via environment objects
- Avoid direct Supabase calls from views - use service layer
- Background tasks are managed automatically by DataManager

## Dependencies

### Swift Package Manager Dependencies
- **Supabase SDK** - Backend services and real-time sync
- **Firebase** - Analytics and additional services
- **SwiftyJSON** - JSON parsing utilities
- **Alamofire** - HTTP networking
- **Polyline** - GPS route encoding/decoding
- **CoreGPX** - GPX file handling

### External APIs
- **Supabase** - Primary backend (configured in `Utils/Supabase.swift`)
- **Runaway Coach API** - AI analysis (configured in `APIConfiguration.swift`)
- **NewsAPI** - Running news (optional, requires API key)
- **Eventbrite** - Running events (optional, requires API key)

## Security Notes

### API Key Management
- Never commit API keys to source control
- Use template files: `Runaway-iOS-Info.plist.template`
- Environment variables take precedence over Info.plist
- Supabase credentials are hardcoded in `Utils/Supabase.swift` (consider moving)

### Data Privacy
- All user data stored in Supabase with Row Level Security (RLS)
- Widget data shared through app group container only
- Location services require explicit user permission

## Testing

### API Testing
```swift
// Use provided test utilities
let testRunner = APITestRunner()
await testRunner.runTests() // Tests all API endpoints
```

### Widget Testing
Widget functionality can be tested by:
1. Adding test activities to DataManager
2. Calling `dataManager.updateWidgetData()`
3. Checking widget display in iOS simulator

## Common Issues

### Widget Not Updating
- Ensure app group is properly configured: `group.com.jackrudelic.runawayios`
- Verify `WidgetCenter.shared.reloadAllTimelines()` is called after data changes
- Check UserDefaults suite accessibility in widget extension

### API Integration Issues
- Verify API configuration in `APIConfiguration.swift`
- Check authentication headers and base URL
- Use `APIConfiguration.RunawayCoach.printCurrentConfiguration()` for debugging

### Real-time Sync Problems
- Ensure Supabase credentials are properly configured
- Check network connectivity and Supabase project status
- Verify RealtimeService subscription is active