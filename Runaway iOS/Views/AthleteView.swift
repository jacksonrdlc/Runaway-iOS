//
//  Profile.swift
//  RunawayUI
//
//  Created by Jack Rudelic on 7/17/24.
//

import SwiftUI
import Charts

struct AthleteView: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    let athlete: Athlete
    let stats: AthleteStats

    @State var userImage: String?
    @State var name: String?

    @State private var isAthleteDataReady = false
    @State private var isActivitiesDataReady = false

    private var background: Color {
        themeManager.isDarkMode ? AppTheme.Colors.DarkMode.background : AppTheme.Colors.LightMode.background
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    // Profile Header
                    ProfileHeader(athlete: athlete)
                    
                    // Twin Identity Summary
                    TwinIdentityBadge()
                    
                    // Quick Stats Grid
                    QuickStatsGrid(
                        runs: (stats.count ?? 0).formatted(.number),
                        miles: (stats.distance! * 0.000621371).formatted(.number.precision(.fractionLength(1))),
                        minutes: (stats.elapsedTime! / 60).formatted(.number.precision(.fractionLength(0)))
                    )
                    
                    // Detailed Stats Cards
                    LazyVStack(spacing: AppTheme.Spacing.md) {
                        AthleteWeeklyStatsCard(stats: stats)
                        MonthlyStatsCard(stats: stats)
                        AllTimeStatsCard(stats: stats)
                    }

                    // Awards Section
                    AwardsPreviewSection()
                }
                .padding(AppTheme.Spacing.md)
            }
        }
    }
}

// MARK: - Profile Header
struct ProfileHeader: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    let athlete: Athlete

    private var textPrimary: Color {
        themeManager.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary
    }

    private var textSecondary: Color {
        themeManager.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary
    }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            // Profile Image - Compact & Refined
            AsyncImage(url: athlete.profile) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(AppTheme.Colors.primaryGradient)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    )
            }
            .frame(width: 100, height: 100)
            .clipShape(Circle())
            .overlay(Circle().stroke(AppTheme.Colors.accent.opacity(0.2), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)

            // Name and Identity
            VStack(spacing: AppTheme.Spacing.xs) {
                Text("\(athlete.firstname ?? "Unknown") \(athlete.lastname ?? "Athlete")")
                    .font(.system(.title, design: .monospaced).weight(.bold))
                    .foregroundColor(textPrimary)

                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    
                    Text("Digital Twin • Active Trajectory")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(textSecondary)
                        .tracking(0.5)
                }
            }
        }
    }
}

// MARK: - Quick Stats Grid
struct QuickStatsGrid: View {
    let runs: String
    let miles: String
    let minutes: String
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: AppTheme.Spacing.md) {
            QuickStatItem(
                icon: "figure.run",
                value: runs,
                label: "Total Runs",
                color: AppTheme.Colors.accent
            )

            QuickStatItem(
                icon: "road.lanes",
                value: miles,
                label: "Miles",
                color: AppTheme.Colors.accent
            )
            
            QuickStatItem(
                icon: "clock.fill",
                value: minutes,
                label: "Hours",
                color: AppTheme.Colors.warning
            )
        }
    }
}

// MARK: - Quick Stat Item
struct QuickStatItem: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    let icon: String
    let value: String
    let label: String
    let color: Color

    private var textPrimary: Color {
        themeManager.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary
    }

    private var textSecondary: Color {
        themeManager.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary
    }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
            }

            Text(value)
                .font(.system(.title, design: .monospaced).weight(.bold))
                .foregroundColor(textPrimary)

            Text(label)
                .font(AppTheme.Typography.caption)
                .foregroundColor(textSecondary)
                .multilineTextAlignment(.center)
        }
        .surfaceCard()
    }
}

