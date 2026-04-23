import SwiftUI

// MARK: - Eyebrow Label
// Uppercase section marker. Matches CSS .t-eyebrow: 13px semibold, 0.14em tracking.
struct EyebrowLabel: View {
    let text: String
    var color: Color = AppTheme.Colors.textTertiary

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .tracking(1.68) // 0.14em × 12px
            .foregroundColor(color)
    }
}

// MARK: - Activity Type Disc
// Tinted rounded-rect background with a type-colored SF Symbol icon.
// Used in activity rows, dashboard, and activity detail screens.
struct ActivityTypeDisc: View {
    let activityType: String
    var size: CGFloat = 44
    var iconSize: CGFloat = 20
    var cornerRadius: CGFloat = AppTheme.CornerRadius.medium

    private var color: Color {
        AppTheme.Colors.activityColor(for: activityType)
    }

    private var symbol: String {
        switch activityType.lowercased() {
        case "run", "trail run", "trailrun", "virtual run": return "figure.run"
        case "walk":                                        return "figure.walk"
        case "hike":                                        return "mountain.2"
        case "bike", "ride", "cycling":                     return "bicycle"
        case "swim", "swimming":                            return "figure.pool.swim"
        case "weight training", "weighttraining", "workout": return "dumbbell"
        case "yoga":                                        return "figure.yoga"
        default:                                            return "figure.mixed.cardio"
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(color.opacity(0.16))
                .frame(width: size, height: size)
            Image(systemName: symbol)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundColor(color)
        }
    }
}

// MARK: - Filter Chip
// Pill-shaped filter toggle. Active state: amber tint bg + amber border + amber-light text.
struct FilterChip: View {
    let label: String
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(isActive ? AppTheme.Colors.amberLight : AppTheme.Colors.textSecondary)
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.xs + 2)
                .background(
                    Capsule().fill(isActive
                        ? AppTheme.Colors.warmAmber.opacity(0.16)
                        : Color.white.opacity(0.04))
                )
                .overlay(
                    Capsule().stroke(isActive
                        ? AppTheme.Colors.warmAmber.opacity(0.3)
                        : AppTheme.Colors.Semantic.border,
                        lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .frame(minHeight: AppTheme.Layout.touchTargetMinimum)
    }
}

// MARK: - PR Badge
// Small amber pill badge used on activities that set a personal record.
struct PRBadge: View {
    var body: some View {
        Text("PR")
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .tracking(1.0)
            .foregroundColor(AppTheme.Colors.warmAmber)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(AppTheme.Colors.warmAmber.opacity(0.2))
            .cornerRadius(AppTheme.CornerRadius.tiny)
    }
}

// MARK: - Today Badge
// Small filled amber badge used on the current day's training session.
struct TodayBadge: View {
    var body: some View {
        Text("TODAY")
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .tracking(0.8)
            .foregroundColor(Color(red: 0.10, green: 0.05, blue: 0))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(AppTheme.Colors.warmAmber)
            .cornerRadius(AppTheme.CornerRadius.tiny)
    }
}

// MARK: - Mini Stat Tile
// Three-across compact stat tile used in Activity Detail hero row.
struct MiniStatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppTheme.Colors.DarkMode.surfaceBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Account Row
// Settings-style row: icon disc + label + subtitle + chevron. Used in Profile ACCOUNT section.
struct AccountRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppTheme.Colors.DarkMode.surfaceBackground)
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.warmAmber)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(AppTheme.Colors.DarkMode.cardBackground)
            .frame(minHeight: 56)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Lifetime Stat Tile
// One cell in the 3-column Profile lifetime stats row.
struct LifetimeStatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.Colors.warmAmber)
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(1.2)
                .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

// MARK: - Trend Chip
// Inline percentage change indicator. Positive values are green, negative are red.
// Design rule: one amber element per viewport section — use this for non-primary metrics.
struct TrendChip: View {
    let percentage: Double
    var showArrow: Bool = true

    private var isPositive: Bool { percentage >= 0 }
    private var chipColor: Color { isPositive ? AppTheme.Colors.success : AppTheme.Colors.error }
    private var label: String {
        let sign = isPositive ? "+" : ""
        return "\(sign)\(Int(percentage.rounded()))%"
    }

    var body: some View {
        HStack(spacing: 3) {
            if showArrow {
                Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 8, weight: .bold))
            }
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundColor(chipColor)
        .padding(.horizontal, AppTheme.Spacing.sm)
        .padding(.vertical, 4)
        .background(chipColor.opacity(0.18))
        .cornerRadius(6)
    }
}
