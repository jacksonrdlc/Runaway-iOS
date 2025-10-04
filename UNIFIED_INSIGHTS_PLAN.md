# 📋 Plan: Unified Insights Tab

## Current State Analysis

**Analysis Tab Contains:**
- Performance Dashboard (week vs week)
- Monthly Progress Ring
- AI Analysis with recommendations
- Activity Heatmap
- Pace Trends Chart
- Running Goal Card
- Detailed performance metrics (distance, pace, time, consistency)
- Weekly Volume Chart
- Performance Trend (improving/stable/declining)
- Next Run Prediction

**Quick Wins Tab Contains:**
- Quick Stats Carousel (ACWR, VO2 Max, Temp, Volume)
- Priority Recommendations
- Weather Impact details
- VO2 Max & Race Predictions
- Training Load & ACWR
- 7-Day Workout Plan
- Injury risk monitoring

**Overlap/Duplication:**
- Both have recommendations
- Both show weekly volume
- Both have AI-powered insights
- Both show performance metrics

---

## Proposed Unified Structure

### **Tab Name:** "Insights" (keep the icon: `chart.bar.fill`)

### **Layout:** Scrollable vertical sections

```
┌─────────────────────────────────────┐
│  [Insights Header with Cache Clear] │
├─────────────────────────────────────┤
│                                      │
│  1. HERO SECTION                     │
│     - Quick Stats Carousel           │
│       (4 cards: ACWR, VO2 Max,      │
│        Avg Temp, Weekly Volume)      │
│                                      │
├─────────────────────────────────────┤
│                                      │
│  2. PRIORITY INSIGHTS                │
│     - AI Recommendations Banner      │
│       (expandable, top 3 shown)      │
│     - Performance Status Badge       │
│       (Improving/Stable/Declining)   │
│                                      │
├─────────────────────────────────────┤
│                                      │
│  3. PERFORMANCE AT A GLANCE          │
│     ┌─────────┬─────────┐           │
│     │ Monthly │ Week vs │           │
│     │Progress │  Week   │           │
│     │  Ring   │Comparison│          │
│     └─────────┴─────────┘           │
│                                      │
├─────────────────────────────────────┤
│                                      │
│  4. DEEP DIVE NAVIGATION             │
│     ┌─────────┬─────────┐           │
│     │ Weather │  Race   │           │
│     │ Impact  │Predictions│         │
│     ├─────────┼─────────┤           │
│     │Training │ Activity│           │
│     │  Load   │ Trends  │           │
│     └─────────┴─────────┘           │
│                                      │
├─────────────────────────────────────┤
│                                      │
│  5. CHARTS & ANALYSIS                │
│     - Pace Trends Chart              │
│     - Weekly Volume Chart            │
│     - Activity Heatmap               │
│                                      │
├─────────────────────────────────────┤
│                                      │
│  6. GOAL & READINESS                 │
│     - Running Goal Card              │
│     - Goal Readiness Score           │
│     - Next Run Prediction            │
│                                      │
└─────────────────────────────────────┘
```

---

## Detailed Component Organization

### **Section 1: Hero Section**
**Purpose:** Immediate, at-a-glance metrics
- Quick Stats Carousel (4 horizontal cards):
  - ACWR (with color-coded risk)
  - VO2 Max (with fitness level)
  - Avg Temperature (last 7 days)
  - Weekly Volume (km + mi)

### **Section 2: Priority Insights**
**Purpose:** Most important actionable insights
- **Priority Recommendations Banner:**
  - Shows top 3 AI recommendations
  - Expandable to show all
  - Combines Quick Wins + Local AI recommendations
- **Performance Status Badge:**
  - Large badge showing: "Performance Improving 📈" / "Stable" / "Declining"
  - Tappable for trend details

### **Section 3: Performance at a Glance**
**Purpose:** Quick progress checks
- **2x1 Grid:**
  - **Monthly Progress Ring** (left)
    - Current: `XX.X miles`
    - Goal: `100.0 miles`
    - Status: "Ahead of Target" / "On Track" / "Behind"
  - **Week vs Week Comparison** (right)
    - This week vs last week
    - Distance, pace, time deltas

### **Section 4: Deep Dive Navigation**
**Purpose:** Navigate to detailed analyses
- **2x2 Grid of Navigation Cards:**
  - **Weather Impact** → Opens WeatherImpactView sheet
  - **Race Predictions** → Opens VO2MaxRacingView sheet
  - **Training Load** → Opens TrainingLoadView sheet
  - **Activity Trends** → Opens NEW ActivityTrendsView sheet
    - Contains: Pace trends, heatmap, consistency metrics

### **Section 5: Charts & Analysis**
**Purpose:** Visual data exploration
- **Pace Trends Chart** (line chart)
- **Weekly Volume Chart** (bar chart)
- **Activity Heatmap** (calendar view)
- All collapsible if user wants cleaner view

### **Section 6: Goal & Readiness**
**Purpose:** Goal-specific insights
- **Running Goal Card** (if goal exists)
- **Goal Readiness Score** (circular progress with breakdown)
- **Next Run Prediction** (expected pace range)

