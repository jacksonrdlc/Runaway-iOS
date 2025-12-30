# Quick Wins Feature - Implementation Summary

## Overview

The Quick Wins feature provides AI-powered running insights with 4 main screens:
1. **Dashboard** - Comprehensive overview with quick stats and navigation
2. **Weather Impact** - Weather analysis affecting performance
3. **VO2 Max & Racing** - Fitness estimation and race predictions
4. **Training Load** - ACWR-based injury risk and recovery monitoring

## Architecture

### Data Models
**Location**: `/Models/QuickWinsModels.swift`

- `QuickWinsResponse` - Main API response wrapper
- `QuickWinsAnalyses` - Contains all three analysis types
- `WeatherAnalysis` - Weather impact metrics
- `VO2MaxEstimate` - VO2 max and race predictions
- `RacePrediction` - Individual race prediction
- `TrainingLoadAnalysis` - ACWR and training metrics
- `QuickWinsError` - Error handling

### Service Layer
**Location**: `/Services/QuickWinsService.swift`

- `QuickWinsService` - ObservableObject for API calls
- Methods:
  - `fetchComprehensiveAnalysis()` - Get all insights
  - `fetchWeatherImpact(limit:)` - Weather analysis only
  - `fetchVO2MaxEstimate(limit:)` - VO2 max only
  - `fetchTrainingLoad(limit:)` - Training load only
  - `fetchWithLoading(operation:)` - Loading state wrapper

### ViewModel
**Location**: `/ViewModels/QuickWinsViewModel.swift`

- `QuickWinsViewModel` - @MainActor ObservableObject
- Features:
  - 1-hour cache (UserDefaults)
  - Auto-refresh on stale data
  - Loading/error states
  - Mock data support for development

### Views

#### Dashboard
**Location**: `/Views/QuickWins/QuickWinsDashboardView.swift`

Components:
- `QuickStatsCarousel` - Horizontal scrolling stat cards
- `PriorityRecommendationsBanner` - Top recommendations
- `NavigationCardsGrid` - 2x2 grid to detail views
- `ErrorView` - Error state with retry
- `EmptyStateView` - No data state

#### Weather Impact
**Location**: `/Views/QuickWins/WeatherImpactView.swift`

Components:
- `WeatherHeroCard` - Impact badge + 2x2 metrics
- `PaceImpactCallout` - Pace degradation warning
- `HeatAcclimationIndicator` - 3-dot acclimation level
- `OptimalTrainingTimes` - Best times to train
- `RecommendationsList` - Weather recommendations

#### VO2 Max & Racing
**Location**: `/Views/QuickWins/VO2MaxRacingView.swift`

Components:
- `VO2MaxHeroCard` - Large VO2 number + fitness level
- `FitnessLevelProgressBar` - Rainbow gradient progress
- `VVO2MaxTrainingCard` - Interval training pace
- `RacePredictionsList` - 5K, 10K, Half, Marathon
- `RacePredictionCard` - Individual prediction with confidence

#### Training Load
**Location**: `/Views/QuickWins/TrainingLoadView.swift`

Components:
- `ACWRCircularGauge` - Circular ACWR indicator
- `ACWRZoneIndicator` - 4-zone horizontal bar
- `TrainingStatsGrid` - 2x2 metrics (acute/chronic/TSS/volume)
- `RecoveryStatusBanner` - Tappable recovery status
- `TrainingTrendsRow` - Training & fitness trends
- `SevenDayWorkoutPlan` - Daily workout cards

## API Configuration

**Location**: `/Configuration/APIConfiguration.swift`

Added endpoints:
```swift
static let comprehensiveAnalysis = "/quick-wins/comprehensive-analysis"
static let weatherImpact = "/quick-wins/weather-impact"
static let vo2maxEstimate = "/quick-wins/vo2max-estimate"
static let trainingLoad = "/quick-wins/training-load"
```

Base URL: `https://runaway-coach-api-203308554831.us-central1.run.app`

## Integration

**Location**: `/Views/MainView.swift`

Added new tab:
```swift
QuickWinsDashboardView()
    .tabItem {
        Label("Insights", systemImage: "chart.bar.fill")
    }
    .tag(3)
```

## Color Logic

### ACWR / Injury Risk
- `< 0.8` = Blue (Detraining)
- `0.8 - 1.3` = Green (Optimal)
- `1.3 - 1.5` = Orange (Moderate Risk)
- `> 1.5` = Red (High Risk)

