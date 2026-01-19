# UX Design Principles Audit Report
**Date:** January 2026
**Branch:** `feature/ux-design-system`
**Auditor:** Claude Code

---

## Executive Summary

This audit evaluates Runaway iOS views against the UX Design Principles documented in `/.claude/UX-DESIGN-PRINCIPLES.md`. The app demonstrates **strong foundational design** with notable strengths in theme consistency and typography hierarchy. However, there are **critical gaps** in progressive disclosure, touch target sizing for motion contexts, and dashboard-level information architecture.

| View | Score | Priority Issues |
|------|-------|-----------------|
| ActiveRecordingView | 7.2/10 | Touch targets, cognitive load |
| ActivitiesView (Dashboard) | 6.5/10 | Missing Tier 2 stats, no progressive disclosure |
| Widget | 9.0/10 | Excellent Tier 1 implementation |
| PostRecordingView | 9.2/10 | Exemplary (see previous session) |

---

## Detailed View Audits

---

### 1. ActiveRecordingView.swift

**File:** `Runaway iOS/Views/ActiveRecordingView.swift`
**Lines:** 482
**Context:** Primary view during active workout recording

#### Principle Compliance Analysis

##### Three-Tier Information Architecture

| Tier | Implementation | Assessment |
|------|---------------|------------|
| **Tier 1 (Glance)** | Timer at 64pt (`line 236`) | **GOOD** - Large, readable, monospacedDigit |
| **Tier 2 (Quick View)** | Distance/Pace cards + secondary metrics | **MIXED** - Primary cards good, secondary overwhelms |
| **Tier 3 (Deep Dive)** | None available | **N/A** - Appropriate for recording context |

**Issues Found:**

1. **Secondary metrics grid shows 5 values simultaneously** (`lines 264-281`):
   - Avg Pace
   - Speed
   - GPS Points (when GPS activity)

   Combined with 2 primary metrics (Distance, Pace), users see **7 data points** while running. UX Principles state: "reduced cognitive load - no decisions required" for motion context.

2. **No progressive disclosure** - All metrics visible at once, no tap-to-expand functionality.

##### Touch Targets (Motion Context)

**Principle requirement:** 60pt minimum, 80pt+ preferred during active runs

| Element | Current Size | Location | Assessment |
|---------|-------------|----------|------------|
| Pause/Resume button | 70x70pt | `line 363` | **BELOW STANDARD** - Should be 80pt+ |
| Stop button | 70x70pt | `line 384` | **BELOW STANDARD** - Should be 80pt+ |
| Activity type badge | ~44pt height | `lines 148-161` | **OK** - Not interactive during recording |
| Secondary metric cards | ~40pt height | `lines 315-332` | **NOT TAPPABLE** - No interaction |

**Critical Issue:** Control buttons at 70x70pt are **10pt below the 80pt+ recommendation** for active motion context. During runs with sweaty/gloved fingers, this increases tap failure rate.

##### Context Adaptation

**Strengths:**
- Auto-pause indicator (`lines 336-351`) - Excellent contextual feedback
- Recording state indicator with pulse animation (`lines 166-181`)
- Activity-specific icon and color (`lines 35-59`)
- Timer updates via dedicated `TimerUpdateManager` (`line 22`)

**Gaps:**
- No simplified "racing mode" with minimal UI
- No haptic feedback on button presses (principle: "Haptic feedback for confirmations")
- No adaptive layout for different device sizes

##### Typography Compliance

| Element | Current | Principle Standard | Status |
|---------|---------|-------------------|--------|
| Timer | 64pt bold rounded | 34-48pt headline | **EXCEEDS** (appropriate for hero) |
| Primary metric value | 32pt bold | 24-32pt primary stat | **COMPLIANT** |
| Primary metric label | caption (12pt) | 13-15pt caption | **COMPLIANT** |
| Secondary metric value | headline (~17pt) | 17-20pt secondary | **COMPLIANT** |
| Secondary metric label | caption2 (11pt) | 11-13pt caption | **COMPLIANT** |

##### Spacing Analysis

Current implementation uses:
- `spacing: 24` between timer and icon (`line 206`)
- `spacing: 16` in metrics grid (`line 245`)
- `spacing: 20` between primary cards (`line 247`)
- `spacing: 12` between secondary cards (`line 264`)
- `padding: 20` horizontal (`lines 283, 351, 395`)

**Assessment:** Spacing is consistent with principle's 8pt base system (multiples of 4/8).

#### Specific Code Issues

```swift
// Line 363 - Touch target too small for motion context
.frame(width: 70, height: 70)

// SHOULD BE:
.frame(width: 80, height: 80)
```

```swift
// Lines 264-281 - Information overload
// Shows: Avg Pace, Speed, GPS Points all at once

// RECOMMENDATION: Progressive disclosure
// Show only 1-2 secondary metrics, tap for more
```

