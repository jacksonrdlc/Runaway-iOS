//
//  AdaptiveInsightCards.swift
//  Runaway iOS
//
//  Adaptive insight cards that change based on training phase
//

import SwiftUI

// MARK: - Adaptive Primary Insight Card

/// Main card that switches content based on detected training phase
struct AdaptivePrimaryInsightCard: View {
    let phaseContext: TrainingPhaseContext
    let activities: [Activity]
    let trainingLoad: TrainingLoadAnalysis?
    let racePredictions: [RacePrediction]?

    var body: some View {
        VStack(spacing: 0) {
            // Phase indicator header
            PhaseIndicatorHeader(phaseContext: phaseContext)

            // Phase-specific content
            switch phaseContext.phase {
            case .newUser:
                ProgressionBasicsCard(
                    metrics: TrainingPhaseService.generateProgressionMetrics(activities: activities)
                )

            case .steady, .base, .build, .peak, .rampingUp:
                VolumeConsistencyCard(
                    metrics: TrainingPhaseService.generateVolumeMetrics(
                        activities: activities,
                        trainingLoad: trainingLoad
                    ),
                    streakDays: phaseContext.streakDays
                )

            case .taper, .raceWeek, .raceDay:
                TaperMetricsCard(
                    metrics: TrainingPhaseService.generateTaperMetrics(
                        activities: activities,
                        trainingLoad: trainingLoad,
                        daysUntilRace: phaseContext.daysUntilRace ?? 14,
                        raceGoal: nil,
                        racePredictions: racePredictions
                    )
                )

            case .recovery:
                RecoveryReadinessCard(
                    metrics: TrainingPhaseService.generateRecoveryMetrics(
                        activities: activities,
                        trainingLoad: trainingLoad
                    )
                )

            case .detraining:
                ReturnToRunningCard(
                    phaseContext: phaseContext,
                    activities: activities
                )
            }
        }
        .background(AppTheme.Colors.adaptiveCardBackground)
        .cornerRadius(AppTheme.CornerRadius.large)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                .stroke(phaseContext.phase.color.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Phase Indicator Header (Twin Voice Banner)

struct PhaseIndicatorHeader: View {
    let phaseContext: TrainingPhaseContext
    private var isUrgent: Bool { phaseContext.urgency == .high || phaseContext.urgency == .critical }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Phase badge row
            HStack(spacing: 6) {
                Image(systemName: phaseContext.phase.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(phaseContext.phase.color)
                Text(phaseContext.phase.displayName.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(phaseContext.phase.color)
                    .kerning(1.2)
                Spacer()
                if let days = phaseContext.daysUntilRace, days <= 14 {
                    Text("\(days)D")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(phaseContext.phase.color).cornerRadius(6)
                }
            }

            // Twin Voice — hero line
            Text(phaseContext.twinMessage)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)

            // Data point
            if let sub = phaseContext.twinSubmessage {
                Text(sub)
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.DarkMode.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(isUrgent ? phaseContext.phase.color.opacity(0.18) : Color.white.opacity(0.04))
        .overlay(
            Rectangle()
                .fill(phaseContext.phase.color)
                .frame(width: 3)
                .cornerRadius(1.5),
            alignment: .leading
        )
    }
}

// MARK: - 1. Progression Basics Card (New Users)

struct ProgressionBasicsCard: View {
    let metrics: ProgressionMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            // Quick stats
            HStack(spacing: AppTheme.Spacing.md) {
                AdaptiveStatPill(
                    value: "\(metrics.totalActivities)",
                    label: "Runs",
                    color: .blue
                )

                AdaptiveStatPill(
                    value: String(format: "%.1f", metrics.totalDistanceMiles),
                    label: "Miles",
                    color: .green
                )

                AdaptiveStatPill(
                    value: "\(metrics.daysSinceStart)",
                    label: "Days",
                    color: .orange
                )
            }

            Divider()

            // Milestones
            Text("Milestones")
                .font(AppTheme.Typography.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppTheme.Colors.adaptiveTextPrimary)

            ForEach(metrics.milestones.prefix(4)) { milestone in
                MilestoneRow(milestone: milestone)
            }
        }
        .padding()
    }
}

struct MilestoneRow: View {
    let milestone: ProgressionMilestone

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: milestone.isAchieved ? "checkmark.circle.fill" : milestone.icon)
                .foregroundColor(milestone.isAchieved ? .green : .gray)
                .font(.subheadline)

            VStack(alignment: .leading, spacing: 2) {
                Text(milestone.title)
                    .font(AppTheme.Typography.subheadline)
                    .foregroundColor(AppTheme.Colors.adaptiveTextPrimary)
                    .strikethrough(milestone.isAchieved)

                Text(milestone.description)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.adaptiveTextTertiary)
            }