// MARK: - Athlete Weekly Stats Card
struct AthleteWeeklyStatsCard: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    let stats: AthleteStats
    @Environment(DataManager.self) private var dataManager
    @State private var weeklyRuns = 0
    @State private var weeklyDistanceValue: Double = 0.0
    @State private var weeklyTime = "0h 0m"

    private let weeklyGoal: Double = 50.0

    private var weeklyProgress: Double {
        min(weeklyDistanceValue / weeklyGoal, 1.0)
    }

    private var textPrimary: Color {
        themeManager.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary
    }

    private var textSecondary: Color {
        themeManager.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary
    }

    private var surfaceBackground: Color {
        themeManager.isDarkMode ? AppTheme.Colors.DarkMode.surfaceBackground : AppTheme.Colors.LightMode.surfaceBackground
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(AppTheme.Colors.accent)
                    .font(.title2)

                Text("This Week")
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(textPrimary)

                Spacer()
            }

            HStack(spacing: AppTheme.Spacing.lg) {
                StatPair(label: "Runs", value: String(weeklyRuns), color: AppTheme.Colors.accent)
                StatPair(label: "Distance", value: String(format: "%.1f / %.0f mi", weeklyDistanceValue, weeklyGoal), color: AppTheme.Colors.accent)
                StatPair(label: "Time", value: weeklyTime, color: AppTheme.Colors.warning)
                Spacer()
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(surfaceBackground)
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppTheme.Colors.accent)
                            .frame(width: geometry.size.width * weeklyProgress, height: 8)
                    }
                }
                .frame(height: 8)

                Text(String(format: "%.0f%% of weekly goal", weeklyProgress * 100))
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(textSecondary)
            }
        }
        .surfaceCard()
        .onAppear {
            loadWeeklyStats()
        }
        .onChange(of: dataManager.activities) { _, _ in
            loadWeeklyStats()
        }
    }

    private func loadWeeklyStats() {
        guard let userDefaults = UserDefaults(suiteName: "group.com.jackrudelic.runawayios") else {
            print("❌ WeeklyStatsCard: Failed to access shared UserDefaults")
            return
        }

        print("🔍 WeeklyStatsCard: Loading weekly stats from UserDefaults")

        let dayArrays = [
            userDefaults.stringArray(forKey: "sunArray") ?? [],
            userDefaults.stringArray(forKey: "monArray") ?? [],
            userDefaults.stringArray(forKey: "tueArray") ?? [],
            userDefaults.stringArray(forKey: "wedArray") ?? [],
            userDefaults.stringArray(forKey: "thuArray") ?? [],
            userDefaults.stringArray(forKey: "friArray") ?? [],
            userDefaults.stringArray(forKey: "satArray") ?? []
        ]

        var totalRuns = 0
        var totalDistance = 0.0
        var totalTime = 0.0

        for dayArray in dayArrays {
            totalRuns += dayArray.count

            for activityJson in dayArray {
                if let data = activityJson.data(using: .utf8),
                   let activity = try? JSONDecoder().decode(RAActivity.self, from: data) {
                    totalDistance += activity.distance
                    totalTime += activity.time
                }
            }
        }

        weeklyRuns = totalRuns
        weeklyDistanceValue = totalDistance
        weeklyTime = formatTime(minutes: totalTime)

        print("✅ WeeklyStatsCard: Loaded - Runs: \(totalRuns), Distance: \(totalDistance) mi, Time: \(totalTime) min")
    }
}