#### Recommended Changes

| Priority | Change | Lines Affected |
|----------|--------|----------------|
| **P0** | Increase control buttons to 80x80pt | 363, 384 |
| **P1** | Add haptic feedback on button press | 358, 377 |
| **P1** | Reduce visible secondary metrics to 2 | 264-281 |
| **P2** | Add tap-to-expand for secondary metrics | 315-332 |
| **P2** | Create simplified "focus mode" option | New feature |

---

### 2. ActivitiesView.swift (Dashboard)

**File:** `Runaway iOS/Views/ActivitiesView.swift`
**Lines:** 188
**Context:** Main dashboard/feed showing activity list

#### Principle Compliance Analysis

##### Three-Tier Information Architecture

| Tier | Implementation | Assessment |
|------|---------------|------------|
| **Tier 1 (Glance)** | ActivityCommitmentCard | **PARTIAL** - Only shows commitment, not stats |
| **Tier 2 (Quick View)** | Activity list | **MISSING** - No summary statistics |
| **Tier 3 (Deep Dive)** | ActivityDetailView on tap | **GOOD** - Proper drill-down |

**Critical Gap:** The dashboard **completely lacks Tier 2 summary statistics**. Per UX Principles:

> "Quick View (App home): 3-5 primary stats with trend indicators"

Current dashboard shows:
- ActivityCommitmentCard (commitment tracking only)
- List of activity cards

**Missing elements:**
- Weekly mileage total
- Number of activities this week
- Current streak
- Progress toward weekly/monthly goals
- Trend indicators (up/down arrows)

##### Dashboard Layout Analysis

```swift
// Lines 67-94 - Current structure
ScrollView {
    LazyVStack(spacing: AppTheme.Spacing.md) {
        // Only ActivityCommitmentCard at top
        ActivityCommitmentCard()
            .padding(.horizontal, AppTheme.Spacing.md)

        // Then immediately into activity list
        ForEach(dataManager.activities.indices, id: \.self) { index in
            CardView(...)
        }
    }
}
```

**Issue:** No "WeeklyStatsCard" or "QuickStatsSection" between commitment and activities.

##### Progressive Disclosure

**Current State:** None implemented

- Activity cards are static (no expand/collapse)
- No expandable sections
- All cards same priority visually

**Principle Violation:** "Progressive Disclosure in Charts: Start with simplified trend view, tap to reveal detailed breakdowns"

##### Touch Targets

| Element | Current Size | Assessment |
|---------|-------------|------------|
| FAB (Floating Action Button) | 56pt (`AppTheme.Layout.fabSize`) | **COMPLIANT** - 56pt is good for stationary |
| Activity cards | Full width, implicit | **COMPLIANT** - Easy to tap |
| Refresh button | 44pt (toolbar) | **COMPLIANT** - Apple standard |

##### Empty State Analysis

```swift
// Lines 54-64 - Empty state
ScrollView {
    VStack(spacing: AppTheme.Spacing.lg) {
        ActivityCommitmentCard()
        EmptyActivitiesView()
    }
}
```

**Issue:** Empty state only shows generic message. Should show:
- Weekly/monthly goal progress (even at 0)
- Motivational context
- Quick-start suggestions

##### Recommendations

| Priority | Change | Impact |
|----------|--------|--------|
| **P0** | Add WeeklyStatsCard above activity list | Implements Tier 2 |
| **P0** | Show: Weekly miles, run count, streak | Core dashboard metrics |
| **P1** | Add trend indicators to stats | Visual feedback |
| **P1** | Make stats card tappable for details | Progressive disclosure |
| **P2** | Improve empty state with goals | Better onboarding UX |

**Proposed WeeklyStatsCard Structure:**

```swift
// NEW COMPONENT NEEDED
struct WeeklyStatsCard: View {
    // Tier 2 metrics:
    // - This week: X.X mi (trend arrow)
    // - Activities: N (trend arrow)
    // - Streak: N days
    // - Goal progress: X% of Y mi
}
```

---

### 3. RunawayWidget.swift

**File:** `RunawayWidget/RunawayWidget.swift`
**Lines:** 548
**Context:** Home screen widget for glanceable stats

#### Principle Compliance Analysis

##### Three-Tier Architecture (Tier 1 Focus)

**Assessment: EXCELLENT**

The widget is a **model implementation** of Tier 1 (Glance) principles:

| Element | Implementation | Principle Alignment |
|---------|---------------|---------------------|
| Hero metric | Year total at 40pt Futura Condensed (`line 463`) | **PERFECT** - Single key metric, largest |
| Secondary visual | Weekly bar chart (`line 458`) | **GOOD** - Visual, not text-heavy |
| Tertiary | Pie charts for goals (`lines 467-473`) | **GOOD** - Progress at a glance |
| Context | Location name (`line 453`) | **GOOD** - Provides context |

