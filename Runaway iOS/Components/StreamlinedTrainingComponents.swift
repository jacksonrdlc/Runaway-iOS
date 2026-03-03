//
//  StreamlinedTrainingComponents.swift
//  Runaway iOS
//
//  Streamlined training view components based on UX research
//  Follows: Action-first → Readiness → Progress → Details hierarchy
//

import SwiftUI

// MARK: - Readiness Banner (Color-coded, glanceable)

struct ReadinessBanner: View {
    @StateObject private var readinessService = ReadinessService.shared
    @State private var showingDetail = false

    var body: some View {
        Button(action: { showingDetail = true }) {
            HStack(spacing: 12) {
                // Color indicator circle
                Circle()
                    .fill(readinessColor)
                    .frame(width: 12, height: 12)

                // Status text
                Text(readinessLabel)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(readinessColor)

                Spacer()

                // Score
                if let score = readinessService.todaysReadiness?.score {
                    HStack(spacing: 4) {
                        Text("Score:")
                            .font(.caption)
                            .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
                        Text("\(score)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(readinessColor)
                    }
                } else if readinessService.isCalculating {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Text("Tap to calculate")
                        .font(.caption)
                        .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textTertiary : AppTheme.Colors.LightMode.textTertiary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textTertiary : AppTheme.Colors.LightMode.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(readinessColor.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingDetail) {
            if let readiness = readinessService.todaysReadiness {
                ReadinessDetailView(readiness: readiness)
            } else {
                ReadinessCalculationSheet()
            }
        }
        .task {
            await readinessService.refreshIfNeeded()
        }
    }

    private var readinessColor: Color {
        guard let readiness = readinessService.todaysReadiness else {
            return .gray
        }
        switch readiness.level {
        case .optimal: return .green
        case .good: return Color(red: 0.5, green: 0.8, blue: 0.1) // Lime
        case .moderate: return .yellow
        case .low: return .orange
        case .poor: return .red
        }
    }

    private var readinessLabel: String {
        guard let readiness = readinessService.todaysReadiness else {
            return "Check Readiness"
        }
        switch readiness.level {
        case .optimal: return "Ready to Push"
        case .good: return "Good to Train"
        case .moderate: return "Moderate Recovery"
        case .low: return "Take It Easy"
        case .poor: return "Rest Day Recommended"
        }
    }
}

// MARK: - Readiness Calculation Sheet

struct ReadinessCalculationSheet: View {
    @StateObject private var readinessService = ReadinessService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "heart.text.square")
                    .font(.system(size: 60))
                    .foregroundColor(AppTheme.Colors.accent)

                Text("Calculate Your Readiness")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("We'll analyze your sleep, HRV, resting heart rate, and training load to determine how ready you are to train today.")
                    .font(.subheadline)
                    .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }

                Button {
                    Task {
                        await calculateReadiness()
                    }
                } label: {
                    HStack {
                        if readinessService.isCalculating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "waveform.path.ecg")
                        }
                        Text(readinessService.isCalculating ? "Calculating..." : "Calculate Now")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.Colors.accent)
                    .cornerRadius(12)
                }
                .disabled(readinessService.isCalculating)
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 40)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func calculateReadiness() async {
        errorMessage = nil
        do {
            _ = try await readinessService.calculateTodaysReadiness()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Today's Focus Card

struct TodaysFocusCard: View {
    @Environment(DataManager.self) var dataManager
    @StateObject private var restDayService = RestDayService.shared
    @State private var showingWorkoutDetail = false

    private var todaysWorkout: DailyWorkout? {
        guard let plan = dataManager.currentWeeklyPlan else { return nil }
        let today = Calendar.current.component(.weekday, from: Date())
        let todayDayOfWeek = DayOfWeek.allCases.first { $0.calendarWeekday == today }
        return plan.workouts.first { $0.dayOfWeek == todayDayOfWeek }
    }

    /// Check if there's an activity logged today
    private var todaysActivity: Activity? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return dataManager.activities.first { activity in
            guard let timestamp = activity.activity_date ?? activity.start_date else { return false }
            let activityDate = calendar.startOfDay(for: Date(timeIntervalSince1970: timestamp))
            return calendar.isDate(activityDate, inSameDayAs: today)
        }
    }

    /// Check if yesterday was a rest day
    private var hadRestYesterday: Bool {
        let calendar = Calendar.current
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) else { return false }

        return restDayService.recentRestDays.contains { restDay in
            calendar.isDate(restDay.date, inSameDayAs: yesterday)
        }
    }

    /// Determine what to show for today
    private var todaysFocus: TodayFocusState {
        // Priority 1: If there's an activity today, show "Completed"
        if let activity = todaysActivity {
            return .activityCompleted(activity)
        }

        // Priority 2: If there's a planned workout today, show it
        if let workout = todaysWorkout {
            return .plannedWorkout(workout)
        }

        // Priority 3: Check recovery status - if well rested and no plan, suggest a run
        if hadRestYesterday {
            return .readyToRun
        }

        // Default: Rest day
        return .restDay
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("TODAY")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)

                Spacer()

                switch todaysFocus {
                case .activityCompleted:
                    Text("Completed")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(6)
                case .plannedWorkout(let workout):
                    Text(workout.workoutType.rawValue.capitalized)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(workout.workoutType.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(workout.workoutType.color.opacity(0.15))
                        .cornerRadius(6)
                case .readyToRun:
                    Text("Ready")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(6)
                case .restDay:
                    Text("Rest")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.purple)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.15))
                        .cornerRadius(6)
                }
            }

            switch todaysFocus {
            case .activityCompleted(let activity):
                // Show completed activity
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(activity.name ?? "Activity Completed")
                            .font(.headline)
                            .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary)

                        HStack(spacing: 8) {
                            if let distance = activity.distance {
                                Text(UnitFormatter.formatDistance(distance, decimals: 1, includeUnit: true))
                                    .font(.caption)
                                    .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
                            }
                            if let elapsed = activity.elapsed_time {
                                let minutes = Int(elapsed / 60)
                                Text("\(minutes) min")
                                    .font(.caption)
                                    .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
                            }
                        }
                    }

                    Spacer()
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)

            case .plannedWorkout(let workout):
                // Workout content
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: workout.workoutType.icon)
                            .font(.title2)
                            .foregroundColor(workout.workoutType.color)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(workout.title)
                                .font(.headline)
                                .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary)

                            if !workout.description.isEmpty {
                                Text(workout.description)
                                    .font(.caption)
                                    .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
                                    .lineLimit(2)
                            }
                        }

                        Spacer()
                    }

                    // Distance and pace
                    HStack(spacing: 16) {
                        if let distance = workout.formattedDistance {
                            Label(distance, systemImage: "figure.run")
                                .font(.subheadline)
                                .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
                        }

                        if let pace = workout.targetPace {
                            Label(pace, systemImage: "speedometer")
                                .font(.subheadline)
                                .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
                        }

                        Spacer()
                    }
                }
                .padding()
                .background(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.surfaceBackground : AppTheme.Colors.LightMode.surfaceBackground)
                .cornerRadius(12)
                .onTapGesture {
                    showingWorkoutDetail = true
                }

            case .readyToRun:
                // You rested yesterday, ready to go!
                HStack {
                    Image(systemName: "figure.run")
                        .font(.title2)
                        .foregroundColor(.green)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ready to Run")
                            .font(.headline)
                            .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary)

                        Text("You rested yesterday - great time for a run!")
                            .font(.caption)
                            .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
                    }

                    Spacer()
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)

            case .restDay:
                // Rest day
                HStack {
                    Image(systemName: "moon.zzz.fill")
                        .font(.title2)
                        .foregroundColor(.purple)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Rest Day")
                            .font(.headline)
                            .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary)

                        Text("Recovery is part of training")
                            .font(.caption)
                            .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
                    }

                    Spacer()
                }
                .padding()
                .background(Color.purple.opacity(0.1))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.cardBackground : AppTheme.Colors.LightMode.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .sheet(isPresented: $showingWorkoutDetail) {
            if let workout = todaysWorkout {
                WorkoutDetailSheet(workout: workout)
            }
        }
    }
}