// MARK: - Monthly Stats Card
struct MonthlyStatsCard: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    let stats: AthleteStats
    @Environment(DataManager.self) private var dataManager
    @State private var monthlyRuns = 0
    @State private var monthlyDistanceValue: Double = 0.0
    @State private var averagePace = "0:00"

    private let monthlyGoal: Double = 200.0

    private var monthlyProgress: Double {
        min(monthlyDistanceValue / monthlyGoal, 1.0)
    }

    private var textPrimary: Color {
        themeManager.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary
    }

    private var textSecondary: Color {
        themeManager.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary
    }

    private var surfaceBackground: Color {
        themeManager.isDarkMode ? AppTheme.Colors.DarkMode.surfaceBackground : AppTheme.Colors.LightMode.surfaceBackground
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(AppTheme.Colors.accent)
                    .font(.title2)

                Text("This Month")
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(textPrimary)

                Spacer()
            }

            HStack(spacing: AppTheme.Spacing.lg) {
                StatPair(label: "Runs", value: String(monthlyRuns), color: AppTheme.Colors.accent)
                StatPair(label: "Distance", value: String(format: "%.1f / %.0f mi", monthlyDistanceValue, monthlyGoal), color: AppTheme.Colors.accent)
                StatPair(label: "Avg Pace", value: averagePace, color: AppTheme.Colors.warning)
                Spacer()
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(surfaceBackground)
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppTheme.Colors.accent)
                            .frame(width: geometry.size.width * monthlyProgress, height: 8)
                    }
                }
                .frame(height: 8)

                Text(String(format: "%.0f%% of monthly goal", monthlyProgress * 100))
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(textSecondary)
            }
        }
        .surfaceCard()
        .onAppear {
            loadMonthlyStats()
        }
        .onChange(of: dataManager.activities) { _, _ in
            loadMonthlyStats()
        }
    }
    
    private func loadMonthlyStats() {
        guard let userDefaults = UserDefaults(suiteName: "group.com.jackrudelic.runawayios") else {
            print("❌ MonthlyStatsCard: Failed to access shared UserDefaults")
            return
        }

        print("🔍 MonthlyStatsCard: Loading monthly stats from UserDefaults")
        
        // Get monthly distance from UserDefaults
        let monthlyMiles = userDefaults.double(forKey: "monthlyMiles")
        
        // Calculate monthly runs and pace from all activity data
        let dayArrays = [
            userDefaults.stringArray(forKey: "sunArray") ?? [],
            userDefaults.stringArray(forKey: "monArray") ?? [],
            userDefaults.stringArray(forKey: "tueArray") ?? [],
            userDefaults.stringArray(forKey: "wedArray") ?? [],
            userDefaults.stringArray(forKey: "thuArray") ?? [],
            userDefaults.stringArray(forKey: "friArray") ?? [],
            userDefaults.stringArray(forKey: "satArray") ?? []
        ]
        
        var totalMonthlyRuns = 0
        var totalMonthlyTime = 0.0
        var totalMonthlyDistance = 0.0
        
        // Count all activities (not just this week) for monthly stats
        // Note: This is an approximation since UserDefaults only stores weekly data
        // For more accurate monthly data, you'd need to store monthly activity arrays separately
        for dayArray in dayArrays {
            for activityJson in dayArray {
                if let data = activityJson.data(using: .utf8),
                   let activity = try? JSONDecoder().decode(RAActivity.self, from: data) {
                    totalMonthlyRuns += 1
                    totalMonthlyTime += activity.time
                    totalMonthlyDistance += activity.distance
                }
            }
        }
        
        // Use the stored monthly miles if available, otherwise use calculated value
        let displayDistance = monthlyMiles > 0 ? monthlyMiles : totalMonthlyDistance

        monthlyRuns = totalMonthlyRuns
        monthlyDistanceValue = displayDistance

        // Calculate average pace (minutes per mile)
        if displayDistance > 0 && totalMonthlyTime > 0 {
            let avgPaceMinutes = totalMonthlyTime / displayDistance
            let paceMinutes = Int(avgPaceMinutes)
            let paceSeconds = Int((avgPaceMinutes - Double(paceMinutes)) * 60)
            averagePace = String(format: "%d:%02d", paceMinutes, paceSeconds)
        } else {
            averagePace = "0:00"
        }

        print("✅ MonthlyStatsCard: Loaded - Runs: \(totalMonthlyRuns), Distance: \(displayDistance) mi, Time: \(totalMonthlyTime) min, MonthlyMiles from UserDefaults: \(monthlyMiles)")
    }
}

// MARK: - All Time Stats Card
struct AllTimeStatsCard: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    let stats: AthleteStats

    private var textPrimary: Color {
        themeManager.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundColor(AppTheme.Colors.warning)
                    .font(.title2)

                Text("All Time")
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(textPrimary)

                Spacer()
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: AppTheme.Spacing.md) {
                StatPair(label: "Total Runs", value: "\(stats.count ?? 0)", color: AppTheme.Colors.accent)
                StatPair(label: "Total Distance", value: String(format: "%.1f mi", (stats.distance ?? 0.0) * 0.000621371), color: AppTheme.Colors.accent)
                StatPair(label: "Total Time", value: formatTime(minutes: (stats.elapsedTime ?? 0.0) / 60), color: AppTheme.Colors.warning)
                StatPair(label: "Best Pace", value: "6:45/mi", color: AppTheme.Colors.accent)
            }
        }
        .surfaceCard()
    }
}

// MARK: - Stat Pair
struct StatPair: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    let label: String
    let value: String
    let color: Color

    private var textSecondary: Color {
        themeManager.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text(value)
                .font(.system(.headline, design: .monospaced).weight(.bold))
                .foregroundColor(color)

            Text(label)
                .font(AppTheme.Typography.caption)
                .foregroundColor(textSecondary)
        }
    }
}

// MARK: - Helper Functions
private func formatTime(minutes: Double) -> String {
    let hours = Int(minutes) / 60
    let mins = Int(minutes) % 60
    
    if hours > 0 {
        return "\(hours)h \(mins)m"
    } else {
        return "\(mins)m"
    }
}

// MARK: - Twin Identity
struct TwinIdentityBadge: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    
    private var cardBg: Color {
        themeManager.isDarkMode ? AppTheme.Colors.DarkMode.cardBackground : AppTheme.Colors.LightMode.cardBackground
    }
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.accent.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: "brain.head.profile")
                    .foregroundColor(AppTheme.Colors.accent)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("TWIN IDENTITY")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AppTheme.Colors.accent)
                    .tracking(1.2)
                Text("The Consistent Builder")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(themeManager.isDarkMode ? .white : .black)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
        }
        .padding()
        .background(cardBg)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.07), lineWidth: 1))
    }
}
