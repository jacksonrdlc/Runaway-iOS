//
//  AwardsView.swift
//  Runaway iOS
//
//  Awards and achievements display page
//

import SwiftUI

// MARK: - Full Awards View

struct AwardsView: View {
    @EnvironmentObject private var dataManager: DataManager
    @State private var awardsData: [(award: AwardDefinition, isEarned: Bool, progress: Double)] = []
    @State private var selectedCategory: AwardCategory? = nil
    @State private var isLoading = true

    private let awardsService = AwardsService.shared

    var body: some View {
        ZStack {
            AppTheme.Colors.LightMode.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    // Summary Header
                    AwardsSummaryHeader(
                        earnedCount: awardsData.filter { $0.isEarned }.count,
                        totalCount: awardsData.count
                    )

                    // Category Filter
                    CategoryFilterBar(selectedCategory: $selectedCategory)

                    // Awards Grid
                    if isLoading {
                        ProgressView()
                            .scaleEffect(1.2)
                            .padding(.top, 50)
                    } else {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: AppTheme.Spacing.md) {
                            ForEach(filteredAwards, id: \.award.id) { item in
                                AwardBadgeView(
                                    award: item.award,
                                    isEarned: item.isEarned,
                                    progress: item.progress,
                                    showProgress: true
                                )
                            }
                        }
                        .padding(.horizontal, AppTheme.Spacing.md)
                    }
                }
                .padding(.vertical, AppTheme.Spacing.md)
            }
        }
        .navigationTitle("Awards")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadAwards()
        }
    }

    private var filteredAwards: [(award: AwardDefinition, isEarned: Bool, progress: Double)] {
        if let category = selectedCategory {
            return awardsData.filter { $0.award.category == category }
        }
        return awardsData
    }

    private func loadAwards() {
        isLoading = true
        let activities = dataManager.activities
        let athleteId = dataManager.athlete?.id ?? 0

        awardsData = awardsService.getAllAwardsWithStatus(
            activities: activities,
            athleteId: athleteId
        )

        // Sort: earned first, then by tier (platinum > gold > silver > bronze)
        awardsData.sort { a, b in
            if a.isEarned != b.isEarned {
                return a.isEarned
            }
            return tierOrder(a.award.tier) > tierOrder(b.award.tier)
        }

        isLoading = false
    }

    private func tierOrder(_ tier: AwardTier) -> Int {
        switch tier {
        case .platinum: return 4
        case .gold: return 3
        case .silver: return 2
        case .bronze: return 1
        }
    }
}

// MARK: - Awards Summary Header

struct AwardsSummaryHeader: View {
    let earnedCount: Int
    let totalCount: Int

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            ZStack {
                Circle()
                    .stroke(AppTheme.Colors.LightMode.textSecondary.opacity(0.2), lineWidth: 8)
                    .frame(width: 100, height: 100)

                Circle()
                    .trim(from: 0, to: totalCount > 0 ? CGFloat(earnedCount) / CGFloat(totalCount) : 0)
                    .stroke(AppTheme.Colors.LightMode.accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(earnedCount)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Colors.LightMode.accent)
                    Text("of \(totalCount)")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
                }
            }

            Text("Awards Earned")
                .font(AppTheme.Typography.headline)
                .foregroundColor(AppTheme.Colors.LightMode.textPrimary)
        }
        .padding(.vertical, AppTheme.Spacing.md)
    }
}

// MARK: - Category Filter Bar

struct CategoryFilterBar: View {
    @Binding var selectedCategory: AwardCategory?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppTheme.Spacing.sm) {
                CategoryChip(
                    title: "All",
                    icon: "star.fill",
                    isSelected: selectedCategory == nil,
                    action: { selectedCategory = nil }
                )

                ForEach(AwardCategory.allCases, id: \.self) { category in
                    CategoryChip(
                        title: category.displayName,
                        icon: category.icon,
                        isSelected: selectedCategory == category,
                        action: { selectedCategory = category }
                    )
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
        }
    }
}

struct CategoryChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.xs) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(AppTheme.Typography.caption)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background(
                isSelected ?
                AppTheme.Colors.LightMode.accent :
                AppTheme.Colors.LightMode.cardBackground
            )
            .foregroundColor(
                isSelected ?
                .white :
                AppTheme.Colors.LightMode.textPrimary
            )
            .clipShape(Capsule())
        }
    }
}

// MARK: - Award Badge View

struct AwardBadgeView: View {
    let award: AwardDefinition
    let isEarned: Bool
    let progress: Double
    var showProgress: Bool = false
    var size: BadgeSize = .medium

    enum BadgeSize {
        case small, medium, large

        var iconSize: CGFloat {
            switch self {
            case .small: return 24
            case .medium: return 36
            case .large: return 48
            }
        }