            Spacer()

            if milestone.isAchieved {
                Text("Done!")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 2. Volume Consistency Card

struct VolumeConsistencyCard: View {
    let metrics: VolumeConsistencyMetrics
    let streakDays: Int

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            // Weekly comparison
            HStack(alignment: .top, spacing: AppTheme.Spacing.lg) {
                // This week
                VStack(spacing: 4) {
                    Text("This Week")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.adaptiveTextSecondary)

                    Text(String(format: "%.1f", metrics.currentWeekMiles))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Colors.accent)

                    Text("miles")
                        .font(.caption2)
                        .foregroundColor(AppTheme.Colors.adaptiveTextTertiary)
                }
                .frame(maxWidth: .infinity)

                // Change indicator
                VStack(spacing: 4) {
                    Image(systemName: metrics.weekOverWeekChange >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .font(.title2)
                        .foregroundColor(metrics.weekOverWeekChange >= 0 ? .green : .orange)

                    Text(String(format: "%+.0f%%", metrics.weekOverWeekChange))
                        .font(AppTheme.Typography.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(metrics.weekOverWeekChange >= 0 ? .green : .orange)

                    Text("vs last week")
                        .font(.caption2)
                        .foregroundColor(AppTheme.Colors.adaptiveTextTertiary)
                }
                .frame(maxWidth: .infinity)

                // 4-week average
                VStack(spacing: 4) {
                    Text("4-Week Avg")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.adaptiveTextSecondary)

                    Text(String(format: "%.1f", metrics.fourWeekAverageMiles))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Colors.adaptiveTextPrimary)

                    Text("miles")
                        .font(.caption2)
                        .foregroundColor(AppTheme.Colors.adaptiveTextTertiary)
                }
                .frame(maxWidth: .infinity)
            }

            Divider()

            // Consistency and streak
            HStack(spacing: AppTheme.Spacing.md) {
                // Consistency score
                HStack(spacing: 8) {
                    ConsistencyRing(score: metrics.consistencyScore)
                        .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Consistency")
                            .font(.caption2)
                            .foregroundColor(AppTheme.Colors.adaptiveTextTertiary)

                        Text(metrics.consistencyLevel)
                            .font(AppTheme.Typography.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(metrics.consistencyColor)
                    }
                }

                Spacer()

                // Streak
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.title2)
                        .foregroundColor(.orange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Streak")
                            .font(.caption2)
                            .foregroundColor(AppTheme.Colors.adaptiveTextTertiary)

                        Text("\(metrics.streakWeeks) weeks")
                            .font(AppTheme.Typography.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.Colors.adaptiveTextPrimary)
                    }
                }
            }
        }
        .padding()
    }
}

struct ConsistencyRing: View {
    let score: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 4)

            Circle()
                .trim(from: 0, to: score / 100)
                .stroke(
                    score >= 80 ? Color.green : score >= 60 ? Color.blue : Color.orange,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Text("\(Int(score))")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.Colors.adaptiveTextPrimary)
        }
    }
}

// MARK: - 3. Taper Metrics Card

struct TaperMetricsCard: View {
    let metrics: TaperMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            // Race countdown
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Race Day")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.adaptiveTextSecondary)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(metrics.daysUntilRace)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(metrics.taperStatusColor)

                        Text("days")
                            .font(AppTheme.Typography.subheadline)
                            .foregroundColor(AppTheme.Colors.adaptiveTextSecondary)
                    }
                }

                Spacer()

                // Taper status badge
                VStack(spacing: 4) {
                    Text(metrics.taperStatus)
                        .font(AppTheme.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(metrics.taperStatusColor)
                        .cornerRadius(AppTheme.CornerRadius.small)

                    if let predictedTime = metrics.predictedRaceTime {
                        Text("Goal: \(predictedTime)")
                            .font(.caption2)
                            .foregroundColor(AppTheme.Colors.adaptiveTextTertiary)
                    }
                }
            }

            Divider()

            // Volume comparison
            VStack(alignment: .leading, spacing: 8) {
                Text("Volume Reduction")
                    .font(AppTheme.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.Colors.adaptiveTextPrimary)

                // Progress bar showing current vs target
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background (100% = peak volume)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 24)

                        // Target marker
                        RoundedRectangle(cornerRadius: 4)
                            .fill(metrics.taperStatusColor.opacity(0.3))
                            .frame(width: geometry.size.width * (metrics.targetVolumePercent / 100), height: 24)

                        // Current volume
                        RoundedRectangle(cornerRadius: 4)
                            .fill(metrics.taperStatusColor)
                            .frame(width: geometry.size.width * min(metrics.currentVolumePercent, 100) / 100, height: 24)

                        // Labels
                        HStack {
                            Text(String(format: "%.0f%%", metrics.currentVolumePercent))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.leading, 8)

                            Spacer()

                            Text("Target: \(Int(metrics.targetVolumePercent))%")
                                .font(.caption2)
                                .foregroundColor(AppTheme.Colors.adaptiveTextSecondary)
                                .padding(.trailing, 8)
                        }
                        .frame(height: 24)
                    }
                }
                .frame(height: 24)

                Text("of peak volume (\(String(format: "%.0f", metrics.peakVolumeMiles)) mi)")
                    .font(.caption2)
                    .foregroundColor(AppTheme.Colors.adaptiveTextTertiary)
            }
        }
        .padding()
    }
}