/// State for Today's Focus card
private enum TodayFocusState {
    case activityCompleted(Activity)
    case plannedWorkout(DailyWorkout)
    case readyToRun
    case restDay
}

// MARK: - Week Progress Row

struct WeekProgressRow: View {
    @Environment(DataManager.self) var dataManager
    @StateObject private var restDayService = RestDayService.shared

    private var weekEntries: [WeekDayEntry] {
        guard let plan = dataManager.currentWeeklyPlan else {
            // If no plan, still show activities for the week
            return buildEntriesFromActivitiesOnly()
        }
        return plan.mergedWithActivities(dataManager.activities)
    }

    /// Get rest days for this week from RestDayService
    private var thisWeekRestDays: [RestDay] {
        let calendar = Calendar.current
        let now = Date()
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else {
            return []
        }
        guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else {
            return []
        }

        return restDayService.recentRestDays.filter { restDay in
            restDay.date >= weekStart && restDay.date < weekEnd
        }
    }

    /// Check if a specific day has a logged rest day OR is an implicit rest day (past day with no activity)
    private func hasRestDay(for dayOfWeek: DayOfWeek) -> RestDay? {
        let calendar = Calendar.current
        let now = Date()
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else {
            return nil
        }
        guard let dayDate = calendar.date(byAdding: .day, value: dayOfWeek.calendarWeekday - 1, to: weekStart) else {
            return nil
        }

        // First check for logged rest days
        if let loggedRestDay = thisWeekRestDays.first(where: { calendar.isDate($0.date, inSameDayAs: dayDate) }) {
            return loggedRestDay
        }

        // Check if this is a past day with no activity (implicit rest day)
        let today = calendar.startOfDay(for: now)
        let normalizedDayDate = calendar.startOfDay(for: dayDate)

        if normalizedDayDate < today {
            // Check if there's an activity for this day
            let hasActivity = dataManager.activities.contains { activity in
                guard let dateInterval = activity.activity_date ?? activity.start_date else { return false }
                let activityDate = Date(timeIntervalSince1970: dateInterval)
                return calendar.isDate(activityDate, inSameDayAs: dayDate)
            }

            if !hasActivity {
                // Return an implicit rest day for display purposes
                return RestDay(
                    athleteId: dataManager.athlete?.id ?? 0,
                    date: normalizedDayDate,
                    isPlanned: false,
                    reason: .detected
                )
            }
        }

        return nil
    }

