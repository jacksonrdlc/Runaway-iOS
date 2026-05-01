//
//  DiscoveryComponents.swift
//  Runaway iOS
//

import SwiftUI

// MARK: - Discovery Components

struct CoachInsightCard: View {
    @Environment(DataManager.self) var dataManager
    @StateObject private var readinessService = ReadinessService.shared
    let onAskCoach: () -> Void

    private var insightText: String {
        // Prioritize readiness-based insights
        if let readiness = readinessService.todaysReadiness {
            return readiness.recommendation
        }

        // Fall back to training recommendations
        // This would come from the viewModel in a real implementation
        return "Keep up the great work! Your consistency is paying off."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.warmAmber)
                EyebrowLabel(text: "COACH SAYS", color: AppTheme.Colors.warmAmber)
                Spacer()
            }

            Text(insightText)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(AppTheme.Colors.DarkMode.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button(action: onAskCoach) {
                    HStack(spacing: 4) {
                        Text("Ask Coach")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(AppTheme.Colors.warmAmber)
                }
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.warmAmber.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium + 2))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium + 2)
                .stroke(AppTheme.Colors.warmAmber.opacity(0.16), lineWidth: 1)
        )
    }
}

struct ExploreSection: View {
    let quickWinsData: QuickWinsResponse?
    let onWeatherTap: () -> Void
    let onVO2MaxTap: () -> Void
    let onTrainingLoadTap: () -> Void
    let onActivityTrendsTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            EyebrowLabel(text: "EXPLORE")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    if quickWinsData?.analyses.weatherContext != nil {
                        ExplorePill(icon: "cloud.sun.fill", title: "Weather", action: onWeatherTap)
                    }
                    if quickWinsData?.analyses.vo2maxEstimate != nil {
                        ExplorePill(icon: "flag.fill", title: "Race Times", action: onVO2MaxTap)
                    }
                    if quickWinsData?.analyses.trainingLoad != nil {
                        ExplorePill(icon: "chart.line.uptrend.xyaxis", title: "Training Load", action: onTrainingLoadTap)
                    }
                    ExplorePill(icon: "map.fill", title: "Heatmap", action: onActivityTrendsTap)
                }
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.DarkMode.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium + 2))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium + 2)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }
}

struct ExplorePill: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.Colors.warmAmber)
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(AppTheme.Colors.DarkMode.surfaceBackground)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.09), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
