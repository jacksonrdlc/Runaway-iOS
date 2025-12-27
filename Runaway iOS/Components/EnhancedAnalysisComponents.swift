//
//  EnhancedAnalysisComponents.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 9/16/25.
//

import SwiftUI
import Charts

// MARK: - Performance Dashboard Card

struct PerformanceDashboardCard: View {
    let activities: [Activity]

    private var thisWeekStats: WeeklyStats {
        calculateWeeklyStats(for: Date())
    }

    private var lastWeekStats: WeeklyStats {
        let lastWeek = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
        return calculateWeeklyStats(for: lastWeek)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Performance Dashboard")
                        .font(AppTheme.Typography.title)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

                    Text("This week vs last week")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
                }

                Spacer()

                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(AppTheme.Colors.LightMode.accent)
                    .font(.title2)
            }

            // Stats Grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: AppTheme.Spacing.md),
                GridItem(.flexible(), spacing: AppTheme.Spacing.md)
            ], spacing: AppTheme.Spacing.lg) {
                PerformanceMetricCard(
                    title: "Distance",
                    thisWeek: String(format: "%.1f mi", thisWeekStats.totalDistance),
                    lastWeek: String(format: "%.1f mi", lastWeekStats.totalDistance),
                    change: calculatePercentChange(current: thisWeekStats.totalDistance, previous: lastWeekStats.totalDistance),
                    icon: "road.lanes"
                )

                PerformanceMetricCard(
                    title: "Activities",
                    thisWeek: "\(thisWeekStats.activityCount)",
                    lastWeek: "\(lastWeekStats.activityCount)",
                    change: calculatePercentChange(current: Double(thisWeekStats.activityCount), previous: Double(lastWeekStats.activityCount)),
                    icon: "figure.run"
                )

                PerformanceMetricCard(
                    title: "Avg Pace",
                    thisWeek: formatPace(thisWeekStats.averagePace),
                    lastWeek: formatPace(lastWeekStats.averagePace),
                    change: -calculatePercentChange(current: thisWeekStats.averagePace, previous: lastWeekStats.averagePace), // Negative because lower pace is better
                    icon: "speedometer"
                )

                PerformanceMetricCard(
                    title: "Total Time",
                    thisWeek: formatDuration(thisWeekStats.totalTime),
                    lastWeek: formatDuration(lastWeekStats.totalTime),
                    change: calculatePercentChange(current: thisWeekStats.totalTime, previous: lastWeekStats.totalTime),
                    icon: "clock"
                )
            }
        }
        .padding(AppTheme.Spacing.lg)
        .background(AppTheme.Colors.LightMode.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.large)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    private func calculateWeeklyStats(for date: Date) -> WeeklyStats {
        let calendar = Calendar.current
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date)
        let weekStart = weekInterval?.start ?? date
        let weekEnd = weekInterval?.end ?? date

        let weekActivities = activities.filter { activity in
            // Use activity_date first, fall back to start_date
            let dateInterval = activity.activity_date ?? activity.start_date
            guard let dateInterval = dateInterval else { return false }
            let activityDate = Date(timeIntervalSince1970: dateInterval)
            return activityDate >= weekStart && activityDate < weekEnd
        }

        let totalDistance = weekActivities.reduce(0) { $0 + (($1.distance ?? 0) * 0.000621371) }
        let totalTime = weekActivities.reduce(0) { $0 + ($1.elapsed_time ?? 0) }
        let averagePace = totalDistance > 0 ? (totalTime / 60) / totalDistance : 0

        print("📊 PerformanceDashboard: Week stats - Activities: \(weekActivities.count), Distance: \(totalDistance) mi, Time: \(totalTime)s, Pace: \(averagePace)")

        return WeeklyStats(
            totalDistance: totalDistance,
            activityCount: weekActivities.count,
            averagePace: averagePace,
            totalTime: totalTime
        )
    }

    private func calculatePercentChange(current: Double, previous: Double) -> Double {
        // Handle edge cases to prevent NaN/infinite values
        if previous == 0 && current == 0 {
            return 0 // No change if both are zero
        }
        if previous == 0 {
            return 100 // 100% increase if previous was zero but current isn't
        }
        if current.isNaN || previous.isNaN || current.isInfinite || previous.isInfinite {
            return 0 // Safe fallback for invalid values
        }

        let change = ((current - previous) / previous) * 100

        // Cap the change at reasonable values
        return max(-100, min(999, change))
    }
}

// MARK: - Performance Metric Card

struct PerformanceMetricCard: View {
    let title: String
    let thisWeek: String
    let lastWeek: String
    let change: Double
    let icon: String