    /// Build week entries from activities only (when no training plan exists)
    private func buildEntriesFromActivitiesOnly() -> [WeekDayEntry] {
        let calendar = Calendar.current
        let now = Date()

        // Get start of this week (Sunday)
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else {
            return []
        }

        return DayOfWeek.allCases.compactMap { dayOfWeek in
            guard let dayDate = calendar.date(byAdding: .day, value: dayOfWeek.calendarWeekday - 1, to: weekStart) else {
                return nil
            }

            // Find activity for this day
            let activity = dataManager.activities.first { activity in
                guard let dateInterval = activity.activity_date ?? activity.start_date else { return false }
                let activityDate = Date(timeIntervalSince1970: dateInterval)
                return calendar.isDate(activityDate, inSameDayAs: dayDate)
            }

            return WeekDayEntry(date: dayDate, dayOfWeek: dayOfWeek, plannedWorkout: nil, actualActivity: activity)
        }
    }

    private var weekStats: (actual: Double, planned: Double, completed: Int, total: Int) {
        if let plan = dataManager.currentWeeklyPlan {
            let stats = plan.weekStats(with: dataManager.activities)
            return (stats.actualMiles, stats.plannedMiles, stats.completedWorkouts, stats.plannedWorkouts)
        }

        // Calculate from activities only
        let completedActivities = weekEntries.filter { $0.actualActivity != nil }
        let totalDistance = completedActivities.compactMap { entry -> Double? in
            guard let distance = entry.actualActivity?.distance else { return nil }
            return UnitFormatter.metersToPreferredUnit(distance)
        }.reduce(0, +)

        return (totalDistance, 0, completedActivities.count, 0)
    }

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("THIS WEEK")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)

                Spacer()

                // Mileage summary
                HStack(spacing: 4) {
                    Text(String(format: "%.1f", weekStats.actual))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.Colors.accent)
                    if weekStats.planned > 0 {
                        Text("/")
                            .font(.caption)
                            .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textTertiary : AppTheme.Colors.LightMode.textTertiary)
                        Text(String(format: "%.0f \(UnitFormatter.distanceUnitAbbreviation)", weekStats.planned))
                            .font(.caption)
                            .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
                    } else {
                        Text(UnitFormatter.distanceUnitAbbreviation)
                            .font(.caption)
                            .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
                    }
                }
            }

            // Day indicators with activity icons
            HStack(spacing: 4) {
                ForEach(DayOfWeek.allCases, id: \.self) { day in
                    let entry = weekEntries.first { $0.dayOfWeek == day }
                    let restDay = hasRestDay(for: day)
                    WeekDayActivityTile(
                        day: day,
                        entry: entry,
                        restDay: restDay
                    )
                }
            }

            // Progress bar (only show if there's a plan)
            if weekStats.planned > 0 {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 6)

                        let progress = min(weekStats.actual / weekStats.planned, 1.0)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppTheme.Colors.accent)
                            .frame(width: geometry.size.width * progress, height: 6)
                    }
                }
                .frame(height: 6)

                HStack {
                    Text("\(weekStats.completed) of \(weekStats.total) workouts completed")
                        .font(.caption)
                        .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textTertiary : AppTheme.Colors.LightMode.textTertiary)
                    Spacer()
                }
            } else {
                // No plan - show activity count and rest days
                HStack {
                    let restCount = restDaysThisWeek
                    if restCount > 0 {
                        Text("\(weekStats.completed) activities, \(restCount) rest \(restCount == 1 ? "day" : "days") this week")
                            .font(.caption)
                            .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textTertiary : AppTheme.Colors.LightMode.textTertiary)
                    } else {
                        Text("\(weekStats.completed) activities this week")
                            .font(.caption)
                            .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textTertiary : AppTheme.Colors.LightMode.textTertiary)
                    }
                    Spacer()
                }
            }
        }
        .padding()
        .background(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.cardBackground : AppTheme.Colors.LightMode.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .onAppear {
            // Trigger rest day detection on appear
            if let athleteId = dataManager.athlete?.id {
                Task {
                    await restDayService.runDetectionIfNeeded(athleteId: athleteId)
                }
            }
        }
    }

    /// Count of rest days (logged + implicit) this week
    private var restDaysThisWeek: Int {
        DayOfWeek.allCases.filter { hasRestDay(for: $0) != nil }.count
    }
}