---

## Implementation Details

### **What to Keep:**
- ✅ All Quick Wins detail views (Weather, VO2 Max, Training Load)
- ✅ All charts from Analysis tab
- ✅ Monthly Progress Ring
- ✅ Performance Dashboard (week vs week)
- ✅ AI recommendations
- ✅ Activity Heatmap
- ✅ Goal Readiness analysis
- ✅ Next run prediction

### **What to Combine:**
- ✅ Merge AI recommendations from both sources
- ✅ Combine weekly volume displays into one stat
- ✅ Consolidate performance metrics into hero section

### **What to Remove:**
- ❌ Duplicate recommendation lists
- ❌ Redundant volume displays
- ❌ Separate "Analyze" button (make it automatic)

### **New Components:**
- 🆕 **ActivityTrendsView** sheet (for pace trends + heatmap detail)
- 🆕 **Performance Status Badge** (large, tappable)
- 🆕 **Unified Recommendations** (merges Quick Wins + local AI)

---

## User Experience Flow

### **First Load:**
1. Show Quick Stats Carousel immediately (cached data if available)
2. Load local performance metrics (fast)
3. Fetch Quick Wins data in background
4. Update recommendations when both complete

### **Pull-to-Refresh:**
1. Refresh Quick Wins API data
2. Reanalyze local performance
3. Update all sections

### **Navigation:**
- Tap any stat card → Opens relevant detail view
- Tap navigation cards → Opens full-screen sheet with deep dive
- All sheets have "Done" button to return

---

## Benefits

✅ **Eliminates Duplication:** One source of truth for insights
✅ **Better Organization:** Logical flow from quick stats → deep dives
✅ **Improved UX:** Less tab switching, more cohesive experience
✅ **Cleaner UI:** Progressive disclosure - details available when needed
✅ **Faster Load:** Combines data fetching, reduces redundant API calls
✅ **More Space:** Removes one tab, could add something else later

---

## Migration Strategy

### **Phase 1: Create New Unified View**
- Build `UnifiedInsightsView.swift`
- Reuse existing components from both tabs
- Create new `ActivityTrendsView.swift` sheet
- Test with existing data

### **Phase 2: Update Navigation**
- Replace "Analysis" tab with new "Insights" tab
- Remove old "Insights" (Quick Wins) tab
- Update tab indices in MainView

### **Phase 3: Polish**
- Add loading states for sections
- Optimize data fetching
- Add analytics tracking
- Test edge cases (no data, API errors, etc.)

---

## File Structure

```
Views/
├── UnifiedInsightsView.swift          [NEW - Main view]
├── Insights/                           [NEW folder]
│   ├── HeroStatsSection.swift         [Reuse Quick Stats Carousel]
│   ├── PriorityInsightsSection.swift  [NEW - Merged recommendations]
│   ├── PerformanceGlanceSection.swift [Combine monthly ring + week comparison]
│   ├── DeepDiveNavigationGrid.swift   [2x2 navigation cards]
│   ├── ChartsSection.swift            [Group all charts]
│   ├── GoalReadinessSection.swift     [Goal-specific insights]
│   └── ActivityTrendsView.swift       [NEW - Detail sheet for trends]
│
QuickWins/                              [KEEP - Detail views]
├── WeatherImpactView.swift
├── VO2MaxRacingView.swift
└── TrainingLoadView.swift
```

---

## Component Reuse Map

### From QuickWinsDashboardView:
- `QuickStatsCarousel` → Use as-is in Hero Section
- `PriorityRecommendationsBanner` → Merge with local AI recommendations
- `NavigationCardsGrid` → Adapt for 2x2 Deep Dive Navigation

### From AnalysisView:
- `PerformanceDashboardCard` → Move to Performance at a Glance section
- `MonthlyProgressRing` → Move to Performance at a Glance section
- `ActivityHeatmapCard` → Move to Charts & Analysis section
- `PaceTrendsChart` → Move to Charts & Analysis section
- `WeeklyVolumeChart` → Move to Charts & Analysis section
- `RunningGoalCard` → Move to Goal & Readiness section
- `GoalReadinessCard` → Move to Goal & Readiness section
- `NextRunPredictionCard` → Move to Goal & Readiness section
- `QuickInsightsCard` → Merge into Priority Insights section

### New Components Needed:
1. **UnifiedInsightsView** - Main container
2. **PerformanceStatusBadge** - Large status indicator
3. **UnifiedRecommendationsBanner** - Merges both sources
4. **ActivityTrendsView** - Detail sheet for pace/heatmap

---

## Data Flow

