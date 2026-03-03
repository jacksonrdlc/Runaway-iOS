//
//  WeeklyStatsCard.swift
//  Runaway iOS
//
//  Tier 2 dashboard component showing weekly summary statistics
//  Implements glanceable data hierarchy per UX-DESIGN-PRINCIPLES.md
//

import SwiftUI

// MARK: - Weekly Stats Card

/// Tier 2 Quick View component for the dashboard
/// Shows 3-5 primary stats with trend indicators, scannable in 2-3 seconds
struct WeeklyStatsCard: View {
    @Environment(DataManager.self) var dataManager
    @ObservedObject private var goalStore = GoalSettingsStore.shared
    @ObservedObject private var themeManager = ThemeManager.shared

    // MARK: - Computed Stats

    private var weeklyStats: WeeklyActivityStats {
        WeeklyActivityStats(activities: dataManager.activities)
    }

    private var weeklyGoal: Double {
        goalStore.settings.weeklyGoalMiles
    }

    private var goalProgress: Double {
        guard weeklyGoal > 0 else { return 0 }
        return min(weeklyStats.totalMiles / weeklyGoal, 1.0)
    }

    // MARK: - Theme Colors

    private var cardBackground: Color {
        themeManager.isDarkMode ? AppTheme.Colors.DarkMode.cardBackground : AppTheme.Colors.LightMode.cardBackground
    }

    private var textPrimary: Color {
        themeManager.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary
    }

    private var textSecondary: Color {
        themeManager.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary
    }

    private var textTertiary: Color {
        themeManager.isDarkMode ? AppTheme.Colors.DarkMode.textTertiary : AppTheme.Colors.LightMode.textTertiary
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            // Header
            headerSection

            // Main stats row
            mainStatsRow

            // Goal progress bar
            goalProgressSection
        }
        .padding(AppTheme.Spacing.lg)
        .background(cardBackground)
        .cornerRadius(AppTheme.CornerRadius.large)
        .shadow(
            color: themeManager.isDarkMode ? Color.black.opacity(0.3) : Color.black.opacity(0.08),
            radius: 8,
            x: 0,
            y: 4
        )
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("This Week")
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(textPrimary)

                Text(weekDateRange)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(textTertiary)
            }

            Spacer()

            // Week-over-week trend
            if let trend = weeklyStats.weekOverWeekTrend {
                trendBadge(trend: trend)
            }
        }
    }

    private var weekDateRange: String {
        let calendar = Calendar.current
        let today = Date()
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else {
            return ""
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let startStr = formatter.string(from: weekStart)
        let endStr = formatter.string(from: today)
        return "\(startStr) - \(endStr)"
    }

    @ViewBuilder
    private func trendBadge(trend: Double) -> some View {
        let isPositive = trend >= 0
        let trendColor = isPositive ? AppTheme.Colors.success : AppTheme.Colors.error
        let arrow = isPositive ? "arrow.up.right" : "arrow.down.right"
        let percentage = abs(trend * 100)

        HStack(spacing: 4) {
            Image(systemName: arrow)
                .font(.system(size: 10, weight: .bold))
            Text(String(format: "%.0f%%", percentage))
                .font(AppTheme.Typography.caption)
                .fontWeight(.semibold)
        }
        .foregroundColor(trendColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(trendColor.opacity(0.15))
        .cornerRadius(AppTheme.CornerRadius.small)
    }

    // MARK: - Main Stats Row

    private var mainStatsRow: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            // Primary: Distance
            statItem(
                value: UnitFormatter.formatDistance(weeklyStats.totalMeters, decimals: 1, includeUnit: false),
                unit: UnitFormatter.distanceUnitAbbreviation,
                label: "Distance",
                icon: "road.lanes",
                isPrimary: true
            )

            Divider()
                .frame(height: 40)

            // Activities count
            statItem(
                value: "\(weeklyStats.activityCount)",
                unit: nil,
                label: "Activities",
                icon: "figure.run",
                isPrimary: false
            )

            Divider()
                .frame(height: 40)

            // Time
            statItem(
                value: formatDuration(weeklyStats.totalSeconds),
                unit: nil,
                label: "Time",
                icon: "clock",
                isPrimary: false
            )
        }
    }

    @ViewBuilder
    private func statItem(value: String, unit: String?, label: String, icon: String, isPrimary: Bool) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(isPrimary ? AppTheme.Typography.title : AppTheme.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundColor(textPrimary)
                    .monospacedDigit()

                if let unit = unit {
                    Text(unit)
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(textSecondary)
                }
            }

            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(label)
                    .font(AppTheme.Typography.caption)
            }
            .foregroundColor(textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    // MARK: - Goal Progress Section

    private var goalProgressSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Weekly Goal")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(textSecondary)

                Spacer()

                Text("\(UnitFormatter.formatDistance(weeklyStats.totalMeters, decimals: 1, includeUnit: false)) / \(Int(UnitFormatter.metersToPreferredUnit(weeklyGoal * 1609.34))) \(UnitFormatter.distanceUnitAbbreviation)")
                    .font(AppTheme.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(textPrimary)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppTheme.Colors.Semantic.progressTrack)
                        .frame(height: 8)

                    // Fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(progressColor)
                        .frame(width: geometry.size.width * goalProgress, height: 8)
                }
            }
            .frame(height: 8)

            // Progress percentage or completion message
            HStack {
                if goalProgress >= 1.0 {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppTheme.Colors.success)
                    Text("Goal achieved!")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.success)
                } else {
                    let remaining = weeklyGoal - weeklyStats.totalMiles
                    Text("\(UnitFormatter.formatDistance(remaining * 1609.34, decimals: 1, includeUnit: true)) to go")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(textTertiary)
                }

                Spacer()

                Text("\(Int(goalProgress * 100))%")
                    .font(AppTheme.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(textSecondary)
            }
        }
    }

    private var progressColor: Color {
        if goalProgress >= 1.0 {
            return AppTheme.Colors.success
        } else if goalProgress >= 0.75 {
            return AppTheme.Colors.accent
        } else if goalProgress >= 0.5 {
            return AppTheme.Colors.warning
        } else {
            return AppTheme.Colors.accent.opacity(0.7)
        }
    }
}