// MARK: - 4. Recovery Readiness Card

struct RecoveryReadinessCard: View {
    let metrics: RecoveryMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            // Recovery score
            HStack(spacing: AppTheme.Spacing.md) {
                // Big recovery score
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                        .frame(width: 80, height: 80)

                    Circle()
                        .trim(from: 0, to: metrics.recoveryScore / 100)
                        .stroke(metrics.statusColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text("\(Int(metrics.recoveryScore))")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.Colors.adaptiveTextPrimary)

                        Text(metrics.recoveryLevel)
                            .font(.caption2)
                            .foregroundColor(metrics.statusColor)
                    }
                }

                // Details
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(metrics.statusColor)

                        Text(metrics.statusDisplay)
                            .font(AppTheme.Typography.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.Colors.adaptiveTextPrimary)
                    }

                    HStack(spacing: AppTheme.Spacing.md) {
                        Label("\(metrics.restDaysLast7) rest days", systemImage: "bed.double")
                            .font(.caption)
                            .foregroundColor(AppTheme.Colors.adaptiveTextSecondary)

                        Label("ACWR: \(String(format: "%.2f", metrics.acwr))", systemImage: "chart.line.uptrend.xyaxis")
                            .font(.caption)
                            .foregroundColor(AppTheme.Colors.adaptiveTextSecondary)
                    }
                }

                Spacer()
            }

            if metrics.suggestedRestDays > 0 {
                Divider()

                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)

                    Text("Consider \(metrics.suggestedRestDays) more rest day\(metrics.suggestedRestDays > 1 ? "s" : "") this week")
                        .font(AppTheme.Typography.subheadline)
                        .foregroundColor(AppTheme.Colors.adaptiveTextPrimary)
                }
                .padding(AppTheme.Spacing.sm)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(AppTheme.CornerRadius.small)
            }

            // Top recommendation
            if let recommendation = metrics.recommendations.first {
                Text(recommendation)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.adaptiveTextSecondary)
                    .padding(.top, 4)
            }
        }
        .padding()
    }
}

// MARK: - 5. Return to Running Card

struct ReturnToRunningCard: View {
    let phaseContext: TrainingPhaseContext
    let activities: [Activity]

    private var daysSinceLastRun: Int {
        let dates = activities.compactMap { activity -> Date? in
            guard let timestamp = activity.activity_date ?? activity.start_date else { return nil }
            return Date(timeIntervalSince1970: timestamp)
        }
        guard let lastDate = dates.max() else {
            return 0
        }
        return Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            // Time away
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Time Since Last Run")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.adaptiveTextSecondary)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(daysSinceLastRun)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)

                        Text("days")
                            .font(AppTheme.Typography.subheadline)
                            .foregroundColor(AppTheme.Colors.adaptiveTextSecondary)
                    }
                }

                Spacer()

                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.orange.opacity(0.3))
            }

            Divider()

            // Return plan
            VStack(alignment: .leading, spacing: 8) {
                Text("Return Plan")
                    .font(AppTheme.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.Colors.adaptiveTextPrimary)

                ForEach(Array(phaseContext.recommendations.prefix(3).enumerated()), id: \.offset) { index, recommendation in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                            .background(Color.orange)
                            .clipShape(Circle())

                        Text(recommendation)
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.adaptiveTextSecondary)
                    }
                }
            }

            Label("Use these steps to guide your next run", systemImage: "checkmark.circle.fill")
                .font(AppTheme.Typography.caption.weight(.medium))
                .foregroundColor(AppTheme.Colors.adaptiveTextSecondary)
        }
        .padding()
    }
}

// MARK: - Supporting Components

struct AdaptiveStatPill: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(color)

            Text(label)
                .font(.caption2)
                .foregroundColor(AppTheme.Colors.adaptiveTextTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(AppTheme.CornerRadius.small)
    }
}
