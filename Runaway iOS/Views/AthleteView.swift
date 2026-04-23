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
    @Environment(DataManager.self) private var dataManager

    private var lifetimeMiles: Double { (stats.distance ?? 0) * 0.000621371 }
    private var lifetimeRuns: Int { stats.count ?? 0 }
    private var lifetimeHours: Int { Int((stats.elapsedTime ?? 0) / 3600) }

    private struct PREntry { let label: String; let meters: ClosedRange<Double> }
    private let prDistances: [PREntry] = [
        PREntry(label: "5K",           meters: 4700...5300),
        PREntry(label: "10K",          meters: 9400...10600),
        PREntry(label: "Half Marathon", meters: 19500...22000),
        PREntry(label: "Marathon",     meters: 40000...44500),
    ]

    private func bestTime(for range: ClosedRange<Double>) -> TimeInterval? {
        dataManager.activities
            .filter { a in
                guard let d = a.distance, let t = a.elapsed_time, d > 0, t > 0 else { return false }
                return range.contains(d)
            }
            .compactMap { $0.elapsed_time }
            .min()
    }

    private func formatPRTime(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    var body: some View {
        ZStack {
            AppTheme.Colors.DarkMode.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // ── Profile header ─────────────────────────────────────
                    HStack(spacing: 16) {
                        AsyncImage(url: athlete.profile) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            ZStack {
                                Circle().fill(AppTheme.Colors.warmAmber.opacity(0.16))
                                Text(String((athlete.firstname ?? "?").prefix(1)).uppercased())
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.Colors.warmAmber)
                            }
                        }
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(AppTheme.Colors.warmAmber.opacity(0.25), lineWidth: 1.5))

                        VStack(alignment: .leading, spacing: 3) {
                            Text([athlete.firstname, athlete.lastname].compactMap { $0 }.joined(separator: " "))
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text(locationSubtitle)
                                .font(.system(size: 13, design: .rounded))
                                .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
                        }
                        Spacer()
                    }

                    // ── LIFETIME ───────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        EyebrowLabel(text: "LIFETIME")
                        HStack(spacing: 0) {
                            LifetimeStatTile(value: String(format: "%.0f", lifetimeMiles), label: "MILES")
                            Rectangle().fill(Color.white.opacity(0.07)).frame(width: 1, height: 50)
                            LifetimeStatTile(value: "\(lifetimeRuns)", label: "RUNS")
                            Rectangle().fill(Color.white.opacity(0.07)).frame(width: 1, height: 50)
                            LifetimeStatTile(value: "\(lifetimeHours)", label: "HOURS")
                        }
                        .background(AppTheme.Colors.DarkMode.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.07), lineWidth: 1))
                    }

                    // ── PERSONAL BESTS ─────────────────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        EyebrowLabel(text: "PERSONAL BESTS")
                        VStack(spacing: 0) {
                            ForEach(Array(prDistances.enumerated()), id: \.offset) { index, entry in
                                if index > 0 {
                                    Divider().background(Color.white.opacity(0.06))
                                }
                                PersonalBestRow(
                                    distance: entry.label,
                                    time: bestTime(for: entry.meters).map { formatPRTime($0) }
                                )
                            }
                        }
                        .background(AppTheme.Colors.DarkMode.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.07), lineWidth: 1))
                    }

                    // ── ACCOUNT ────────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        EyebrowLabel(text: "ACCOUNT")
                        VStack(spacing: 0) {
                            AccountRow(icon: "bolt.fill", title: "Strava", subtitle: stravaSubtitle)
                            Divider().background(Color.white.opacity(0.06)).padding(.leading, 64)
                            AccountRow(icon: "applewatch", title: "Devices & sensors", subtitle: "Apple Watch")
                            Divider().background(Color.white.opacity(0.06)).padding(.leading, 64)
                            AccountRow(icon: "chart.bar.fill", title: "Training preferences", subtitle: "Goals & zones")
                            Divider().background(Color.white.opacity(0.06)).padding(.leading, 64)
                            AccountRow(icon: "bell.fill", title: "Notifications", subtitle: "Workout reminders")
                        }
                        .background(AppTheme.Colors.DarkMode.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.07), lineWidth: 1))
                    }

                    Spacer(minLength: 32)
                }
                .padding(20)
            }
        }
    }

    // MARK: - Computed strings

    private var locationSubtitle: String {
        var parts: [String] = []
        if let city = athlete.city, !city.isEmpty { parts.append(city) }
        if let state = athlete.state, !state.isEmpty { parts.append(state) }
        if parts.isEmpty, let country = athlete.country, !country.isEmpty { parts.append(country) }
        let location = parts.joined(separator: ", ")
        let since = joinYear.map { "Runner since \($0)" }
        return [location, since].compactMap { $0 }.joined(separator: " · ")
    }

    private var joinYear: String? {
        guard let date = athlete.createdAt else { return nil }
        return "\(Calendar.current.component(.year, from: date))"
    }

    private var stravaSubtitle: String {
        guard athlete.stravaConnected == true else { return "Not connected" }
        if let syncedAt = athlete.stravaConnectedAt {
            let interval = Date().timeIntervalSince(syncedAt)
            if interval < 3600 { return "Synced · \(Int(interval / 60))m ago" }
            if interval < 86400 { return "Synced · \(Int(interval / 3600))h ago" }
            let days = Int(interval / 86400)
            return "Synced · \(days)d ago"
        }
        return "Connected"
    }
}

// MARK: - Personal Best Row
private struct PersonalBestRow: View {
    let distance: String
    let time: String? // nil = no PR yet

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(time != nil
                          ? AppTheme.Colors.warmAmber.opacity(0.16)
                          : Color.white.opacity(0.05))
                    .frame(width: 36, height: 36)
                Image(systemName: "star.fill")
                    .font(.system(size: 14))
                    .foregroundColor(time != nil
                                     ? AppTheme.Colors.warmAmber
                                     : AppTheme.Colors.DarkMode.textTertiary.opacity(0.4))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(distance)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Text(time != nil ? "Personal best" : "No PR yet")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
            }
            Spacer()
            Text(time ?? "--:--")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(time != nil ? .white : AppTheme.Colors.DarkMode.textTertiary)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(minHeight: 56)
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
    let hours: String
    
    var body: some View {
        HStack(spacing: 0) {
            QuickStatItem(value: runs, label: "RUNS", color: AppTheme.Colors.accent)
            
            Divider()
                .frame(height: 40)
                .background(Color.white.opacity(0.08))
            
            QuickStatItem(value: miles, label: "MILES", color: AppTheme.Colors.accent)
            
            Divider()
                .frame(height: 40)
                .background(Color.white.opacity(0.08))
            
            QuickStatItem(value: hours, label: "HOURS", color: AppTheme.Colors.accent)
        }
        .padding(.vertical, 20)
        .background(AppTheme.Colors.DarkMode.cardBackground)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.07), lineWidth: 1))
    }
}

// MARK: - Quick Stat Item
struct QuickStatItem: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 24, weight: .heavy, design: .monospaced))
                .foregroundColor(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(AppTheme.Colors.DarkMode.textSecondary)
                .tracking(1.2)
        }
        .frame(maxWidth: .infinity)
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