### VO2 Max Fitness Level
- `elite` = Purple
- `excellent` = Blue
- `good` = Green
- `average` = Orange
- `below_average` = Gray

### Weather Impact
- `minimal` = Green
- `moderate` = Orange
- `significant` = Red
- `severe` = Purple

### Temperature
- `< 15°C` = Blue
- `15-20°C` = Green
- `20-25°C` = Orange
- `> 25°C` = Red

## Features

### 1. Caching
- 1-hour cache in UserDefaults
- Auto-loads cached data on startup
- Smart refresh only when stale

### 2. Pull-to-Refresh
- Dashboard supports pull-to-refresh
- Fetches fresh data from API

### 3. Error Handling
- Network errors
- Decoding errors
- Unauthorized (401)
- Server errors
- User-friendly error messages with retry

### 4. Loading States
- Skeleton loading on first fetch
- Progress indicators
- Loading overlays

### 5. Empty States
- "No data available" messaging
- Encouragement to complete more runs
- Clear call-to-action buttons

## Mock Data

For development/testing without API:

```swift
let viewModel = QuickWinsViewModel()
viewModel.loadMockData()
```

Or use built-in mock:
```swift
QuickWinsResponse.mock
```

## Testing Checklist

- [x] Dashboard loads comprehensive analysis
- [x] Quick stats display correct values
- [x] Navigation cards lead to detail screens
- [x] Weather impact colors match severity
- [x] VO2 Max gauge shows correct fitness level
- [x] All 4 race predictions display
- [x] ACWR gauge color matches injury risk
- [x] 7-day workout plan shows all days
- [x] Pull-to-refresh updates data
- [x] Loading spinner shows during API calls
- [x] Error state displays when API fails
- [x] Works in light and dark mode
- [x] Accessibility labels for VoiceOver

## Dependencies

- SwiftUI (UI framework)
- Foundation (Core functionality)
- URLSession (Network requests)

## API Authentication

Uses JWT token from `UserSession`:
- Token automatically included via `APIConfiguration.RunawayCoach.getAuthHeaders()`
- Bearer authentication
- Auto-refresh handled by Supabase

## Future Enhancements

### High Priority
- [ ] Share race predictions (export/share sheet)
- [ ] Add Fahrenheit temperature toggle
- [ ] Workout plan export to calendar
- [ ] Notifications for optimal training times

### Medium Priority
- [ ] Historical trend charts
- [ ] Compare predictions to actual races
- [ ] Custom ACWR thresholds
- [ ] Widget support for quick stats

### Low Priority
- [ ] PDF report generation
- [ ] Social sharing
- [ ] Integration with health apps
- [ ] Multi-language support

## Development Notes

### Mock vs Real API
Switch between mock and real data:

```swift
// Use mock data
let viewModel = QuickWinsViewModel()
viewModel.loadMockData()

// Use real API
let viewModel = QuickWinsViewModel()
Task { await viewModel.loadData() }
```

### Debug Logging
All API calls log to console with 🏃 prefix:
```
🏃 Quick Wins API Request:
   URL: https://...
   Method: GET
   Auth: Bearer eyJ...
   Response Code: 200
   ✅ Successfully decoded QuickWinsResponse
```

### Force Refresh
```swift
viewModel.clearCache()
Task { await viewModel.refresh() }
```

## File Structure

```
Runaway iOS/
├── Models/
│   └── QuickWinsModels.swift
├── Services/
│   └── QuickWinsService.swift
├── ViewModels/
│   └── QuickWinsViewModel.swift
├── Views/
│   └── QuickWins/
│       ├── QuickWinsDashboardView.swift
│       ├── WeatherImpactView.swift
│       ├── VO2MaxRacingView.swift
│       └── TrainingLoadView.swift
└── Configuration/
    └── APIConfiguration.swift (modified)
```

## API Response Example

```json
{
  "success": true,
  "user_id": "123",
  "analysis_date": "2025-10-01T17:30:00Z",
  "analyses": {
    "weather_context": { ... },
    "vo2max_estimate": { ... },
    "training_load": { ... }
  },
  "priority_recommendations": [ ... ]
}
```

## Support

For issues:
1. Check console logs for API errors
2. Verify JWT token is valid
3. Test with mock data first
4. Ensure API base URL is correct

## Credits

- UI Design: Claude Code
- API Integration: Runaway Coach AI
- SwiftUI Components: Apple Frameworks
