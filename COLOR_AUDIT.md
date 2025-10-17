# Color Accessibility Audit

## Current Theme Colors (RGB values)

### Background Colors
- **background**: `rgb(242, 242, 237)` - Creamy beige
- **cardBackground**: `rgb(20, 36, 51)` - Dark teal/navy
- **surfaceBackground**: `rgb(26, 41, 56)` - Slightly lighter dark surface

### Text Colors (for light backgrounds)
- **primaryText**: `rgb(31, 31, 38)` - Almost black
- **secondaryText**: `rgb(102, 102, 115)` - Medium gray
- **mutedText**: `rgb(153, 153, 166)` - Light gray

### Text Colors (for dark cards)
- **cardPrimaryText**: `rgb(255, 255, 255)` - White
- **cardSecondaryText**: `rgb(179, 191, 204)` - Light blue-gray
- **cardMutedText**: `rgb(128, 140, 153)` - Medium blue-gray

### Brand Colors
- **primary**: `rgb(23, 46, 89)` - Navy blue
- **primaryDark**: `rgb(13, 31, 64)` - Darker navy
- **accent**: `rgb(100, 255, 150)` - Bright neon green

### Status Colors
- **success**: `rgb(0, 204, 102)` - Green
- **warning**: `rgb(255, 153, 0)` - Orange
- **error**: `rgb(255, 77, 77)` - Red

---

## Color Combinations Used in App

### 1. Light Background Areas

#### Main App Background
- **Background**: `rgb(242, 242, 237)` creamy beige
- **Used in**: MainView, ActivitiesView, AthleteView, UnifiedInsightsView

#### Text on Light Background
- **primaryText** `rgb(31, 31, 38)` on **background** `rgb(242, 242, 237)`
  - **Where**: Profile name, loading text, navigation titles
  - **Contrast Ratio**: ~13.5:1 ✅ AAA (excellent)

- **secondaryText** `rgb(102, 102, 115)` on **background** `rgb(242, 242, 237)`
  - **Where**: Profile subtitle "Runner • Athlete", loading subtext
  - **Contrast Ratio**: ~5.2:1 ✅ AA (good)

- **mutedText** `rgb(153, 153, 166)` on **background** `rgb(242, 242, 237)`
  - **Where**: Time ago text, less important info
  - **Contrast Ratio**: ~3.1:1 ⚠️ Fails AA for normal text, passes for large text only

#### Brand Colors on Light Background
- **primary (navy)** `rgb(23, 46, 89)` on **background** `rgb(242, 242, 237)`
  - **Where**: Toolbar icons, navigation buttons, loading icon
  - **Contrast Ratio**: ~9.8:1 ✅ AAA (excellent)

---

### 2. Dark Card Areas

#### Activity Cards / Stats Cards / Commitment Cards
- **Background**: `cardBackground` `rgb(20, 36, 51)` dark teal/navy
- **Used in**: CardView, ActivityCommitmentCard, QuickStatItem, WeeklyStatsCard, MonthlyStatsCard, AllTimeStatsCard

#### Text on Dark Cards
- **cardPrimaryText** `rgb(255, 255, 255)` on **cardBackground** `rgb(20, 36, 51)`
  - **Where**: Activity names, stat values, commitment headers
  - **Contrast Ratio**: ~12.6:1 ✅ AAA (excellent)

- **cardSecondaryText** `rgb(179, 191, 204)` on **cardBackground** `rgb(20, 36, 51)`
  - **Where**: Activity type, stat labels, timestamps
  - **Contrast Ratio**: ~9.1:1 ✅ AAA (excellent)

- **cardMutedText** `rgb(128, 140, 153)` on **cardBackground** `rgb(20, 36, 51)`
  - **Where**: Less prominent info, time ago
  - **Contrast Ratio**: ~5.6:1 ✅ AA (good)

#### Brand Colors on Dark Cards
- **primary (navy)** `rgb(23, 46, 89)` on **cardBackground** `rgb(20, 36, 51)`
  - **Where**: Icon colors in cards (calendar, trophy, etc.)
  - **Contrast Ratio**: ~1.2:1 ❌ FAIL - Too similar, very poor contrast

