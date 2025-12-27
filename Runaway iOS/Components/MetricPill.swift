import SwiftUI

// MARK: - Metric Pill Component
struct MetricPill: View {
    let icon: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)
            
            HStack(alignment: .bottom, spacing: 1) {
                Text(value)
                    .font(AppTheme.Typography.caption.weight(.semibold))
                    .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption2)
                        .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
                }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.sm)
        .padding(.vertical, AppTheme.Spacing.sm)
        .frame(minHeight: 44)
        .background(Color(red: 0.96, green: 0.96, blue: 0.97))
        .cornerRadius(AppTheme.CornerRadius.large)
    }
}