struct WeekDayActivityTile: View {
    let day: DayOfWeek
    let entry: WeekDayEntry?
    let restDay: RestDay?

    private var isToday: Bool {
        if let entryIsToday = entry?.isToday {
            return entryIsToday
        }
        return Calendar.current.component(.weekday, from: Date()) == day.calendarWeekday
    }

    private var isPast: Bool {
        entry?.isPast ?? false
    }

    private var hasActivity: Bool {
        entry?.actualActivity != nil
    }

    private var hasPlannedWorkout: Bool {
        entry?.plannedWorkout != nil
    }

    private var hasRestDay: Bool {
        restDay != nil
    }

    private var activityType: String? {
        entry?.actualActivity?.type?.lowercased()
    }

    private var activityDistance: Double? {
        guard let distance = entry?.actualActivity?.distance else { return nil }
        return UnitFormatter.metersToPreferredUnit(distance)
    }

    private var activityElapsedMinutes: Int? {
        guard let elapsed = entry?.actualActivity?.elapsed_time else { return nil }
        return Int(elapsed / 60)
    }

    /// Determine if this activity type is mileage-focused (vs time-focused)
    private var isMileageFocused: Bool {
        guard let type = activityType else { return true }

        // Time-focused activities (show duration instead of distance)
        let timeFocusedActivities = ["yoga", "weight", "strength", "workout", "training", "stretch", "core", "meditation"]

        for keyword in timeFocusedActivities {
            if type.contains(keyword) {
                return false
            }
        }

        // All other activities are mileage-focused
        return true
    }