### ViewModel Structure:
```swift
@MainActor
class UnifiedInsightsViewModel: ObservableObject {
    // Data sources
    @Published var quickWinsData: QuickWinsResponse?
    @Published var localAnalysis: AnalysisResults?

    // Loading states
    @Published var isLoadingQuickWins = false
    @Published var isLoadingLocal = false

    // Combined data
    @Published var unifiedRecommendations: [String] = []

    // Services
    private let quickWinsService: QuickWinsService
    private let localAnalyzer: RunningAnalyzer

    func loadAllData(activities: [Activity]) async {
        async let quickWins = loadQuickWins()
        async let local = loadLocalAnalysis(activities: activities)

        _ = await (quickWins, local)
        mergeRecommendations()
    }

    func mergeRecommendations() {
        var combined: [String] = []

        // Add Quick Wins priority recommendations
        if let qw = quickWinsData {
            combined.append(contentsOf: qw.priorityRecommendations)
        }

        // Add local AI recommendations
        if let local = localAnalysis {
            combined.append(contentsOf: local.insights.recommendations)
        }

        // Deduplicate and limit to top 5
        unifiedRecommendations = Array(Set(combined)).prefix(5).map { $0 }
    }
}
```

---

## Loading States

### Empty State:
```
┌─────────────────────────────────────┐
│                                      │
│         📊 No Data Available         │
│                                      │
│  Start logging activities to see     │
│  AI-powered insights and analytics   │
│                                      │
│         [Start Recording]            │
│                                      │
└─────────────────────────────────────┘
```

### Loading State:
- Show skeleton loaders for each section
- Quick Stats: 4 gray cards with shimmer
- Charts: Gray rectangles with shimmer
- Progressive loading: Show local data first, then Quick Wins

### Error State:
- Show error banner at top
- Allow partial data display (show what's available)
- Retry button for failed sections

---

## API Optimization

### Current Issue:
- Two separate data fetches (Quick Wins + Local Analysis)
- Both happen on view load

### Optimization:
1. **Parallel Loading:** Load both simultaneously with `async let`
2. **Smart Caching:**
   - Quick Wins: 1-hour cache (already implemented)
   - Local Analysis: Cache until activities change
3. **Progressive Display:**
   - Show local analysis immediately (fast)
   - Update with Quick Wins when available
4. **Background Refresh:**
   - Refresh Quick Wins in background every hour
   - Don't block UI

---

## Timeline Estimate

### Phase 1: Foundation (2-3 hours)
- [ ] Create `UnifiedInsightsView.swift`
- [ ] Create `UnifiedInsightsViewModel.swift`
- [ ] Set up basic layout structure
- [ ] Import existing components

### Phase 2: Sections (3-4 hours)
- [ ] Build Hero Section (reuse QuickStatsCarousel)
- [ ] Build Priority Insights Section (new)
- [ ] Build Performance at a Glance (combine existing)
- [ ] Build Deep Dive Navigation (adapt existing)
- [ ] Build Charts Section (group existing)
- [ ] Build Goal & Readiness Section (group existing)

### Phase 3: Integration (1 hour)
- [ ] Create `ActivityTrendsView.swift` detail sheet
- [ ] Wire up all navigation
- [ ] Connect data flow
- [ ] Test all interactions

### Phase 4: Navigation Update (30 min)
- [ ] Update `MainView.swift` tabs
- [ ] Remove old Analysis tab
- [ ] Remove old Insights tab
- [ ] Test tab navigation

### Phase 5: Polish (1-2 hours)
- [ ] Add loading states
- [ ] Add error handling
- [ ] Add empty states
- [ ] Test edge cases
- [ ] Performance optimization

**Total Estimate:** 7-10 hours

---

## Testing Checklist

- [ ] Empty state (no activities)
- [ ] Loading state (first load)
- [ ] Error state (API failure)
- [ ] Partial data (only local analysis available)
- [ ] Full data (both sources available)
- [ ] Pull-to-refresh
- [ ] All navigation cards work
- [ ] All detail sheets open/close
- [ ] Cache works correctly
- [ ] Performance (smooth scrolling)
- [ ] Dark mode
- [ ] Different screen sizes
- [ ] Accessibility (VoiceOver)

---

## Future Enhancements (Post-MVP)

- [ ] Add filtering options (date range, activity type)
- [ ] Add export functionality (PDF reports)
- [ ] Add comparison mode (this month vs last month)
- [ ] Add customizable sections (user can reorder)
- [ ] Add widget for home screen
- [ ] Add share functionality
- [ ] Add notification for new insights

---

## Notes

- Keep all existing Quick Wins detail views intact
- Preserve all existing data models
- No breaking changes to API contracts
- Maintain backward compatibility with cache
- Use existing theme/styling conventions
- Follow existing architecture patterns (MVVM)

---

## Questions to Resolve

1. **Recommendations Priority:** Which source should take precedence when merging?
   - **Recommendation:** Quick Wins first (more comprehensive AI), then local

2. **Performance Status Badge:** Where should tap action go?
   - **Recommendation:** Opens bottom sheet with detailed trend analysis

3. **Activity Trends Detail:** What should this include?
   - **Recommendation:** Pace chart, heatmap, consistency score, best/worst runs

4. **Section Collapsibility:** Should sections be collapsible?
   - **Recommendation:** Yes, save state in UserDefaults for user preference

---

## Success Metrics

- Single source of insights (no duplication)
- Faster perceived load time (progressive loading)
- Reduced API calls (merged fetching)
- Better user navigation (clear hierarchy)
- Improved discoverability (all insights in one place)
- Cleaner codebase (fewer redundant components)

---

**Ready to implement!** 🚀
