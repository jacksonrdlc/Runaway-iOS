//
//  CompactCommitmentCard.swift
//  Runaway iOS
//
//  Condensed commitment card for Activities tab - single row layout
//

import SwiftUI

struct CompactCommitmentCard: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingFullCommitment = false

    @ObservedObject private var themeManager = ThemeManager.shared

    private var backgroundColor: Color {
        themeManager.isDarkMode
            ? AppTheme.Colors.DarkMode.cardBackground
            : AppTheme.Colors.LightMode.cardBackground
    }

    private var textPrimary: Color {
        themeManager.isDarkMode
            ? AppTheme.Colors.DarkMode.textPrimary
            : AppTheme.Colors.LightMode.textPrimary
    }

    private var textSecondary: Color {
        themeManager.isDarkMode
            ? AppTheme.Colors.DarkMode.textSecondary
            : AppTheme.Colors.LightMode.textSecondary
    }

    var body: some View {
        Button(action: { showingFullCommitment = true }) {
            HStack(spacing: AppTheme.Spacing.md) {
                // Status icon
                statusIcon

                // Content
                VStack(alignment: .leading, spacing: 2) {
                    if let commitment = dataManager.todaysCommitment {
                        if commitment.isFulfilled {
                            fulfilledContent(commitment)
                        } else {
                            activeContent(commitment)
                        }
                    } else {
                        noCommitmentContent
                    }
                }

                Spacer()

                // Action indicator
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(textSecondary)
            }
            .padding(AppTheme.Spacing.md)
            .background(backgroundColor)
            .cornerRadius(AppTheme.CornerRadius.medium)
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingFullCommitment) {
            NavigationView {
                FullCommitmentSheet()
                    .environmentObject(dataManager)
            }
        }
    }

    // MARK: - Status Icon

    @ViewBuilder
    private var statusIcon: some View {
        if let commitment = dataManager.todaysCommitment {
            if commitment.isFulfilled {
                // Completed - green checkmark
                ZStack {
                    Circle()
                        .fill(AppTheme.Colors.success.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppTheme.Colors.success)
                }
            } else {
                // Active - activity icon with accent
                ZStack {
                    Circle()
                        .fill(AppTheme.Colors.accent.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: commitment.activityType.icon)
                        .font(.system(size: 18))
                        .foregroundColor(AppTheme.Colors.accent)
                }
            }
        } else {
            // No commitment - plus icon
            ZStack {
                Circle()
                    .stroke(textSecondary.opacity(0.3), lineWidth: 1.5)
                    .frame(width: 40, height: 40)

                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(textSecondary)
            }
        }
    }

    // MARK: - Content Views

    @ViewBuilder
    private func fulfilledContent(_ commitment: DailyCommitment) -> some View {
        Text("Commitment Complete!")
            .font(AppTheme.Typography.body)
            .fontWeight(.semibold)
            .foregroundColor(AppTheme.Colors.success)

        Text("\(commitment.activityType.displayName) done today")
            .font(AppTheme.Typography.caption)
            .foregroundColor(textSecondary)
    }

    @ViewBuilder
    private func activeContent(_ commitment: DailyCommitment) -> some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            Text("Today:")
                .font(AppTheme.Typography.body)
                .foregroundColor(textSecondary)

            Text(commitment.activityType.displayName)
                .font(AppTheme.Typography.body)
                .fontWeight(.semibold)
                .foregroundColor(textPrimary)
        }

        if commitment.timeRemainingToday > 0 {
            Text(commitment.timeRemainingText)
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.accent)
        } else {
            Text("Commitment expired")
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.error)
        }
    }

    @ViewBuilder
    private var noCommitmentContent: some View {
        Text("Set today's commitment")
            .font(AppTheme.Typography.body)
            .fontWeight(.medium)
            .foregroundColor(textPrimary)

        Text("Tap to commit to an activity")
            .font(AppTheme.Typography.caption)
            .foregroundColor(textSecondary)
    }
}

// MARK: - Full Commitment Sheet

struct FullCommitmentSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataManager: DataManager

    @ObservedObject private var themeManager = ThemeManager.shared

    private var backgroundColor: Color {
        themeManager.isDarkMode
            ? AppTheme.Colors.DarkMode.background
            : AppTheme.Colors.LightMode.background
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    // Embed the full ActivityCommitmentCard
                    ActivityCommitmentCard()
                        .environmentObject(dataManager)
                }
                .padding(AppTheme.Spacing.md)
            }
        }
        .navigationTitle("Today's Commitment")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
                    .foregroundColor(AppTheme.Colors.accent)
            }
        }
    }
}

#Preview("With Active Commitment") {
    CompactCommitmentCard()
        .padding()
        .background(Color.gray.opacity(0.1))
        .environmentObject(DataManager.shared)
}

#Preview("No Commitment") {
    CompactCommitmentCard()
        .padding()
        .background(Color.gray.opacity(0.1))
        .environmentObject(DataManager.shared)
}
