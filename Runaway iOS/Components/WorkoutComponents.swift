//
//  WorkoutComponents.swift
//  Runaway iOS
//

import SwiftUI

// MARK: - Workout Components

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

    /// Check if there was an activity logged yesterday (user may need recovery)
    private var hadActivityYesterday: Bool {
        let calendar = Calendar.current
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) else { return false }
        return dataManager.activities.contains { activity in
            guard let ts = activity.activity_date ?? activity.start_date else { return false }
            return calendar.isDate(Date(timeIntervalSince1970: ts), inSameDayAs: yesterday)
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

        // Priority 3: Only suggest rest when user exercised yesterday and may need recovery
        if hadActivityYesterday {
            return .restDay
        }

        // Default: encourage a run
        return .readyToRun
    }

    private var nextUpLabel: String {
        let weekday = Calendar.current.component(.weekday, from: Date())
        let names = ["", "SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"]
        let name = weekday < names.count ? names[weekday] : "TODAY"
        return "NEXT UP · \(name)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                EyebrowLabel(text: nextUpLabel, color: AppTheme.Colors.warmAmber)
                Spacer()
                switch todaysFocus {
                case .activityCompleted:
                    Text("Completed")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.Colors.success)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.Colors.success.opacity(0.15))
                        .clipShape(Capsule())
                case .plannedWorkout(let workout):
                    Text(workout.workoutType.rawValue.capitalized)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(workout.workoutType.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(workout.workoutType.color.opacity(0.15))
                        .clipShape(Capsule())
                case .readyToRun:
                    Text("Ready")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.Colors.success)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.Colors.success.opacity(0.15))
                        .clipShape(Capsule())
                case .restDay:
                    Text("Rest")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.Colors.DarkMode.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                }
            }

            switch todaysFocus {
            case .activityCompleted(let activity):
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small + 2)
                            .fill(AppTheme.Colors.success.opacity(0.16))
                            .frame(width: 44, height: 44)
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.success)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(activity.name ?? "Activity Completed")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        HStack(spacing: 8) {
                            if let distance = activity.distance {
                                Text(UnitFormatter.formatDistance(distance, decimals: 1, includeUnit: true))
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
                            }
                            if let elapsed = activity.elapsed_time {
                                Text("· \(Int(elapsed / 60)) min")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AppTheme.Colors.success.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small + 4))

            case .plannedWorkout(let workout):
                HStack(spacing: 12) {
                    // Amber bolt disc
                    ZStack {
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small + 2)
                            .fill(AppTheme.Colors.warmAmber.opacity(0.16))
                            .frame(width: 44, height: 44)
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.warmAmber)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(workout.title)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        HStack(spacing: 8) {
                            if let distance = workout.formattedDistance {
                                Text(distance)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
                            }
                            if let pace = workout.targetPace {
                                Text("·")
                                    .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
                                    .font(.system(size: 12))
                                Text(pace)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
                            }
                        }
                        if !workout.description.isEmpty {
                            Text(workout.description)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AppTheme.Colors.DarkMode.surfaceBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small + 4))
                .onTapGesture {
                    showingWorkoutDetail = true
                }

            case .readyToRun:
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small + 2)
                            .fill(AppTheme.Colors.warmAmber.opacity(0.16))
                            .frame(width: 44, height: 44)
                        Image(systemName: "figure.run")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.warmAmber)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Ready to Run")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        Text("You rested yesterday — great time for a run")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AppTheme.Colors.DarkMode.surfaceBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small + 4))

            case .restDay:
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small + 2)
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 44, height: 44)
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.DarkMode.textSecondary)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Rest Day")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Recovery is part of training")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AppTheme.Colors.DarkMode.surfaceBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small + 4))
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.DarkMode.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium + 2))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium + 2)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
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
            HStack {
                EyebrowLabel(text: "THIS WEEK")
                Spacer()
                HStack(spacing: 4) {
                    Text(String(format: "%.1f", weekStats.actual))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Colors.warmAmber)
                        .monospacedDigit()
                    if weekStats.planned > 0 {
                        Text("/ \(String(format: "%.0f", weekStats.planned)) \(UnitFormatter.distanceUnitAbbreviation)")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
                    } else {
                        Text(UnitFormatter.distanceUnitAbbreviation)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
                    }
                }
            }

            HStack(spacing: 4) {
                ForEach(DayOfWeek.allCases, id: \.self) { day in
                    let entry = weekEntries.first { $0.dayOfWeek == day }
                    let restDay = hasRestDay(for: day)
                    WeekDayActivityTile(day: day, entry: entry, restDay: restDay)
                }
            }

            if weekStats.planned > 0 {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(AppTheme.Colors.warmAmber)
                            .frame(width: geometry.size.width * min(weekStats.actual / weekStats.planned, 1.0), height: 4)
                    }
                }
                .frame(height: 4)
                Text("\(weekStats.completed) of \(weekStats.total) workouts done")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
            } else {
                let restCount = restDaysThisWeek
                Text(restCount > 0
                    ? "\(weekStats.completed) activities, \(restCount) rest \(restCount == 1 ? "day" : "days") this week"
                    : "\(weekStats.completed) activities this week")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.DarkMode.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium + 2))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium + 2)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
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
            Text(String(day.shortName.prefix(1)))
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(isToday ? AppTheme.Colors.warmAmber : AppTheme.Colors.DarkMode.textTertiary)

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(tileBackground)
                    .frame(width: 40, height: 44)

                if isToday {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppTheme.Colors.warmAmber, lineWidth: 1.5)
                        .frame(width: 40, height: 44)
                }

                VStack(spacing: 2) {
                    Image(systemName: iconName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(tileIconColor)

                    Group {
                        if hasActivity {
                            if isMileageFocused, let distance = activityDistance {
                                Text(String(format: "%.1f\(UnitFormatter.distanceUnitAbbreviation)", distance))
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(tileIconColor)
                            } else if let minutes = activityElapsedMinutes {
                                Text("\(minutes)m")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(tileIconColor)
                            } else {
                                Text(" ").font(.system(size: 8))
                            }
                        } else {
                            Text(" ").font(.system(size: 8))
                        }
                    }
                    .frame(height: 10)
                }
                .padding(.vertical, 2)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var tileBackground: Color {
        if hasActivity { return activityColor.opacity(0.15) }
        if hasRestDay { return Color.white.opacity(0.06) }
        if isPast && hasPlannedWorkout { return AppTheme.Colors.warmAmber.opacity(0.08) }
        if hasPlannedWorkout || isToday { return AppTheme.Colors.DarkMode.surfaceBackground }
        return Color.white.opacity(0.03)
    }

    private var iconName: String {
        if hasActivity { return activityIcon }
        if hasRestDay { return restDay?.reason.icon ?? "moon.zzz.fill" }
        if hasPlannedWorkout { return plannedWorkoutIcon }
        if isPast { return "minus" }
        return "circle"
    }

    private var activityIcon: String {
        guard let type = activityType else { return "figure.run" }
        if type.contains("run") || type.contains("running") { return "figure.run" }
        if type.contains("walk") { return "figure.walk" }
        if type.contains("hike") { return "figure.hiking" }
        if type.contains("cycle") || type.contains("ride") || type.contains("bike") { return "figure.outdoor.cycle" }
        if type.contains("swim") { return "figure.pool.swim" }
        if type.contains("yoga") { return "figure.yoga" }
        if type.contains("strength") || type.contains("weight") { return "dumbbell.fill" }
        return "figure.run"
    }

    private var plannedWorkoutIcon: String {
        guard let workout = entry?.plannedWorkout else { return "circle" }
        switch workout.workoutType {
        case .easyRun, .recoveryRun, .longRun: return "figure.run"
        case .tempoRun, .hillRun: return "flame.fill"
        case .intervalRun: return "bolt.fill"
        case .rest: return "moon.zzz.fill"
        case .crossTraining: return "figure.mixed.cardio"
        case .strengthTraining, .upperBody, .lowerBody, .fullBody: return "dumbbell.fill"
        case .yoga, .stretchMobility: return "figure.yoga"
        }
    }

    private var activityColor: Color {
        AppTheme.Colors.activityColor(for: activityType ?? "")
    }

    private var tileIconColor: Color {
        if hasActivity { return activityColor }
        if hasRestDay { return AppTheme.Colors.DarkMode.textTertiary }
        if isPast && hasPlannedWorkout { return AppTheme.Colors.warmAmber.opacity(0.6) }
        if hasPlannedWorkout { return AppTheme.Colors.DarkMode.textTertiary }
        return Color.white.opacity(0.2)
    }
}
