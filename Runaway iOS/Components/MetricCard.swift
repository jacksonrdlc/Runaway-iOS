//
//  MetricCard.swift
//  Runaway iOS
//
//  Reusable metric display component following UX Design Principles.
//  Implements Tier 2 Quick View pattern with consistent styling.
//

import SwiftUI

// MARK: - Metric Card Style

/// Defines the visual style of the metric card
enum MetricCardStyle {
    /// Large value with unit, icon + label, card background (32pt value)
    case primary
    /// Medium value with label, subtle card background (headline value)
    case secondary
    /// Compact inline display without background (for use in rows)
    case inline
    /// Inline with primary sizing (larger text, no background)
    case inlinePrimary
}

// MARK: - Metric Card

/// Reusable component for displaying metrics consistently across the app.
/// Follows the three-tier information architecture from UX-DESIGN-PRINCIPLES.md
struct MetricCard: View {
    let value: String
    var unit: String? = nil
    let label: String
    var icon: String? = nil
    var style: MetricCardStyle = .primary
    var trend: Double? = nil

    @ObservedObject private var themeManager = ThemeManager.shared

    // MARK: - Theme Colors

    private var textPrimary: Color {
        AppTheme.Colors.adaptiveTextPrimary
    }

    private var textSecondary: Color {
        AppTheme.Colors.adaptiveTextSecondary
    }

    private var textTertiary: Color {
        AppTheme.Colors.adaptiveTextTertiary
    }