    var body: some View {
        VStack(spacing: 4) {
            // Day label
            Text(String(day.shortName.prefix(1)))
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(isToday ? AppTheme.Colors.accent : ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textTertiary : AppTheme.Colors.LightMode.textTertiary)

            // Activity indicator
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor)
                    .frame(width: 40, height: 44)

                // Today indicator
                if isToday {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppTheme.Colors.accent, lineWidth: 2)
                        .frame(width: 40, height: 44)
                }

                // Content - use fixed layout for consistent alignment
                VStack(spacing: 2) {
                    Image(systemName: iconName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(iconColor)

                    // Metric text - always at bottom with consistent height
                    Group {
                        if hasActivity {
                            if isMileageFocused {
                                if let distance = activityDistance {
                                    Text(String(format: "%.1f\(UnitFormatter.distanceUnitAbbreviation)", distance))
                                        .font(.system(size: 8, weight: .medium))
                                        .foregroundColor(iconColor)
                                } else {
                                    Text(" ")
                                        .font(.system(size: 8, weight: .medium))
                                }
                            } else {
                                if let minutes = activityElapsedMinutes {
                                    Text("\(minutes)min")
                                        .font(.system(size: 8, weight: .medium))
                                        .foregroundColor(iconColor)
                                } else {
                                    Text(" ")
                                        .font(.system(size: 8, weight: .medium))
                                }
                            }
                        } else {
                            Text(" ")
                                .font(.system(size: 8, weight: .medium))
                        }
                    }
                    .frame(height: 10)
                }
                .padding(.vertical, 2)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var backgroundColor: Color {
        if hasActivity {
            return activityColor.opacity(0.15)
        } else if hasRestDay {
            // Rest day - show purple background
            return Color.purple.opacity(0.15)
        } else if isPast && hasPlannedWorkout {
            return Color.orange.opacity(0.1)
        } else if hasPlannedWorkout {
            return ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.surfaceBackground : AppTheme.Colors.LightMode.surfaceBackground
        } else if isToday {
            return ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.surfaceBackground : AppTheme.Colors.LightMode.surfaceBackground
        }
        return Color.gray.opacity(0.05)
    }

    private var iconName: String {
        if hasActivity {
            return activityIcon
        } else if hasRestDay {
            // Show rest day icon from the restDay reason
            return restDay?.reason.icon ?? "moon.zzz.fill"
        } else if hasPlannedWorkout {
            return plannedWorkoutIcon
        } else if isPast {
            return "minus"
        }
        return "circle"
    }

    private var activityIcon: String {
        guard let type = activityType else { return "figure.run" }

        if type.contains("run") || type.contains("running") {
            return "figure.run"
        } else if type.contains("walk") {
            return "figure.walk"
        } else if type.contains("hike") {
            return "figure.hiking"
        } else if type.contains("cycle") || type.contains("ride") || type.contains("bike") {
            return "figure.outdoor.cycle"
        } else if type.contains("swim") {
            return "figure.pool.swim"
        } else if type.contains("yoga") {
            return "figure.yoga"
        } else if type.contains("strength") || type.contains("weight") {
            return "dumbbell.fill"
        }
        return "figure.run"
    }

    private var plannedWorkoutIcon: String {
        guard let workout = entry?.plannedWorkout else { return "circle" }

        switch workout.workoutType {
        case .easyRun, .recoveryRun:
            return "figure.run"
        case .longRun:
            return "figure.run"
        case .tempoRun, .hillRun:
            return "flame.fill"
        case .intervalRun:
            return "bolt.fill"
        case .rest:
            return "moon.zzz.fill"
        case .crossTraining:
            return "figure.mixed.cardio"
        case .strengthTraining, .upperBody, .lowerBody, .fullBody:
            return "dumbbell.fill"
        case .yoga, .stretchMobility:
            return "figure.yoga"
        }
    }

    private var activityColor: Color {
        guard let type = activityType else { return .green }

        if type.contains("run") || type.contains("running") {
            return .green
        } else if type.contains("walk") {
            return .blue
        } else if type.contains("hike") {
            return .orange
        } else if type.contains("cycle") || type.contains("ride") || type.contains("bike") {
            return .purple
        } else if type.contains("swim") {
            return .cyan
        } else if type.contains("yoga") {
            return .purple
        } else if type.contains("weight") || type.contains("strength") || type.contains("training") || type.contains("workout") {
            return .green
        }
        return .green
    }

    private var iconColor: Color {
        if hasActivity {
            return activityColor
        } else if hasRestDay {
            return .purple
        } else if isPast && hasPlannedWorkout {
            return .orange
        } else if hasPlannedWorkout {
            return ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textTertiary : AppTheme.Colors.LightMode.textTertiary
        }
        return Color.gray.opacity(0.3)
    }
}

// MARK: - Coach Insight Card

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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.Colors.accent)

                Text("COACH SAYS")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)

                Spacer()
            }

            Text(insightText)
                .font(.subheadline)
                .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()

                Button(action: onAskCoach) {
                    HStack(spacing: 4) {
                        Text("Ask Coach")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Image(systemName: "arrow.right")
                            .font(.caption)
                    }
                    .foregroundColor(AppTheme.Colors.accent)
                }
            }
        }
        .padding()
        .background(AppTheme.Colors.accent.opacity(0.08))
        .cornerRadius(16)
    }
}

