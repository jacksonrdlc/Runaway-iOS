//
//  InsightsSections.swift
//  Runaway iOS
//
//  Section components for Unified Insights View
//

import SwiftUI
import Charts

// MARK: - Section 1: Hero Stats Section

struct HeroStatsSection: View {
    let quickWinsData: QuickWinsResponse?

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("At a Glance")
                .font(AppTheme.Typography.headline)
                .foregroundColor(AppTheme.Colors.LightMode.textPrimary)
                .padding(.horizontal)

            if let data = quickWinsData {
                QuickStatsCarousel(data: data)
            }
        }
    }
}

// MARK: - Section 2: Priority Insights Section

struct PriorityInsightsSection: View {
    let recommendations: [String]
    let performanceTrend: PerformanceTrend?
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            // Performance Status Badge
            if let trend = performanceTrend {
                PerformanceStatusBadge(trend: trend)
            }

            // Unified Recommendations
            if !recommendations.isEmpty {
                UnifiedRecommendationsBanner(
                    recommendations: recommendations,
                    isExpanded: $isExpanded
                )
            }
        }
    }
}

struct PerformanceStatusBadge: View {
    let trend: PerformanceTrend

    var body: some View {
        HStack {
            Image(systemName: trendIcon)
                .font(.title)
                .foregroundColor(trendColor)

            VStack(alignment: .leading, spacing: 4) {
                Text("Performance Trend")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.LightMode.textSecondary)

                Text(trend.description)
                    .font(AppTheme.Typography.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(trendColor)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(AppTheme.Colors.LightMode.textTertiary)
        }
        .padding()
        .background(trendColor.opacity(0.1))
        .cornerRadius(AppTheme.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                .stroke(trendColor.opacity(0.3), lineWidth: 1)
        )
    }

    private var trendIcon: String {
        switch trend {
        case .improving: return "arrow.up.circle.fill"
        case .stable: return "minus.circle.fill"
        case .declining: return "arrow.down.circle.fill"
        }
    }

    private var trendColor: Color {
        switch trend {
        case .improving: return .green
        case .stable: return .blue
        case .declining: return .orange
        }
    }
}

struct UnifiedRecommendationsBanner: View {
    let recommendations: [String]
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(AppTheme.Colors.LightMode.accent)
                Text("Recommendations")
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(AppTheme.Colors.LightMode.textPrimary)
                Spacer()
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
                }
            }

            ForEach(Array(recommendations.prefix(isExpanded ? recommendations.count : 3).enumerated()), id: \.offset) { index, recommendation in
                HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                    Text("\(index + 1)")
                        .font(AppTheme.Typography.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(AppTheme.Colors.LightMode.accent)
                        .clipShape(Circle())

                    Text(recommendation)
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppTheme.Colors.LightMode.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()
                }
            }

            if !isExpanded && recommendations.count > 3 {
                Button(action: { isExpanded = true }) {
                    Text("See \(recommendations.count - 3) more")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.LightMode.accent)
                }
            }
        }
        .padding()
        .background(AppTheme.Colors.LightMode.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.large)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Section 3: Performance at a Glance Section

struct PerformanceGlanceSection: View {
    let activities: [Activity]
    let quickWinsData: QuickWinsResponse?

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            // Week vs Week Comparison
            PerformanceDashboardCard(activities: activities)
        }
    }
}

// MARK: - Section 4: Deep Dive Navigation Grid

struct DeepDiveNavigationGrid: View {
    let quickWinsData: QuickWinsResponse?
    let onWeatherTap: () -> Void
    let onVO2MaxTap: () -> Void
    let onTrainingLoadTap: () -> Void
    let onActivityTrendsTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Deep Dive Analysis")
                .font(AppTheme.Typography.headline)
                .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.md) {
                if let weather = quickWinsData?.analyses.weatherContext {
                    DeepDiveCard(
                        title: "Weather Impact",
                        subtitle: weather.weatherImpactScore.capitalized,
                        icon: "cloud.sun.fill",
                        color: colorForWeatherImpact(weather.weatherImpactScore),
                        action: onWeatherTap
                    )
                }

                if let vo2max = quickWinsData?.analyses.vo2maxEstimate {
                    DeepDiveCard(
                        title: "Race Predictions",
                        subtitle: "\(vo2max.racePredictions.count) Distances",
                        icon: "flag.fill",
                        color: .blue,
                        action: onVO2MaxTap
                    )
                }

                if let trainingLoad = quickWinsData?.analyses.trainingLoad {
                    DeepDiveCard(
                        title: "Training Load",
                        subtitle: trainingLoad.injuryRiskDisplay,
                        icon: "chart.line.uptrend.xyaxis",
                        color: colorForInjuryRisk(trainingLoad.injuryRiskLevel),
                        action: onTrainingLoadTap
                    )
                }

                DeepDiveCard(
                    title: "Activity Trends",
                    subtitle: "Pace & Heatmap",
                    icon: "chart.xyaxis.line",
                    color: .purple,
                    action: onActivityTrendsTap
                )
            }
        }
    }

    private func colorForWeatherImpact(_ score: String) -> Color {
        switch score {
        case "minimal": return .green
        case "moderate": return .orange
        case "significant": return .red
        case "severe": return .purple
        default: return .gray
        }
    }

    private func colorForInjuryRisk(_ risk: String) -> Color {
        switch risk {
        case "low": return .green
        case "moderate": return .orange
        case "high": return .red
        case "very_high": return .purple
        default: return .gray
        }
    }
}

