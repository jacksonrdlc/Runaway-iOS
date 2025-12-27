//
//  ElevationProfileChart.swift
//  Runaway iOS
//
//  Elevation profile visualization for activities
//  Shows elevation summary and detailed profile when data available
//

import SwiftUI
import Charts

// MARK: - Elevation Data Models

/// Elevation summary data from activity
struct ElevationSummary {
    let gain: Double?      // Total elevation gain (meters)
    let loss: Double?      // Total elevation loss (meters)
    let high: Double?      // Highest point (meters)
    let low: Double?       // Lowest point (meters)

    var hasData: Bool {
        gain != nil || loss != nil || high != nil || low != nil
    }

    var range: Double? {
        guard let high = high, let low = low else { return nil }
        return high - low
    }
}

/// Detailed elevation point for profile chart
struct ElevationPoint: Identifiable {
    let id = UUID()
    let distance: Double    // Distance from start (meters or km)
    let elevation: Double   // Elevation at this point (meters)
}

// MARK: - Elevation Profile Chart View

struct ElevationProfileChart: View {
    let summary: ElevationSummary
    let detailedProfile: [ElevationPoint]?  // Optional detailed data
    let distanceUnit: String  // "km" or "mi"

    @State private var selectedPoint: ElevationPoint?

    init(activity: Activity, distanceUnit: String = "km") {
        // Extract summary from activity
        self.summary = ElevationSummary(
            gain: activity.elevation_gain,
            loss: activity.elevation_loss,
            high: activity.elevation_high,
            low: activity.elevation_low
        )

        // TODO: Extract detailed profile when route point data includes altitude
        self.detailedProfile = nil
        self.distanceUnit = distanceUnit
    }