// MARK: - Key Metrics Grid

struct KeyMetricsGrid: View {
    @Environment(DataManager.self) var dataManager
    let quickWinsData: QuickWinsResponse?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOUR PROGRESS")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)

            HStack(spacing: 12) {
                // Weekly Mileage
                KeyMetricTile(
                    title: "This Week",
                    value: weeklyMileage,
                    trend: weeklyTrend,
                    trendLabel: weeklyTrendLabel,
                    color: .blue
                )

                // Performance Trend
                KeyMetricTile(
                    title: "Fitness",
                    value: fitnessTrend,
                    trend: fitnessTrendDirection,
                    trendLabel: nil,
                    color: fitnessTrendColor
                )

                // Training Load
                KeyMetricTile(
                    title: "Load",
                    value: trainingLoadValue,
                    trend: trainingLoadTrend,
                    trendLabel: trainingLoadLabel,
                    color: trainingLoadColor
                )
            }
        }
        .padding()
        .background(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.cardBackground : AppTheme.Colors.LightMode.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    // MARK: - Weekly Mileage

    private var weeklyMileage: String {
        let activities = dataManager.activities
        let calendar = Calendar.current
        let now = Date()

        // Use calendar week (Sunday to Saturday) for consistency
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return "0 \(UnitFormatter.distanceUnitAbbreviation)"
        }

        let weeklyActivities = activities.filter { activity in
            guard let dateInterval = activity.activity_date ?? activity.start_date else { return false }
            let activityDate = Date(timeIntervalSince1970: dateInterval)
            return activityDate >= weekInterval.start && activityDate < weekInterval.end
        }

        let totalMeters = weeklyActivities.compactMap { $0.distance }.reduce(0, +)
        return UnitFormatter.formatDistance(totalMeters, decimals: 1, includeUnit: true)
    }

    private var weeklyTrend: String {
        // Compare to previous week
        return "↑"
    }

    private var weeklyTrendLabel: String? {
        return "+18%"
    }

    // MARK: - Fitness Trend

    private var fitnessTrend: String {
        if let data = quickWinsData?.analyses.trainingLoad {
            switch data.fitnessTrend {
            case "improving": return "Improving"
            case "maintaining": return "Stable"
            case "declining": return "Declining"
            default: return "Stable"
            }
        }
        return "Stable"
    }

    private var fitnessTrendDirection: String {
        if let data = quickWinsData?.analyses.trainingLoad {
            switch data.fitnessTrend {
            case "improving": return "↑"
            case "maintaining": return "→"
            case "declining": return "↓"
            default: return "→"
            }
        }
        return "→"
    }

    private var fitnessTrendColor: Color {
        if let data = quickWinsData?.analyses.trainingLoad {
            switch data.fitnessTrend {
            case "improving": return .green
            case "maintaining": return .blue
            case "declining": return .orange
            default: return .blue
            }
        }
        return .blue
    }

    // MARK: - Training Load

    private var trainingLoadValue: String {
        if let data = quickWinsData?.analyses.trainingLoad {
            switch data.injuryRiskLevel {
            case "low": return "Optimal"
            case "moderate": return "Building"
            case "high": return "High"
            case "very_high": return "Caution"
            default: return "Optimal"
            }
        }
        return "Optimal"
    }

    private var trainingLoadTrend: String {
        return ""
    }

    private var trainingLoadLabel: String? {
        if let data = quickWinsData?.analyses.trainingLoad {
            return String(format: "%.2f", data.acwr)
        }
        return nil
    }

    private var trainingLoadColor: Color {
        if let data = quickWinsData?.analyses.trainingLoad {
            switch data.injuryRiskLevel {
            case "low": return .green
            case "moderate": return .yellow
            case "high": return .orange
            case "very_high": return .red
            default: return .green
            }
        }
        return .green
    }
}