        var frameSize: CGFloat {
            switch self {
            case .small: return 60
            case .medium: return 90
            case .large: return 120
            }
        }
    }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.xs) {
            ZStack {
                // Background circle with tier color
                Circle()
                    .fill(
                        isEarned ?
                        award.tier.color.opacity(0.2) :
                        Color.gray.opacity(0.1)
                    )
                    .frame(width: size.frameSize, height: size.frameSize)

                // Progress ring (if showing progress and not earned)
                if showProgress && !isEarned && progress > 0 {
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(award.tier.color.opacity(0.5), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: size.frameSize - 6, height: size.frameSize - 6)
                        .rotationEffect(.degrees(-90))
                }

                // Icon
                Image(systemName: award.icon)
                    .font(.system(size: size.iconSize))
                    .foregroundColor(
                        isEarned ?
                        award.tier.color :
                        Color.gray.opacity(0.4)
                    )
            }

            // Award name
            Text(award.name)
                .font(size == .small ? AppTheme.Typography.caption : AppTheme.Typography.subheadline)
                .foregroundColor(
                    isEarned ?
                    AppTheme.Colors.LightMode.textPrimary :
                    AppTheme.Colors.LightMode.textSecondary
                )
                .lineLimit(2)
                .multilineTextAlignment(.center)

            // Tier badge (for medium and large sizes)
            if size != .small && isEarned {
                Text(award.tier.displayName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(award.tier.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(award.tier.color.opacity(0.15))
                    .clipShape(Capsule())
            }

            // Progress text (for unearned awards with progress)
            if showProgress && !isEarned && progress > 0 {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
            }
        }
        .frame(width: size.frameSize + 20)
    }
}

// MARK: - Awards Preview Section (for AthleteView)

struct AwardsPreviewSection: View {
    @EnvironmentObject private var dataManager: DataManager
    @Environment(AppRouter.self) private var router
    @State private var earnedAwards: [(award: AwardDefinition, earnedDate: Date?)] = []

    private let awardsService = AwardsService.shared
    private let maxDisplayCount = 8

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            // Header
            HStack {
                Image(systemName: "medal.fill")
                    .foregroundColor(AppTheme.Colors.warning)
                    .font(.title2)

                Text("Awards")
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

                Spacer()

                if !earnedAwards.isEmpty {
                    Button(action: {
                        router.navigate(to: .awards)
                    }) {
                        HStack(spacing: 4) {
                            Text("View All")
                                .font(AppTheme.Typography.subheadline)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .foregroundColor(AppTheme.Colors.LightMode.accent)
                    }
                }
            }

            if earnedAwards.isEmpty {
                // Empty state
                VStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "medal")
                        .font(.system(size: 40))
                        .foregroundColor(AppTheme.Colors.LightMode.textSecondary.opacity(0.5))

                    Text("No awards yet")
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppTheme.Colors.LightMode.textSecondary)

                    Text("Keep running to earn your first award!")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.Spacing.lg)
            } else {
                // Awards grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: AppTheme.Spacing.sm) {
                    ForEach(earnedAwards.prefix(maxDisplayCount), id: \.award.id) { item in
                        AwardBadgeView(
                            award: item.award,
                            isEarned: true,
                            progress: 1.0,
                            size: .small
                        )
                    }
                }

                // Show "View More" button if there are more awards
                if earnedAwards.count > maxDisplayCount {
                    Button(action: {
                        router.navigate(to: .awards)
                    }) {
                        Text("+ \(earnedAwards.count - maxDisplayCount) more awards")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.LightMode.accent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, AppTheme.Spacing.xs)
                }
            }
        }
        .surfaceCard()
        .onAppear {
            loadEarnedAwards()
        }
        .onChange(of: dataManager.activities) { _, _ in
            loadEarnedAwards()
        }
    }

    private func loadEarnedAwards() {
        let activities = dataManager.activities
        let athleteId = dataManager.athlete?.id ?? 0

        earnedAwards = awardsService.getEarnedAwardsWithDetails(
            activities: activities,
            athleteId: athleteId
        )

        // Sort by tier (platinum first) then by earned date (most recent first)
        earnedAwards.sort { a, b in
            if tierOrder(a.award.tier) != tierOrder(b.award.tier) {
                return tierOrder(a.award.tier) > tierOrder(b.award.tier)
            }
            let dateA = a.earnedDate ?? Date.distantPast
            let dateB = b.earnedDate ?? Date.distantPast
            return dateA > dateB
        }
    }

    private func tierOrder(_ tier: AwardTier) -> Int {
        switch tier {
        case .platinum: return 4
        case .gold: return 3
        case .silver: return 2
        case .bronze: return 1
        }
    }
}