    private var changeColor: Color {
        if change > 5 { return AppTheme.Colors.success }
        if change < -5 { return AppTheme.Colors.error }
        return AppTheme.Colors.info
    }

    private var changeIcon: String {
        if change > 5 { return "arrow.up.circle.fill" }
        if change < -5 { return "arrow.down.circle.fill" }
        return "minus.circle.fill"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(AppTheme.Colors.LightMode.accent)
                    .font(.title3)

                Spacer()

                Image(systemName: changeIcon)
                    .foregroundColor(changeColor)
                    .font(.caption)
            }

            Spacer()

            Text(thisWeek)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AppTheme.Colors.LightMode.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.caption)
                .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
                .lineLimit(1)

            HStack {
                Spacer()
                Text("\(change >= 0 ? "+" : "")\(String(format: "%.0f", change))%")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(changeColor)
            }
        }
        .padding(AppTheme.Spacing.sm)
        .frame(minHeight: AppTheme.Layout.metricCardMinHeight)
        .background(AppTheme.Colors.LightMode.surfaceBackground)
        .cornerRadius(AppTheme.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                .stroke(changeColor.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Activity Heatmap

struct ActivityHeatmapCard: View {
    let activities: [Activity]

    private var heatmapData: [HeatmapData] {
        let calendar = Calendar.current
        let today = Date()
        let startDate = calendar.date(byAdding: .day, value: -49, to: today) ?? today // Last 50 days

        var data: [HeatmapData] = []

        for i in 0..<50 {
            let date = calendar.date(byAdding: .day, value: i, to: startDate) ?? today
            let dayActivities = activities.filter { activity in
                guard let activityStart = activity.start_date else { return false }
                let activityDate = Date(timeIntervalSince1970: activityStart)
                return calendar.isDate(activityDate, inSameDayAs: date)
            }

            let totalDistance = dayActivities.reduce(0) { $0 + (($1.distance ?? 0) * 0.000621371) }
            let intensity = min(totalDistance / 10.0, 1.0) // Normalize to 0-1 scale

            data.append(HeatmapData(date: date, intensity: intensity, activityCount: dayActivities.count))
        }

        return data
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Activity Heatmap")
                        .font(AppTheme.Typography.title)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

                    Text("Last 50 days of activity intensity")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
                }

                Spacer()

                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(AppTheme.Colors.LightMode.accent)
                    .font(.title2)
            }

            // Heatmap Grid
            let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(heatmapData, id: \.date) { data in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(heatmapColor(for: data.intensity))
                        .frame(height: 16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(AppTheme.Colors.textTertiary.opacity(0.2), lineWidth: 0.5)
                        )
                }
            }

            // Legend
            HStack {
                Text("Less")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.LightMode.textSecondary)

                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { intensity in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(heatmapColor(for: Double(intensity) / 4.0))
                            .frame(width: 12, height: 12)
                    }
                }

                Text("More")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.LightMode.textSecondary)

                Spacer()
            }
        }
        .padding(AppTheme.Spacing.lg)
        .background(AppTheme.Colors.LightMode.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.large)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    private func heatmapColor(for intensity: Double) -> Color {
        if intensity == 0 { return AppTheme.Colors.LightMode.textTertiary.opacity(0.2) }
        if intensity <= 0.25 { return AppTheme.Colors.LightMode.accent.opacity(0.4) }
        if intensity <= 0.5 { return AppTheme.Colors.LightMode.accent.opacity(0.6) }
        if intensity <= 0.75 { return AppTheme.Colors.LightMode.accent.opacity(0.8) }
        return AppTheme.Colors.LightMode.accent
    }
}

// MARK: - Pace Trends Chart

struct PaceTrendsChart: View {
    let activities: [Activity]

    private var paceData: [PaceDataPoint] {
        let runningActivities = activities.filter { activity in
            let activityType = activity.type?.lowercased() ?? ""
            return activityType.contains("run")
        }

        return runningActivities.compactMap { activity -> PaceDataPoint? in
            guard let startDate = activity.start_date,
                  let distance = activity.distance,
                  let elapsedTime = activity.elapsed_time,
                  distance > 0 else { return nil }

            let distanceMiles = distance * 0.000621371
            let pace = (elapsedTime / 60) / distanceMiles // minutes per mile

            return PaceDataPoint(
                date: Date(timeIntervalSince1970: startDate),
                pace: pace,
                distance: distanceMiles
            )
        }
        .sorted { $0.date < $1.date }
        .suffix(20) // Last 20 runs
        .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pace Trends")
                        .font(AppTheme.Typography.title)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

                    Text("Last 20 runs - lower is better")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
                }

                Spacer()