// MARK: - Weekly Activity Stats Calculator

struct WeeklyActivityStats {
    let totalMeters: Double
    let totalMiles: Double
    let activityCount: Int
    let totalSeconds: Int
    let weekOverWeekTrend: Double?

    init(activities: [Activity]) {
        let calendar = Calendar.current
        let today = Date()

        // Get start of current week (Sunday)
        guard let currentWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else {
            self.totalMeters = 0
            self.totalMiles = 0
            self.activityCount = 0
            self.totalSeconds = 0
            self.weekOverWeekTrend = nil
            return
        }

        // Get start of previous week
        guard let previousWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: currentWeekStart) else {
            self.totalMeters = 0
            self.totalMiles = 0
            self.activityCount = 0
            self.totalSeconds = 0
            self.weekOverWeekTrend = nil
            return
        }

        // Filter current week activities
        let currentWeekActivities = activities.filter { activity in
            guard let activityDate = activity.activity_date ?? activity.start_date else { return false }
            let date = Date(timeIntervalSince1970: activityDate)
            return date >= currentWeekStart && date <= today
        }

        // Filter previous week activities
        let previousWeekActivities = activities.filter { activity in
            guard let activityDate = activity.activity_date ?? activity.start_date else { return false }
            let date = Date(timeIntervalSince1970: activityDate)
            return date >= previousWeekStart && date < currentWeekStart
        }

        // Calculate current week stats
        let currentDistance = currentWeekActivities.reduce(0.0) { $0 + ($1.distance ?? 0) }
        let currentTime = currentWeekActivities.reduce(0) { $0 + Int($1.elapsed_time ?? 0) }

        self.totalMeters = currentDistance
        self.totalMiles = currentDistance / 1609.34
        self.activityCount = currentWeekActivities.count
        self.totalSeconds = currentTime

        // Calculate week-over-week trend
        let previousDistance = previousWeekActivities.reduce(0.0) { $0 + ($1.distance ?? 0) }
        if previousDistance > 0 {
            self.weekOverWeekTrend = (currentDistance - previousDistance) / previousDistance
        } else if currentDistance > 0 {
            self.weekOverWeekTrend = 1.0 // 100% increase if previous was 0
        } else {
            self.weekOverWeekTrend = nil
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        WeeklyStatsCard()
            .padding()
    }
    .background(Color.gray.opacity(0.1))
    .environment(DataManager.shared)
}
