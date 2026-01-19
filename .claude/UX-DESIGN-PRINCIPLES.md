# Runaway UX Design Principles

**Status:** Active - These principles MUST be considered for all UI/UX decisions.

---

## Core Philosophy: Glanceable Data with Progressive Disclosure

Runaway prioritizes **scannable information architecture** with **adaptive visual density** based on user context. Information should be instantly comprehensible at a glance, with depth available on demand.

---

## Three-Tier Information Architecture

Every piece of data in Runaway should be designed for three consumption contexts:

### Tier 1: Glance (Widget / Watch / Lock Screen)
- **Single key metric** - the one number that matters most right now
- Maximum 1-2 data points
- Large, bold typography readable at arm's length
- No interaction required to understand
- Examples: Today's mileage, current streak, next workout

### Tier 2: Quick View (App Home / Dashboard)
- **3-5 primary stats** with trend indicators
- Scannable in 2-3 seconds
- Visual hierarchy guides eye to most important info first
- Trend arrows/colors show direction without requiring thought
- Examples: Weekly summary card, training load indicator, recent activity list

### Tier 3: Deep Dive (Detail Screens / Analysis)
- Full historical context and insights
- Interactive charts and filters
- Comparative analysis (vs last week, vs PR, vs plan)
- Only shown when user explicitly requests depth
- Examples: Activity detail view, performance analytics, training history

---

## Context-Aware Design

### During Active Runs (Motion Context)
- **Larger touch targets** (minimum 60pt, prefer 80pt+)
- **Simplified UI** - remove all non-essential elements
- **High contrast** for outdoor visibility
- **Reduced cognitive load** - no decisions required
- **Haptic feedback** for confirmations
- Single-tap actions only (no swipes or long-press)

### Post-Workout / Stationary Context
- Standard touch targets (44pt minimum)
- Full analytics and insights available
- Comparative data and trends
- Edit/annotation capabilities
- Share and export options

### Recovery / Rest Day Context
- Emphasize recovery metrics
- Suggest light activities
- Show streak maintenance options
- Celebrate rest as part of training

---

## Smart Metric Prioritization

Surface the most relevant data based on training phase:

| Training Phase | Primary Metrics | Secondary Metrics |
|----------------|-----------------|-------------------|
| **Base Building** | Weekly mileage, consistency streak | Easy pace compliance, heart rate zones |
| **Race Prep** | Workout quality, race pace progress | Taper compliance, readiness score |
| **Recovery** | Rest days taken, sleep quality | HRV trends, fatigue indicators |
| **Maintenance** | Activity frequency, variety | Enjoyment metrics, social engagement |

---

## Progressive Disclosure in Data Visualization

### Charts and Graphs
1. **Default view:** Simplified trend (sparkline or single stat)
2. **First tap:** Expanded view with labeled axes and key data points
3. **Second tap/interaction:** Full breakdown with filters, comparisons, and details

### Metric Cards
1. **Collapsed:** Single value with trend indicator
2. **Expanded:** Value + context (vs average, vs goal, vs last period)
3. **Detail sheet:** Historical chart + insights + related metrics

---

## Visual Design Guidelines

### Typography Hierarchy
```
Headline (Glance): SF Pro Display Bold, 34-48pt
Primary Stat: SF Pro Display Semibold, 24-32pt
Secondary Stat: SF Pro Text Medium, 17-20pt
Supporting Text: SF Pro Text Regular, 13-15pt
Caption/Label: SF Pro Text Regular, 11-13pt
```

### Spacing System
- Base unit: 8pt
- Compact context (active run): 4pt base
- Standard context: 8pt base
- Comfortable context (analysis): 12pt base

### Color Usage
- **Primary metrics:** High contrast (white on dark, black on light)
- **Positive trends:** System green (`Color.green`)
- **Negative trends:** System red (`Color.red`)
- **Neutral/stable:** System gray
- **Interactive elements:** App accent color

### Touch Targets
- **Minimum:** 44x44pt (Apple HIG standard)
- **Preferred:** 48x48pt
- **Active run context:** 60x60pt minimum, 80x80pt preferred

---

## Component Patterns

### Metric Card (Reusable)
Every metric display should use a consistent card pattern:
- Value prominently displayed
- Label below or beside value
- Trend indicator (arrow + percentage or sparkline)
- Tap to expand for context
- Responds to size class changes

### Responsive Layouts
- Use `GeometryReader` for adaptive sizing
- Implement size class awareness (`@Environment(\.horizontalSizeClass)`)
- Create view modifiers for context-based density
- Test on all device sizes (SE to Pro Max)

### Animation Guidelines
- Chart transitions: 0.3s ease-in-out
- Card expand/collapse: 0.25s spring
- Value changes: 0.2s with number counting effect
- Use `withAnimation` blocks, not implicit animations

---

## Implementation Checklist

When building any new UI component, verify:

- [ ] Works at all three information tiers
- [ ] Adapts to motion/stationary context
- [ ] Follows typography hierarchy
- [ ] Meets touch target requirements
- [ ] Uses progressive disclosure for complex data
- [ ] Tested on smallest (iPhone SE) and largest (Pro Max) devices
- [ ] Supports Dynamic Type accessibility
- [ ] Dark mode compatible
- [ ] VoiceOver accessible with meaningful labels

---

## Anti-Patterns to Avoid

1. **Information overload on home screen** - If you show everything, nothing stands out
2. **Requiring precision taps during runs** - Users are moving and sweaty
3. **Hiding critical data behind multiple taps** - Glanceable means visible immediately
4. **Inconsistent metric cards** - Every stat should look/behave the same way
5. **Static layouts** - Everything should adapt to context and device
6. **Decorative animations** - Every animation should convey meaning or aid comprehension
7. **Text-heavy explanations** - Use visual hierarchy and icons instead

---

## Resources

- [Apple Human Interface Guidelines - Charts](https://developer.apple.com/design/human-interface-guidelines/charts)
- [Apple Charts Framework Documentation](https://developer.apple.com/documentation/charts)
- [Material Design - Data Visualization](https://m3.material.io/styles/data-visualization)
- [Fitbit Design Language](https://design.fitbit.com/) (competitor reference)

---

*Last updated: January 2026*
*These principles should evolve as we learn from user feedback and usage patterns.*