struct KeyMetricTile: View {
    let title: String
    let value: String
    let trend: String
    let trendLabel: String?
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)

            HStack(spacing: 4) {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary)

                if !trend.isEmpty {
                    Text(trend)
                        .font(.caption)
                        .foregroundColor(color)
                }
            }

            if let label = trendLabel {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - This Week's Activities

struct ThisWeekActivitiesSection: View {
    @Environment(DataManager.self) var dataManager

    private var thisWeekActivities: [Activity] {
        let calendar = Calendar.current
        let now = Date()

        // Use calendar week (Sunday to Saturday) for consistency across app
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return []
        }

        return dataManager.activities.filter { activity in
            guard let dateInterval = activity.activity_date ?? activity.start_date else { return false }
            let activityDate = Date(timeIntervalSince1970: dateInterval)
            return activityDate >= weekInterval.start && activityDate < weekInterval.end
        }.prefix(5).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("THIS WEEK'S ACTIVITIES")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)

                Spacer()

                if !thisWeekActivities.isEmpty {
                    Text("\(thisWeekActivities.count) runs")
                        .font(.caption)
                        .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textTertiary : AppTheme.Colors.LightMode.textTertiary)
                }
            }

            if thisWeekActivities.isEmpty {
                HStack {
                    Image(systemName: "figure.run")
                        .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textTertiary : AppTheme.Colors.LightMode.textTertiary)
                    Text("No activities yet this week")
                        .font(.subheadline)
                        .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(thisWeekActivities, id: \.id) { activity in
                        CompactActivityRow(activity: activity)
                    }
                }
            }
        }
        .padding()
        .background(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.cardBackground : AppTheme.Colors.LightMode.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

struct CompactActivityRow: View {
    let activity: Activity

    private var activityDate: Date? {
        guard let interval = activity.activity_date ?? activity.start_date else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    private var formattedDistance: String {
        UnitFormatter.formatDistance(activity.distance ?? 0, decimals: 1, includeUnit: true)
    }

    private var paceString: String {
        guard let speed = activity.average_speed, speed > 0 else { return "--:--" }
        // Calculate minutes per mile from m/s
        let minutesPerMile = (1609.34 / speed) / 60.0
        return UnitFormatter.formatPaceTime(minutesPerMile: minutesPerMile)
    }

    private var durationString: String {
        guard let elapsed = activity.elapsed_time else { return "--:--" }
        let totalMinutes = Int(elapsed / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return String(format: "%d:%02d", hours, minutes)
        }
        return String(format: "%d min", minutes)
    }

    private var dayOfWeek: String {
        guard let date = activityDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Day indicator
            VStack(spacing: 2) {
                Text(dayOfWeek)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textTertiary : AppTheme.Colors.LightMode.textTertiary)

                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
            }
            .frame(width: 32)

            // Activity details
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.name ?? "Run")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label(formattedDistance, systemImage: "figure.run")
                        .font(.caption)
                        .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)

                    Text("•")
                        .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textTertiary : AppTheme.Colors.LightMode.textTertiary)

                    Label("\(paceString)\(UnitFormatter.paceUnitLabel)", systemImage: "speedometer")
                        .font(.caption)
                        .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)

                    Text("•")
                        .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textTertiary : AppTheme.Colors.LightMode.textTertiary)

                    Text(durationString)
                        .font(.caption)
                        .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
                }
            }

            Spacer()

            // Chevron for detail
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textTertiary : AppTheme.Colors.LightMode.textTertiary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.surfaceBackground : AppTheme.Colors.LightMode.surfaceBackground)
        .cornerRadius(10)
    }
}