struct DeepDiveCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                    Spacer()
                }

                Text(title)
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

                Text(subtitle)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
            .padding()
            .background(color.opacity(0.1))
            .cornerRadius(AppTheme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Section 5: Charts Section

struct ChartsSection: View {
    let activities: [Activity]
    let weeklyData: [WeeklyVolume]

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            // Pace Trends Chart
            PaceTrendsChart(activities: activities)

            // Weekly Volume Chart
            if !weeklyData.isEmpty {
                WeeklyVolumeChart(weeklyData: weeklyData)
            }

            // Activity Heatmap
            ActivityHeatmapCard(activities: activities)
        }
    }
}

// MARK: - Section 6: Goal & Readiness Section

struct GoalReadinessSection: View {
    let activities: [Activity]
    let goalReadiness: GoalReadiness?
    let nextRunPrediction: PaceRange?

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            // Running Goal Card
            RunningGoalCard(activities: activities, goalReadiness: goalReadiness)

            // Goal Readiness
            if let goalReadiness = goalReadiness {
                GoalReadinessCard(goalReadiness: goalReadiness)
            }

            // Next Run Prediction
            if let prediction = nextRunPrediction {
                NextRunPredictionCard(prediction: prediction)
            }
        }
    }
}

// MARK: - Training Journal Section

struct TrainingJournalSection: View {
    let journal: TrainingJournal?
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            // Header
            HStack {
                Image(systemName: "book.fill")
                    .foregroundColor(AppTheme.Colors.LightMode.accent)
                Text("Training Journal")
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(AppTheme.Colors.LightMode.textPrimary)
                Spacer()
                if let journal = journal {
                    Text(journal.weekRangeString)
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
                }
            }
            .padding(.horizontal)

            if let journal = journal {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    // Week Stats Summary
                    WeekStatsGrid(stats: journal.weekStats)
                        .padding(.horizontal)

                    // Narrative
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        HStack {
                            Image(systemName: "quote.bubble.fill")
                                .foregroundColor(AppTheme.Colors.LightMode.accent.opacity(0.6))
                                .font(.caption)
                            Text("Coach's Summary")
                                .font(AppTheme.Typography.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
                        }
                        .padding(.horizontal)

                        Text(journal.narrative)
                            .font(AppTheme.Typography.body)
                            .foregroundColor(AppTheme.Colors.LightMode.textPrimary)
                            .lineSpacing(4)
                            .padding()
                            .background(AppTheme.Colors.LightMode.surfaceBackground)
                            .cornerRadius(AppTheme.CornerRadius.medium)
                            .padding(.horizontal)
                    }

                    // Insights
                    if !journal.insights.isEmpty {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                            HStack {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(AppTheme.Colors.LightMode.accent)
                                Text("Key Insights")
                                    .font(AppTheme.Typography.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
                                Spacer()
                                Button(action: { isExpanded.toggle() }) {
                                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                        .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
                                }
                            }
                            .padding(.horizontal)

                            ForEach(Array(journal.insights.prefix(isExpanded ? journal.insights.count : 3)), id: \.id) { insight in
                                InsightRow(insight: insight)
                                    .padding(.horizontal)
                            }

                            if !isExpanded && journal.insights.count > 3 {
                                Button(action: { isExpanded = true }) {
                                    Text("See \(journal.insights.count - 3) more")
                                        .font(AppTheme.Typography.caption)
                                        .foregroundColor(AppTheme.Colors.LightMode.accent)
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical, AppTheme.Spacing.sm)
            } else {
                // Empty State
                VStack(spacing: AppTheme.Spacing.md) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 48))
                        .foregroundColor(AppTheme.Colors.LightMode.textTertiary)

                    Text("No journal entry yet")
                        .font(AppTheme.Typography.headline)
                        .foregroundColor(AppTheme.Colors.LightMode.textSecondary)

                    Text("Your weekly training summary will appear here")
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppTheme.Colors.LightMode.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
        .padding(.vertical, AppTheme.Spacing.sm)
        .background(AppTheme.Colors.LightMode.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.large)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Supporting Components

struct WeekStatsGrid: View {
    let stats: WeekStats

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.md) {
            JournalStatBox(icon: "figure.run", title: "Distance", value: String(format: "%.1f mi", stats.totalDistance))
            JournalStatBox(icon: "timer", title: "Time", value: String(format: "%.1f hrs", stats.totalTime))
            JournalStatBox(icon: "speedometer", title: "Avg Pace", value: stats.avgPace)
            JournalStatBox(icon: "flame.fill", title: "Runs", value: "\(stats.activitiesCount)")
        }
    }
}

struct JournalStatBox: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(AppTheme.Colors.LightMode.accent)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
                Text(value)
                    .font(AppTheme.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.Colors.LightMode.textPrimary)
            }
            Spacer()
        }
        .padding(AppTheme.Spacing.sm)
        .background(AppTheme.Colors.LightMode.surfaceBackground)
        .cornerRadius(AppTheme.CornerRadius.small)
    }
}

struct InsightRow: View {
    let insight: JournalInsight

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            Image(systemName: insight.type.icon)
                .foregroundColor(insightColor)
                .font(.caption)
                .frame(width: 24)

            Text(insight.text)
                .font(AppTheme.Typography.body)
                .foregroundColor(AppTheme.Colors.LightMode.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(.vertical, AppTheme.Spacing.xs)
    }

    private var insightColor: Color {
        switch insight.type.color {
        case "yellow": return .yellow
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        default: return .gray
        }
    }
}