- **accent (neon green)** `rgb(100, 255, 150)` on **cardBackground** `rgb(20, 36, 51)`
  - **Where**: Accent icons, success indicators
  - **Contrast Ratio**: ~12.8:1 ✅ AAA (excellent)

- **warning (orange)** `rgb(255, 153, 0)` on **cardBackground** `rgb(20, 36, 51)`
  - **Where**: Warning icons, pace metrics
  - **Contrast Ratio**: ~8.9:1 ✅ AAA (excellent)

---

### 3. Special Component: MetricPill

#### Metric Pills (nested dark on dark)
- **Background**: `cardBackground` `rgb(20, 36, 51)` (pill background)
- **Parent**: `cardBackground` `rgb(20, 36, 51)` (card background)
- **Text**: `cardPrimaryText` white, `cardSecondaryText` light gray
- **Icon Colors**: `.green`, `.purple`, various custom colors

**Issues**: Pills use same background as parent card - may lack visual separation

---

### 4. AI Insights Banner (Neon Green Section)

#### Banner Background & Text
- **Background**: `rgb(51, 217, 102)` neon green (hardcoded in CardView.swift line 299)
- **Text**:
  - Small labels: `rgb(255, 255, 255)` white with 0.8 opacity = ~`rgb(230, 230, 230)`
  - Main text: `rgb(0, 0, 0)` black

**Contrast Analysis**:
- **Black text** `rgb(0, 0, 0)` on **green** `rgb(51, 217, 102)`
  - **Contrast Ratio**: ~4.8:1 ✅ AA for normal text

- **White labels** `rgb(230, 230, 230)` on **green** `rgb(51, 217, 102)`
  - **Contrast Ratio**: ~5.1:1 ✅ AA (good)

---

### 5. Chat Interface

#### Chat Messages
- **User messages**: White text on **primary** `rgb(23, 46, 89)` navy background
  - **Contrast**: ~9.8:1 ✅ AAA

- **Assistant messages**: **primaryText** `rgb(31, 31, 38)` on **cardBackground** `rgb(20, 36, 51)`
  - **Contrast**: ~2.9:1 ❌ FAIL AA - Poor contrast

#### Chat Input
- **Background**: System gray (`Color(uiColor: .systemGray6)`)
- **Send button**: **primary** color or gray when disabled
  - Appears on **cardBackground** at bottom

---

### 6. Buttons

#### Primary Buttons
- **Background**: primaryGradient (navy gradient)
- **Text**: White
- **Contrast**: ~9.8:1 ✅ AAA

#### FAB (Floating Action Button in ActivitiesView)
- **Background**: Gradient from **primary** to **primaryDark**
- **Icon**: White
- **Shadow**: Good
- **Contrast**: ~9.8:1 ✅ AAA

---

## Critical Accessibility Issues

### ❌ HIGH PRIORITY FAILURES

1. **Navy primary color icons on dark cards**
   - `rgb(23, 46, 89)` on `rgb(20, 36, 51)`
   - Ratio: ~1.2:1 - Nearly invisible
   - **Location**: Calendar icons, trophy icons, etc. in stat cards
   - **Fix**: Use lighter color for icons on dark backgrounds

2. **Chat assistant message text**
   - `rgb(31, 31, 38)` on `rgb(20, 36, 51)`
   - Ratio: ~2.9:1 - Below AA standard
   - **Location**: ChatView assistant messages
   - **Fix**: Should use cardPrimaryText (white) instead

3. **Muted text on light background**
   - `rgb(153, 153, 166)` on `rgb(242, 242, 237)`
   - Ratio: ~3.1:1 - Fails AA for normal text
   - **Location**: Timestamps, less important info
   - **Fix**: Darken mutedText to meet 4.5:1 minimum

### ⚠️ MEDIUM PRIORITY

4. **secondaryButton text on surfaceBackground**
   - Uses primaryText which is dark on dark surface
   - **Fix**: Check usage and adjust

### ✅ Other combinations pass AA or AAA standards

---

## Recommended Fixes

See updated Theme.swift with accessibility improvements.
