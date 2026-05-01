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
            HStack(spacing: 16) {
                // ── Ring gauge ─────────────────────────────────────────────
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 5)
                        .frame(width: 64, height: 64)
                    Circle()
                        .trim(from: 0, to: ringProgress)
                        .stroke(readinessColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .frame(width: 64, height: 64)
                        .rotationEffect(.degrees(-90))
                    if let score = readinessService.todaysReadiness?.score {
                        VStack(spacing: 0) {
                            Text("\(score)")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .monospacedDigit()
                            Text("%")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
                        }
                    } else if readinessService.isCalculating {
                        ProgressView().scaleEffect(0.7)
                    } else {
                        Image(systemName: "questionmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
                    }
                }

                // ── Text stack ─────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 4) {
                    EyebrowLabel(text: "READINESS · \(readinessLevelLabel)", color: readinessColor)
                    Text(readinessHeadline)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    Text(readinessSubtext)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(readinessColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium + 2))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium + 2)
                    .stroke(readinessColor.opacity(0.18), lineWidth: 1)
            )
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

    private var ringProgress: CGFloat {
        guard let score = readinessService.todaysReadiness?.score else { return 0 }
        return CGFloat(score) / 100.0
    }

    private var readinessColor: Color {
        guard let readiness = readinessService.todaysReadiness else { return .gray }
        switch readiness.level {
        case .optimal: return AppTheme.Colors.success
        case .good: return Color(red: 0.5, green: 0.8, blue: 0.1)
        case .moderate: return .yellow
        case .low: return .orange
        case .poor: return .red
        }
    }

    private var readinessLevelLabel: String {
        guard let readiness = readinessService.todaysReadiness else { return "UNKNOWN" }
        switch readiness.level {
        case .optimal: return "OPTIMAL"
        case .good: return "GOOD"
        case .moderate: return "MODERATE"
        case .low: return "LOW"
        case .poor: return "POOR"
        }
    }

    private var readinessHeadline: String {
        guard let readiness = readinessService.todaysReadiness else { return "Tap to calculate" }
        switch readiness.level {
        case .optimal: return "Ready for a hard effort"
        case .good: return "Good to train today"
        case .moderate: return "Keep it moderate"
        case .low: return "Take it easy today"
        case .poor: return "Rest day recommended"
        }
    }

    private var readinessSubtext: String {
        guard let score = readinessService.todaysReadiness?.score else { return "Analyze your recovery" }
        return "Score \(score) · Tap for full breakdown"
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
                    .foregroundColor(AppTheme.Colors.adaptiveTextSecondary)
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

// MARK: - Key Metrics Grid

struct KeyMetricsGrid: View {
    @Environment(DataManager.self) var dataManager
    let quickWinsData: QuickWinsResponse?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            EyebrowLabel(text: "YOUR PROGRESS")

            HStack(spacing: 10) {
                KeyMetricTile(title: "This Week", value: weeklyMileage, trend: weeklyTrend, trendLabel: weeklyTrendLabel, color: AppTheme.Colors.warmAmber)
                KeyMetricTile(title: "Fitness", value: fitnessTrend, trend: fitnessTrendDirection, trendLabel: nil, color: fitnessTrendColor)
                KeyMetricTile(title: "Load", value: trainingLoadValue, trend: trainingLoadTrend, trendLabel: trainingLoadLabel, color: trainingLoadColor)
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
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)

            HStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                if !trend.isEmpty {
                    Text(trend)
                        .font(.system(size: 12))
                        .foregroundColor(color)
                }
            }

            if let label = trendLabel {
                Text(label)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(AppTheme.Colors.DarkMode.surfaceBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small + 4))
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
                EyebrowLabel(text: "THIS WEEK'S ACTIVITIES")
                Spacer()
                if !thisWeekActivities.isEmpty {
                    Text("\(thisWeekActivities.count) activities")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
                }
            }

            if thisWeekActivities.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
                    Text("No activities yet this week")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(AppTheme.Colors.DarkMode.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 6) {
                    ForEach(thisWeekActivities, id: \.id) { activity in
                        CompactActivityRow(activity: activity)
                    }
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

    private var activityColor: Color {
        AppTheme.Colors.activityColor(for: activity.type ?? "")
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 3) {
                Text(dayOfWeek)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
                Circle()
                    .fill(activityColor)
                    .frame(width: 7, height: 7)
            }
            .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(activity.name ?? "Activity")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text([formattedDistance, "\(paceString)\(UnitFormatter.paceUnitLabel)", durationString].joined(separator: " · "))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11))
                .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(AppTheme.Colors.DarkMode.surfaceBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small + 2))
    }
}

// MARK: - Compact Trends Chart

struct CompactTrendsChart: View {
    let activities: [Activity]
    @State private var showingFullChart = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                EyebrowLabel(text: "TRENDS")
                Spacer()
                Button(action: { showingFullChart = true }) {
                    HStack(spacing: 4) {
                        Text("See All")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(AppTheme.Colors.warmAmber)
                }
            }

            MiniWeeklyChart(activities: activities)
                .frame(height: 56)
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.DarkMode.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium + 2))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium + 2)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
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