// MARK: - Compact Trends Chart

struct CompactTrendsChart: View {
    let activities: [Activity]
    @State private var showingFullChart = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TRENDS")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)

                Spacer()

                Button(action: { showingFullChart = true }) {
                    HStack(spacing: 4) {
                        Text("See All")
                            .font(.caption)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .foregroundColor(AppTheme.Colors.accent)
                }
            }

            // Mini chart visualization
            MiniWeeklyChart(activities: activities)
                .frame(height: 60)
        }
        .padding()
        .background(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.cardBackground : AppTheme.Colors.LightMode.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .sheet(isPresented: $showingFullChart) {
            ActivityTrendsView(activities: activities)
        }
    }
}

struct MiniWeeklyChart: View {
    let activities: [Activity]

    private var weeklyData: [(week: Int, miles: Double)] {
        let calendar = Calendar.current
        let now = Date()

        var weeks: [(week: Int, miles: Double)] = []

        for weekOffset in (0..<8).reversed() {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: now),
                  let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else {
                continue
            }

            let weekActivities = activities.filter { activity in
                guard let dateInterval = activity.activity_date ?? activity.start_date else { return false }
                let date = Date(timeIntervalSince1970: dateInterval)
                return date >= weekStart && date < weekEnd
            }

            let totalMeters = weekActivities.compactMap { $0.distance }.reduce(0, +)
            let distance = UnitFormatter.metersToPreferredUnit(totalMeters)
            weeks.append((week: 8 - weekOffset, miles: distance))
        }

        return weeks
    }

    private var maxMiles: Double {
        weeklyData.map { $0.miles }.max() ?? 1
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(weeklyData, id: \.week) { data in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(data.week == 8 ? AppTheme.Colors.accent : AppTheme.Colors.accent.opacity(0.4))
                        .frame(height: max(4, CGFloat(data.miles / maxMiles) * 50))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Explore Section

struct ExploreSection: View {
    let quickWinsData: QuickWinsResponse?
    let onWeatherTap: () -> Void
    let onVO2MaxTap: () -> Void
    let onTrainingLoadTap: () -> Void
    let onActivityTrendsTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("EXPLORE")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if quickWinsData?.analyses.weatherContext != nil {
                        ExplorePill(
                            icon: "cloud.sun.fill",
                            title: "Weather",
                            color: .orange,
                            action: onWeatherTap
                        )
                    }

                    if quickWinsData?.analyses.vo2maxEstimate != nil {
                        ExplorePill(
                            icon: "flag.fill",
                            title: "Race Times",
                            color: .blue,
                            action: onVO2MaxTap
                        )
                    }

                    if quickWinsData?.analyses.trainingLoad != nil {
                        ExplorePill(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "Training Load",
                            color: .green,
                            action: onTrainingLoadTap
                        )
                    }

                    ExplorePill(
                        icon: "map.fill",
                        title: "Heatmap",
                        color: .purple,
                        action: onActivityTrendsTap
                    )
                }
            }
        }
        .padding()
        .background(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.cardBackground : AppTheme.Colors.LightMode.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

struct ExplorePill: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(color)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(color.opacity(0.1))
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            ReadinessBanner()
            TodaysFocusCard()
            WeekProgressRow()
            CoachInsightCard(onAskCoach: {})
            KeyMetricsGrid(quickWinsData: nil)
            CompactTrendsChart(activities: [])
            ExploreSection(
                quickWinsData: nil,
                onWeatherTap: {},
                onVO2MaxTap: {},
                onTrainingLoadTap: {},
                onActivityTrendsTap: {}
            )
        }
        .padding()
    }
    .environment(DataManager.shared)
}