    // Direct init for custom data
    init(summary: ElevationSummary, detailedProfile: [ElevationPoint]? = nil, distanceUnit: String = "km") {
        self.summary = summary
        self.detailedProfile = detailedProfile
        self.distanceUnit = distanceUnit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            // Header
            HStack {
                Label("Elevation", systemImage: "mountain.2.fill")
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

                Spacer()

                if let range = summary.range {
                    Text("\(Int(range))m range")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
                }
            }

            if let profile = detailedProfile, !profile.isEmpty {
                // Detailed elevation profile chart
                detailedProfileView(profile: profile)
            } else if summary.hasData {
                // Summary elevation bars
                summaryBarsView()
            } else {
                // No elevation data
                noDataView()
            }

            // Elevation statistics
            if summary.hasData {
                elevationStatsView()
            }
        }
        .padding(AppTheme.Spacing.lg)
        .background(AppTheme.Colors.LightMode.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.large)
        .shadow(
            color: AppTheme.Shadows.medium.color,
            radius: AppTheme.Shadows.medium.radius,
            x: AppTheme.Shadows.medium.x,
            y: AppTheme.Shadows.medium.y
        )
    }

    // MARK: - Detailed Profile View

    @ViewBuilder
    private func detailedProfileView(profile: [ElevationPoint]) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Chart(profile) { point in
                AreaMark(
                    x: .value("Distance", point.distance),
                    y: .value("Elevation", point.elevation)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            AppTheme.Colors.success.opacity(0.6),
                            AppTheme.Colors.success.opacity(0.2)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Distance", point.distance),
                    y: .value("Elevation", point.elevation)
                )
                .foregroundStyle(AppTheme.Colors.success)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                // Selection indicator
                if let selectedPoint = selectedPoint, selectedPoint.id == point.id {
                    PointMark(
                        x: .value("Distance", point.distance),
                        y: .value("Elevation", point.elevation)
                    )
                    .foregroundStyle(AppTheme.Colors.accent)
                    .symbol(.circle)
                    .symbolSize(100)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine()
                        .foregroundStyle(AppTheme.Colors.textQuaternary.opacity(0.3))
                    AxisValueLabel()
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.LightMode.textTertiary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic) { _ in
                    AxisGridLine()
                        .foregroundStyle(AppTheme.Colors.textQuaternary.opacity(0.3))
                    AxisValueLabel()
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.LightMode.textTertiary)
                }
            }
            .chartXAxisLabel("Distance (\(distanceUnit))")
            .chartYAxisLabel("Elevation (m)")
            .frame(height: 180)

            // Selected point info
            if let selected = selectedPoint {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "location.fill")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.accent)

                    Text(String(format: "%.2f %@ - %.0fm", selected.distance, distanceUnit, selected.elevation))
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
                }
                .transition(.opacity)
            }
        }
    }

    // MARK: - Summary Bars View

    @ViewBuilder
    private func summaryBarsView() -> some View {
        HStack(spacing: AppTheme.Spacing.md) {
            // Elevation Gain Bar
            if let gain = summary.gain, gain > 0 {
                VStack(spacing: AppTheme.Spacing.xs) {
                    ZStack(alignment: .bottom) {
                        // Background bar
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                            .fill(AppTheme.Colors.LightMode.surfaceBackground)
                            .frame(width: 40, height: 100)

                        // Filled portion (proportional to max value)
                        let maxValue = max(summary.gain ?? 0, summary.loss ?? 0)
                        let fillHeight = maxValue > 0 ? (gain / maxValue) * 100 : 0

                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.Colors.success, AppTheme.Colors.success.opacity(0.7)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 40, height: fillHeight)
                    }

                    VStack(spacing: 2) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.success)

                        Text("\(Int(gain))m")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

                        Text("GAIN")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(AppTheme.Colors.LightMode.textTertiary)
                    }
                }
            }

            // Elevation Loss Bar
            if let loss = summary.loss, loss > 0 {
                VStack(spacing: AppTheme.Spacing.xs) {
                    ZStack(alignment: .bottom) {
                        // Background bar
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                            .fill(AppTheme.Colors.LightMode.surfaceBackground)
                            .frame(width: 40, height: 100)

                        // Filled portion
                        let maxValue = max(summary.gain ?? 0, summary.loss ?? 0)
                        let fillHeight = maxValue > 0 ? (loss / maxValue) * 100 : 0

                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.Colors.info, AppTheme.Colors.info.opacity(0.7)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 40, height: fillHeight)
                    }

                    VStack(spacing: 2) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.info)

                        Text("\(Int(loss))m")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

                        Text("LOSS")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(AppTheme.Colors.LightMode.textTertiary)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, AppTheme.Spacing.sm)
    }

    // MARK: - Elevation Stats View

    @ViewBuilder
    private func elevationStatsView() -> some View {
        HStack(spacing: AppTheme.Spacing.lg) {
            // High Point
            if let high = summary.high {
                VStack(alignment: .leading, spacing: 2) {
                    Text("HIGH")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.LightMode.textTertiary)
                        .tracking(1)

                    Text("\(Int(high))m")
                        .font(AppTheme.Typography.bodyBold)
                        .foregroundColor(AppTheme.Colors.LightMode.textPrimary)
                }
            }

            // Low Point
            if let low = summary.low {
                VStack(alignment: .leading, spacing: 2) {
                    Text("LOW")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.LightMode.textTertiary)
                        .tracking(1)

                    Text("\(Int(low))m")
                        .font(AppTheme.Typography.bodyBold)
                        .foregroundColor(AppTheme.Colors.LightMode.textPrimary)
                }
            }

            Spacer()
        }
        .padding(.top, AppTheme.Spacing.xs)
    }

    // MARK: - No Data View

    @ViewBuilder
    private func noDataView() -> some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "mountain.2")
                .font(.system(size: 40))
                .foregroundColor(AppTheme.Colors.textQuaternary)

            Text("No elevation data")
                .font(AppTheme.Typography.subheadline)
                .foregroundColor(AppTheme.Colors.LightMode.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
    }
}

// MARK: - Preview

#Preview("With Summary Data") {
    ElevationProfileChart(
        summary: ElevationSummary(
            gain: 234,
            loss: 189,
            high: 567,
            low: 123
        )
    )
    .padding()
    .background(AppTheme.Colors.LightMode.background)
}

#Preview("With Detailed Profile") {
    ElevationProfileChart(
        summary: ElevationSummary(
            gain: 234,
            loss: 189,
            high: 567,
            low: 123
        ),
        detailedProfile: [
            ElevationPoint(distance: 0, elevation: 123),
            ElevationPoint(distance: 1, elevation: 145),
            ElevationPoint(distance: 2, elevation: 234),
            ElevationPoint(distance: 3, elevation: 389),
            ElevationPoint(distance: 4, elevation: 456),
            ElevationPoint(distance: 5, elevation: 567),
            ElevationPoint(distance: 6, elevation: 478),
            ElevationPoint(distance: 7, elevation: 345),
            ElevationPoint(distance: 8, elevation: 234),
            ElevationPoint(distance: 9, elevation: 189)
        ]
    )
    .padding()
    .background(AppTheme.Colors.LightMode.background)
}

#Preview("No Data") {
    ElevationProfileChart(
        summary: ElevationSummary(
            gain: nil,
            loss: nil,
            high: nil,
            low: nil
        )
    )
    .padding()
    .background(AppTheme.Colors.LightMode.background)
}
