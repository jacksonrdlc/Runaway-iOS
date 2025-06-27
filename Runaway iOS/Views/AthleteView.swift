//
//  Profile.swift
//  RunawayUI
//
//  Created by Jack Rudelic on 7/17/24.
//

import SwiftUI
import Charts

struct AthleteView: View {
    let athlete: Athlete
    let stats: AthleteStats
    
    @State var userImage: String?
    @State var name: String?
    @State var runs: String? = ""
    @State var miles: String? = ""
    @State var minutes: String? = ""
    
    @State private var isAthleteDataReady = false
    @State private var isActivitiesDataReady = false
    
    var body: some View {
        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    // Profile Header
                    ProfileHeader(athlete: athlete)
                    
                    // Quick Stats Grid
                    QuickStatsGrid(runs: runs ?? "0", miles: miles ?? "0", minutes: minutes ?? "0")
                    
                    // Detailed Stats Cards
                    LazyVStack(spacing: AppTheme.Spacing.md) {
                        WeeklyStatsCard(stats: stats)
                        MonthlyStatsCard(stats: stats)
                        AllTimeStatsCard(stats: stats)
                    }
                }
                .padding(AppTheme.Spacing.md)
            }
        }
        .onAppear{
            setStats()
        }
    }
}

extension AthleteView {
    func setStats() {
        if let userDefaults = UserDefaults(suiteName: "group.com.jackrudelic.runawayios") {
            if let runsInt = stats.count {
                self.runs = String(runsInt)
                userDefaults.set(runsInt, forKey: "runs")
            }
            if let milesInt = stats.distance {
                self.miles = String(format: "%.1f", milesInt * Double(0.00062137))
                userDefaults.set(milesInt, forKey: "miles")
            }
            if let minutesInt = stats.elapsedTime {
                self.minutes = String(format: "%.0f", minutesInt / 60)
                userDefaults.set(minutesInt, forKey: "minutes")
            }
        }
    }
}

// MARK: - Profile Header
struct ProfileHeader: View {
    let athlete: Athlete
    
    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            // Profile Image - Much Smaller
            AsyncImage(url: athlete.profile) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(AppTheme.Colors.primaryGradient)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    )
            }
            .frame(width: 80, height: 80)
            .clipShape(Circle())
            .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
            
            // Name and Info
            VStack(spacing: AppTheme.Spacing.xs) {
                Text("\(athlete.firstname ?? "Unknown") \(athlete.lastname ?? "Athlete")")
                    .font(AppTheme.Typography.title)
                    .foregroundColor(AppTheme.Colors.primaryText)
                
                Text("Runner • Athlete")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.secondaryText)
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
                color: AppTheme.Colors.primary
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
    let icon: String
    let value: String
    let label: String
    let color: Color
    
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
                .font(AppTheme.Typography.title.weight(.bold))
                .foregroundColor(AppTheme.Colors.primaryText)
            
            Text(label)
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .surfaceCard()
    }
}

// MARK: - Weekly Stats Card
struct WeeklyStatsCard: View {
    let stats: AthleteStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(AppTheme.Colors.primary)
                    .font(.title2)
                
                Text("This Week")
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(AppTheme.Colors.primaryText)
                
                Spacer()
            }
            
            HStack(spacing: AppTheme.Spacing.lg) {
                StatPair(label: "Runs", value: "3", color: AppTheme.Colors.primary)
                StatPair(label: "Distance", value: "12.4 mi", color: AppTheme.Colors.accent)
                StatPair(label: "Time", value: "2h 15m", color: AppTheme.Colors.warning)
                Spacer()
            }
        }
        .surfaceCard()
    }
}

// MARK: - Monthly Stats Card
struct MonthlyStatsCard: View {
    let stats: AthleteStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(AppTheme.Colors.accent)
                    .font(.title2)
                
                Text("This Month")
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(AppTheme.Colors.primaryText)
                
                Spacer()
            }
            
            HStack(spacing: AppTheme.Spacing.lg) {
                StatPair(label: "Runs", value: "12", color: AppTheme.Colors.primary)
                StatPair(label: "Distance", value: "58.7 mi", color: AppTheme.Colors.accent)
                StatPair(label: "Avg Pace", value: "8:23", color: AppTheme.Colors.warning)
                Spacer()
            }
        }
        .surfaceCard()
    }
}

// MARK: - All Time Stats Card
struct AllTimeStatsCard: View {
    let stats: AthleteStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundColor(AppTheme.Colors.warning)
                    .font(.title2)
                
                Text("All Time")
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(AppTheme.Colors.primaryText)
                
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: AppTheme.Spacing.md) {
                StatPair(label: "Total Runs", value: "\(stats.count ?? 0)", color: AppTheme.Colors.primary)
                StatPair(label: "Total Distance", value: String(format: "%.1f mi", (stats.distance ?? 0.0) * 0.00062137), color: AppTheme.Colors.accent)
                StatPair(label: "Total Time", value: formatTime(minutes: (stats.elapsedTime ?? 0.0) / 60), color: AppTheme.Colors.warning)
                StatPair(label: "Best Pace", value: "6:45/mi", color: AppTheme.Colors.success)
            }
        }
        .surfaceCard()
    }
}

// MARK: - Stat Pair
struct StatPair: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text(value)
                .font(AppTheme.Typography.headline.weight(.bold))
                .foregroundColor(color)
            
            Text(label)
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.secondaryText)
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