    private var cardBackground: Color {
        switch style {
        case .primary:
            return themeManager.isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.04)
        case .secondary:
            return themeManager.isDarkMode ? Color.white.opacity(0.05) : Color.black.opacity(0.03)
        case .inline, .inlinePrimary:
            return .clear
        }
    }

    // MARK: - Body

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .padding(.vertical, verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(cardBackground)
            )
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        VStack(spacing: contentSpacing) {
            // Value + Unit row
            HStack(alignment: .lastTextBaseline, spacing: unitSpacing) {
                Text(value)
                    .font(valueFont)
                    .fontWeight(.bold)
                    .foregroundColor(textPrimary)
                    .monospacedDigit()

                if let unit = unit {
                    Text(unit)
                        .font(unitFont)
                        .fontWeight(.medium)
                        .foregroundColor(textSecondary)
                }

                // Trend indicator (if provided)
                if let trend = trend {
                    trendBadge(trend: trend)
                }
            }

            // Label + Icon row
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(iconFont)
                }
                Text(label)
                    .font(labelFont)
            }
            .foregroundColor(labelColor)
        }
    }

    // MARK: - Trend Badge

    @ViewBuilder
    private func trendBadge(trend: Double) -> some View {
        let isPositive = trend >= 0
        let trendColor = isPositive ? AppTheme.Colors.success : AppTheme.Colors.error
        let arrow = isPositive ? "arrow.up.right" : "arrow.down.right"
        let percentage = abs(trend * 100)

        HStack(spacing: 2) {
            Image(systemName: arrow)
                .font(.system(size: 8, weight: .bold))
            Text(String(format: "%.0f%%", percentage))
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundColor(trendColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(trendColor.opacity(0.15))
        .cornerRadius(4)
    }

    // MARK: - Style-based Properties

    private var valueFont: Font {
        switch style {
        case .primary:
            return .system(size: 32, weight: .bold, design: .rounded)
        case .secondary:
            return .headline
        case .inline:
            return AppTheme.Typography.title2
        case .inlinePrimary:
            return AppTheme.Typography.title
        }
    }

    private var unitFont: Font {
        switch style {
        case .primary:
            return .subheadline
        case .secondary:
            return .caption
        case .inline, .inlinePrimary:
            return AppTheme.Typography.caption
        }
    }

    private var labelFont: Font {
        switch style {
        case .primary:
            return .caption
        case .secondary:
            return .caption2
        case .inline, .inlinePrimary:
            return AppTheme.Typography.caption
        }
    }

    private var iconFont: Font {
        switch style {
        case .primary:
            return .caption
        case .secondary:
            return .caption2
        case .inline, .inlinePrimary:
            return .system(size: 10)
        }
    }

    private var labelColor: Color {
        switch style {
        case .primary, .secondary:
            return textSecondary
        case .inline, .inlinePrimary:
            return textTertiary
        }
    }

    private var contentSpacing: CGFloat {
        switch style {
        case .primary:
            return 8
        case .secondary:
            return 4
        case .inline, .inlinePrimary:
            return 4
        }
    }

    private var unitSpacing: CGFloat {
        switch style {
        case .primary:
            return 4
        case .secondary, .inline, .inlinePrimary:
            return 2
        }
    }

    private var verticalPadding: CGFloat {
        switch style {
        case .primary:
            return 16
        case .secondary:
            return 12
        case .inline, .inlinePrimary:
            return 0
        }
    }

    private var cornerRadius: CGFloat {
        switch style {
        case .primary:
            return 16
        case .secondary:
            return 12
        case .inline, .inlinePrimary:
            return 0
        }
    }
}

// MARK: - Convenience Initializers

extension MetricCard {
    /// Creates a primary metric card with all options
    static func primary(
        value: String,
        unit: String,
        label: String,
        icon: String,
        trend: Double? = nil
    ) -> MetricCard {
        MetricCard(
            value: value,
            unit: unit,
            label: label,
            icon: icon,
            style: .primary,
            trend: trend
        )
    }

    /// Creates a secondary metric card (compact)
    static func secondary(
        value: String,
        label: String
    ) -> MetricCard {
        MetricCard(
            value: value,
            label: label,
            style: .secondary
        )
    }

    /// Creates an inline metric (no background)
    static func inline(
        value: String,
        unit: String? = nil,
        label: String,
        icon: String,
        isPrimary: Bool = false
    ) -> MetricCard {
        MetricCard(
            value: value,
            unit: unit,
            label: label,
            icon: icon,
            style: isPrimary ? .inlinePrimary : .inline
        )
    }
}

// MARK: - Preview

#Preview("Primary Style") {
    VStack(spacing: 16) {
        HStack(spacing: 16) {
            MetricCard.primary(
                value: "5.23",
                unit: "mi",
                label: "Distance",
                icon: "point.topleft.down.to.point.bottomright.curvepath"
            )

            MetricCard.primary(
                value: "8:42",
                unit: "/mi",
                label: "Pace",
                icon: "speedometer"
            )
        }
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}

#Preview("Secondary Style") {
    HStack(spacing: 12) {
        MetricCard.secondary(value: "8:30", label: "Avg Pace")
        MetricCard.secondary(value: "7.5", label: "Speed (mph)")
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}

#Preview("Inline Style") {
    HStack(spacing: 16) {
        MetricCard.inline(
            value: "12.5",
            unit: "mi",
            label: "Distance",
            icon: "road.lanes",
            isPrimary: true
        )

        Divider().frame(height: 40)

        MetricCard.inline(
            value: "3",
            label: "Activities",
            icon: "figure.run"
        )

        Divider().frame(height: 40)

        MetricCard.inline(
            value: "1h 45m",
            label: "Time",
            icon: "clock"
        )
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}

#Preview("With Trend") {
    MetricCard(
        value: "15.2",
        unit: "mi",
        label: "This Week",
        icon: "road.lanes",
        style: .primary,
        trend: 0.23
    )
    .padding()
    .background(Color.gray.opacity(0.1))
}

// MARK: - Compact Metric Card (used in ActivityDetailView grid)

struct CompactMetricCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.Colors.adaptiveTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.caption2)
                .foregroundColor(AppTheme.Colors.adaptiveTextTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(AppTheme.Colors.adaptiveCardBackground)
        .cornerRadius(AppTheme.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}