##### Typography Analysis

```swift
// Line 463 - Hero metric
Text(yearTotalDisplay.thousandsOfMiles)
    .font(.custom("Futura-CondensedExtraBold", fixedSize: 40))

// Line 462 - Label
.font(.system(size: 14, weight: .semibold))

// Lines 468, 472 - Pie chart labels
.font(.system(size: 8, weight: .heavy))
```

**Assessment:** Custom Futura font for hero creates visual distinction. However, 8pt labels for pie charts are **below accessibility guidelines** (11pt minimum recommended).

##### Unit Support

```swift
// Lines 15-47 - WidgetUnitHelper
static var isMetric: Bool {
    guard let savedValue = userDefaults?.string(forKey: unitKey) else {
        return false // Default to imperial (miles)
    }
    return savedValue == "kilometers"
}
```

**EXCELLENT:** Respects user's distance unit preference throughout widget.

##### Empty State Messaging

```swift
// Lines 84-97 - Empty state messages
private var emptyStateMessages: [String] {
    [
        "You better be lacing up your sneakers...",
        "Those running shoes are looking lonely 👟",
        "Time to turn those couch miles into real miles!",
        // ...
    ]
}
```

**Issue:** Messages are **judgmental/shaming** rather than encouraging. Per UX principles, empty states should be motivational, not guilt-inducing.

**Recommended alternatives:**
- "Ready for your first run this week?"
- "Your week is wide open - time to write your story!"
- "Every mile starts with the first step"

##### Visual Density

| Component | Size | Assessment |
|-----------|------|------------|
| Bar chart | Flexible height | **GOOD** - Scales with widget |
| Pie charts | 65pt height (`line 189`) | **ADEQUATE** - Could be larger |
| Year total | 40pt font | **EXCELLENT** - Highly readable |
| Labels | 8-14pt | **MIXED** - Some too small |

##### Data Refresh

```swift
// Lines 231-232 - Timeline refresh
for hourOffset in 0 ..< 5 {
    let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
```

**GOOD:** Refreshes every hour with 5-entry timeline. Appropriate for fitness data that changes infrequently.

##### Recommendations

| Priority | Change | Lines |
|----------|--------|-------|
| **P1** | Replace judgmental empty messages | 84-97 |
| **P2** | Increase pie chart label font to 10pt | 468, 472 |
| **P2** | Add goal achievement indicator (checkmark when met) | New |
| **P3** | Consider tap actions for iOS 17+ widgets | New |

---

## Cross-View Consistency Analysis

### Design System Compliance

#### AppTheme Usage

The codebase has a **comprehensive theme system** in `Utils/Theme.swift` (833 lines) that defines:

- Colors (with Light/Dark mode variants)
- Typography (SF Pro Rounded, 15 size variants)
- Spacing (8pt base system: xxs=2, xs=4, sm=8, md=12, lg=16, xl=20, xxl=24)
- Corner radius (tiny=4 to massive=32)
- Shadows (5 levels + colored glows)
- Layout constants (FAB=56pt, icons, cards)

**Consistency Check:**

| View | Uses AppTheme.Spacing | Uses AppTheme.Typography | Uses AppTheme.Colors |
|------|----------------------|-------------------------|---------------------|
| ActiveRecordingView | Partial (hardcoded 16, 20, 24) | Partial (system fonts inline) | Yes (via themeManager) |
| ActivitiesView | Yes | Yes | Yes |
| Widget | No (standalone) | No (custom fonts) | No (hardcoded) |

**Issue:** ActiveRecordingView uses hardcoded spacing values instead of `AppTheme.Spacing` constants:

```swift
// Line 245 - Hardcoded
VStack(spacing: 16)

// SHOULD BE:
VStack(spacing: AppTheme.Spacing.lg)
```

#### Touch Target Standards

| Context | Principle | AppTheme.Layout | Actual Implementation |
|---------|-----------|-----------------|----------------------|
| Standard | 44pt | Not defined | Varies |
| Pre-activity | 56pt | fabSize=56 | FAB correct |
| Active run | 80pt | Not defined | 70pt (non-compliant) |

**Gap:** `AppTheme.Layout` lacks context-aware touch target constants.

**Recommendation:** Add to Theme.swift:

```swift
struct TouchTargets {
    static let standard: CGFloat = 44
    static let preActivity: CGFloat = 56
    static let activeRun: CGFloat = 80
    static let minimum: CGFloat = 44
}
```

### Metric Card Pattern Analysis

#### Current Implementations