                Image(systemName: "waveform.path.ecg")
                    .foregroundColor(AppTheme.Colors.LightMode.accent)
                    .font(.title2)
            }

            if paceData.count >= 2 {
                Chart(paceData) { dataPoint in
                    LineMark(
                        x: .value("Run", dataPoint.date),
                        y: .value("Pace", dataPoint.pace)
                    )
                    .foregroundStyle(AppTheme.Colors.LightMode.accent)
                    .lineStyle(StrokeStyle(lineWidth: 3))

                    PointMark(
                        x: .value("Run", dataPoint.date),
                        y: .value("Pace", dataPoint.pace)
                    )
                    .foregroundStyle(AppTheme.Colors.LightMode.accent)
                    .symbolSize(40)
                }
                .frame(height: 200)
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let paceValue = value.as(Double.self) {
                                Text(formatPace(paceValue))
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                    }
                }
            } else {
                VStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 40))
                        .foregroundColor(AppTheme.Colors.textTertiary)

                    Text("Need at least 2 runs to show pace trends")
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(AppTheme.Spacing.lg)
        .background(AppTheme.Colors.LightMode.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.large)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Monthly Progress Ring

struct MonthlyProgressRing: View {
    let activities: [Activity]
    @State private var animateProgress = false

    private var monthlyStats: MonthlyStats {
        let currentMonth = Calendar.current.component(.month, from: Date())
        let currentYear = Calendar.current.component(.year, from: Date())

        print("📊 MonthlyProgressRing: Total activities: \(activities.count)")
        print("📊 MonthlyProgressRing: Current month: \(currentMonth), year: \(currentYear)")

        let monthlyActivities = activities.filter { activity in
            // Use activity_date if available, otherwise fall back to start_date
            let dateInterval = activity.activity_date ?? activity.start_date
            guard let dateInterval = dateInterval else { return false }
            let activityDate = Date(timeIntervalSince1970: dateInterval)
            return Calendar.current.component(.month, from: activityDate) == currentMonth &&
                   Calendar.current.component(.year, from: activityDate) == currentYear
        }

        print("📊 MonthlyProgressRing: Monthly activities found: \(monthlyActivities.count)")

        let totalDistance = monthlyActivities.reduce(0) { $0 + (($1.distance ?? 0) * 0.000621371) }
        let totalRuns = monthlyActivities.count
        let goal = 100.0 // miles
        let progress = min(totalDistance / goal, 1.0)

        print("📊 MonthlyProgressRing: Distance: \(totalDistance) miles, Runs: \(totalRuns), Progress: \(progress)")

        return MonthlyStats(distance: totalDistance, runs: totalRuns, goal: goal, progress: progress)
    }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Text("Monthly Goal")
                .font(AppTheme.Typography.title)
                .fontWeight(.bold)
                .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

            ZStack {
                // Background ring
                Circle()
                    .stroke(AppTheme.Colors.textTertiary.opacity(0.2), lineWidth: 20)
                    .frame(width: 180, height: 180)

                // Progress ring
                Circle()
                    .trim(from: 0, to: animateProgress ? monthlyStats.progress : 0)
                    .stroke(
                        AppTheme.Colors.LightMode.accent,
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.5), value: animateProgress)

                // Center content
                VStack(spacing: 4) {
                    Text("\(Int(monthlyStats.progress * 100))%")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

                    Text("\(String(format: "%.1f", monthlyStats.distance)) / \(Int(monthlyStats.goal)) mi")
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppTheme.Colors.LightMode.textSecondary)

                    Text("\(monthlyStats.runs) runs")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
            }
        }
        .padding(AppTheme.Spacing.lg)
        .background(AppTheme.Colors.LightMode.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.large)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).delay(0.3)) {
                animateProgress = true
            }
        }
    }
}

// MARK: - Data Models

struct WeeklyStats {
    let totalDistance: Double
    let activityCount: Int
    let averagePace: Double
    let totalTime: Double
}

struct HeatmapData {
    let date: Date
    let intensity: Double
    let activityCount: Int
}

struct PaceDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let pace: Double
    let distance: Double
}

struct MonthlyStats {
    let distance: Double
    let runs: Int
    let goal: Double
    let progress: Double
}

// MARK: - Helper Functions

private func formatPace(_ pace: Double) -> String {
    let minutes = Int(pace)
    let seconds = Int((pace - Double(minutes)) * 60)
    return String(format: "%d:%02d", minutes, seconds)
}

private func formatDuration(_ seconds: Double) -> String {
    let hours = Int(seconds) / 3600
    let minutes = Int(seconds) % 3600 / 60

    if hours > 0 {
        return "\(hours)h \(minutes)m"
    } else {
        return "\(minutes)m"
    }
}
