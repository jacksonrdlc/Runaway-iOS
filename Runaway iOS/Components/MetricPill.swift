import SwiftUI

// MARK: - Metric Pill Component
struct MetricPill: View {
    let icon: String
    let value: String
    let unit: String
    let color: Color

    private var colors: (textPrimary: Color, textSecondary: Color, surface: Color) {
        if ThemeManager.shared.isDarkMode {
            return (
                AppTheme.Colors.DarkMode.textPrimary,
                AppTheme.Colors.DarkMode.textSecondary,
                AppTheme.Colors.DarkMode.surfaceBackground
            )
        } else {
            return (
                ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary,
                ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary,
                ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.surfaceBackground : AppTheme.Colors.LightMode.surfaceBackground
            )
        }
    }

    var body: some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)

            HStack(alignment: .bottom, spacing: 1) {
                Text(value)
                    .font(AppTheme.Typography.caption.weight(.semibold))
                    .foregroundColor(colors.textPrimary)

                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption2)
                        .foregroundColor(colors.textSecondary)
                }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.sm)
        .padding(.vertical, AppTheme.Spacing.sm)
        .frame(minHeight: 44)
        .background(colors.surface)
        .cornerRadius(AppTheme.CornerRadius.large)
    }
}