**1. ActiveRecordingView - `primaryMetricCard` (lines 286-313)**
```swift
private func primaryMetricCard(value: String, unit: String, label: String, icon: String) -> some View {
    VStack(spacing: 8) {
        HStack(alignment: .lastTextBaseline, spacing: 4) {
            Text(value).font(.system(size: 32, weight: .bold, design: .rounded))
            Text(unit).font(.subheadline)
        }
        HStack(spacing: 4) {
            Image(systemName: icon).font(.caption)
            Text(label).font(.caption)
        }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 16)
    .background(RoundedRectangle(cornerRadius: 16).fill(...))
}
```

**2. ActiveRecordingView - `secondaryMetricCard` (lines 315-332)**
```swift
private func secondaryMetricCard(value: String, label: String) -> some View {
    VStack(spacing: 4) {
        Text(value).font(.headline)
        Text(label).font(.caption2)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 12)
    .background(RoundedRectangle(cornerRadius: 12).fill(...))
}
```

**Assessment:** These are **local implementations**, not reusable components. Per UX Principles:

> "Metric Card (Reusable): Every metric display should use a consistent card pattern"

**Recommendation:** Create unified `MetricCard` component:

```swift
// Proposed: Components/MetricCard.swift
struct MetricCard: View {
    enum Size { case compact, standard, large }
    enum Context { case stationary, active }

    let value: String
    let label: String
    var unit: String? = nil
    var icon: String? = nil
    var trend: TrendIndicator? = nil
    var size: Size = .standard
    var context: Context = .stationary
}
```

---

## Priority Improvement Matrix

### P0 - Critical (Affects core UX)

| Issue | View | Effort | Impact |
|-------|------|--------|--------|
| Add WeeklyStatsCard to dashboard | ActivitiesView | Medium | High - Implements Tier 2 |
| Increase recording control buttons to 80pt | ActiveRecordingView | Low | High - Accessibility |

### P1 - Important (Improves experience)

| Issue | View | Effort | Impact |
|-------|------|--------|--------|
| Add haptic feedback to recording controls | ActiveRecordingView | Low | Medium |
| Reduce visible secondary metrics | ActiveRecordingView | Low | Medium |
| Replace widget empty state messages | Widget | Low | Medium |
| Create reusable MetricCard component | Global | Medium | High (consistency) |

### P2 - Enhancement (Polish)

| Issue | View | Effort | Impact |
|-------|------|--------|--------|
| Add tap-to-expand for metrics | ActiveRecordingView | Medium | Medium |
| Add touch target constants to AppTheme | Theme.swift | Low | Medium |
| Standardize spacing to use AppTheme | ActiveRecordingView | Low | Low |
| Increase widget pie chart labels | Widget | Low | Low |

### P3 - Future (Nice to have)

| Issue | View | Effort | Impact |
|-------|------|--------|--------|
| Add "focus mode" for minimal recording UI | ActiveRecordingView | High | Medium |
| Add widget tap actions (iOS 17+) | Widget | Medium | Low |
| Implement smart metric prioritization by training phase | Global | High | High |

---

## Implementation Recommendations

### Phase 1: Critical Fixes (1-2 days)

1. **Create WeeklyStatsCard component**
   - Shows: This week miles, activity count, streak, goal %
   - Add to ActivitiesView above activity list
   - Make tappable for detailed weekly view

2. **Fix recording touch targets**
   - Update control buttons from 70pt to 80pt
   - Add `UIImpactFeedbackGenerator` on button press

### Phase 2: Metric Card System (2-3 days)

1. **Create unified MetricCard component**
   - Support compact/standard/large sizes
   - Support trend indicators
   - Support tap-to-expand behavior
   - Context-aware sizing (active vs stationary)

2. **Refactor existing metric displays**
   - ActiveRecordingView primary/secondary cards
   - PostRecordingView CompactMetricCard
   - ActivityDetailView metric grid

### Phase 3: Progressive Disclosure (3-5 days)

1. **Add expansion behavior to metrics**
   - Tap metric to see historical context
   - Show "vs average" and "vs goal" comparisons

2. **Implement training phase awareness**
   - Detect base building vs race prep vs recovery
   - Surface relevant metrics based on phase

---

## Conclusion

Runaway iOS has a **solid design foundation** with excellent theme consistency and good typography choices. The primary gaps are:

1. **Missing Tier 2 dashboard stats** - Users must drill into activities to see summary data
2. **Suboptimal touch targets during recording** - 70pt vs recommended 80pt for motion context
3. **No progressive disclosure** - All metrics shown at once, no expansion behavior
4. **Inconsistent metric card patterns** - Multiple implementations instead of unified component

Addressing P0 and P1 items would significantly improve the app's adherence to the UX Design Principles and create a more glanceable, context-aware experience.

---

*Audit complete. See `/.claude/UX-DESIGN-PRINCIPLES.md` for the principles referenced in this report.*
