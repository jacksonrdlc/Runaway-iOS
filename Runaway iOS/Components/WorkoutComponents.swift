//
//  WorkoutComponents.swift
//  Runaway iOS
//

import SwiftUI

enum TodayActivityCompletionPolicy {
    static func completedActivity(
        for plannedWorkout: DailyWorkout?,
        among activities: [Activity],
        on date: Date,
        calendar: Calendar = .current
    ) -> Activity? {
        activities.first { activity in
            guard let timestamp = activity.activity_date ?? activity.start_date,
                  calendar.isDate(Date(timeIntervalSince1970: timestamp), inSameDayAs: date) else {
                return false
            }
            guard let plannedWorkout else { return true }
            return activity.isCompatible(with: plannedWorkout.workoutType)
        }
    }
}

// MARK: - Workout Components

struct TodaysFocusCard: View {
    @Environment(DataManager.self) var dataManager
    @StateObject private var restDayService = RestDayService.shared
    @StateObject private var readinessService = ReadinessService.shared
    @EnvironmentObject private var trainingProfileStore: TrainingProfileStore
    @State private var showingWorkoutDetail = false
    @State private var showingTrainingDecision = false
    @State private var changeReceipt: TodayWorkoutAdjustmentResult?
    @State private var planBeforeAdjustment: WeeklyTrainingPlan?

    private var todaysWorkout: DailyWorkout? {
        guard let plan = dataManager.currentWeeklyPlan else { return nil }
        let today = Calendar.current.component(.weekday, from: Date())
        let todayDayOfWeek = DayOfWeek.allCases.first { $0.calendarWeekday == today }
        return plan.workouts.first { $0.dayOfWeek == todayDayOfWeek }
    }

    /// Check if there's an activity logged today
    private var todaysActivity: Activity? {
        TodayActivityCompletionPolicy.completedActivity(
            for: todaysWorkout,
            among: dataManager.activities,
            on: Date()
        )
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

        let recommendation = recommendation

        // Recovery guidance overrides generic and planned workout prompts.
        if recommendation.directive == .recover {
            return .readinessRecommendation(recommendation)
        }

        // A planned workout remains visible when readiness supports training.
        if let workout = todaysWorkout,
           recommendation.workoutType == workout.workoutType {
            return .plannedWorkout(
                workout,
                TodayRecommendationPresentation(recommendation: recommendation)
            )
        }

        if recommendation.workoutType != nil {
            return .readinessRecommendation(recommendation)
        }

        if recommendation.directive == .reduceIntensity || recommendation.directive == .unknown {
            return .readinessRecommendation(recommendation)
        }

        // Priority 3: Only suggest rest when user exercised yesterday and may need recovery
        if hadActivityYesterday {
            return .restDay
        }

        // Default: encourage a run
        return .readyToRun
    }

    private var recommendation: TodayRecommendation {
        let date = Date()
        let workouts = dataManager.currentWeeklyPlan?.workouts ?? []
        let context = TodayRecommendationContextBuilder.build(
            date: date,
            profile: trainingProfileStore.profile,
            plannedWorkout: todaysWorkout,
            planWorkouts: workouts,
            activities: dataManager.activities,
            readinessScore: readinessService.todaysReadiness?.score
        )

        return TodayRecommendationPolicy.recommendation(
            plannedWorkout: todaysWorkout,
            profile: trainingProfileStore.profile,
            recentCompletedWorkouts: context.recentCompletedWorkouts,
            readinessScore: readinessService.todaysReadiness?.score,
            schedulingContext: context.schedulingContext
        )
    }

    private func activityAccent(for accent: TodayRecommendationAccent) -> Color {
        switch accent {
        case .runningPrimary:
            return AppTheme.Colors.warmAmber
        case .aerobic:
            return AppTheme.Colors.strideBlue
        case .recovery:
            return AppTheme.Colors.recoveryMint
        case .workout(let workoutType):
            return workoutType.color
        }
    }

    private var shouldOfferTrainingDecision: Bool {
        guard todaysActivity == nil,
              let workout = todaysWorkout,
              workout.workoutType != .rest,
              !workout.description.hasPrefix("Adjusted for today's readiness") else {
            return false
        }
        return recommendation.directive == .recover || recommendation.directive == .reduceIntensity
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
                case .plannedWorkout(_, let presentation):
                    Text(presentation.badgeText)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(activityAccent(for: presentation.accent))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(activityAccent(for: presentation.accent).opacity(0.15))
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
                case .readinessRecommendation(let recommendation):
                    let presentation = TodayRecommendationPresentation(recommendation: recommendation)
                    Text(recommendation.badgeTitle)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(activityAccent(for: presentation.accent))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(activityAccent(for: presentation.accent).opacity(0.15))
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

            case .plannedWorkout(let workout, let presentation):
                Button {
                    showingWorkoutDetail = true
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small + 2)
                                .fill(activityAccent(for: presentation.accent).opacity(0.16))
                                .frame(width: 44, height: 44)
                            Image(systemName: presentation.systemImage)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(activityAccent(for: presentation.accent))
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(presentation.title)
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
                            if let reason = presentation.reason {
                                Text(reason)
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
                    }
                    .contentShape(Rectangle())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(AppTheme.Colors.DarkMode.surfaceBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small + 4))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("View \(workout.title) details")
                .accessibilityHint("Opens the planned workout details.")

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

            case .readinessRecommendation(let recommendation):
                let presentation = TodayRecommendationPresentation(recommendation: recommendation)
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small + 2)
                            .fill(activityAccent(for: presentation.accent).opacity(0.16))
                            .frame(width: 44, height: 44)
                        Image(systemName: recommendation.systemImage)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(activityAccent(for: presentation.accent))
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(recommendation.title)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        Text(recommendation.detail)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
                            .lineLimit(2)
                        if let reason = recommendation.reason {
                            Text(reason)
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AppTheme.Colors.DarkMode.surfaceBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small + 4))
            }

            if case let .plannedWorkout(workout, _) = todaysFocus, todaysActivity == nil {
                NativeTrainingSummaryStrip(workout: workout)
            }


            if shouldOfferTrainingDecision {
                Button {
                    showingTrainingDecision = true
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 13, weight: .semibold))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Review today's plan")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                            Text("Choose a safer version without changing the rest of your week")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(AppTheme.Colors.success)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(AppTheme.Colors.success.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small + 4))
                }
                .buttonStyle(.plain)
            }

            if let receipt = changeReceipt {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppTheme.Colors.success)
                        .padding(.top, 1)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(receipt.receiptTitle)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        Text(receipt.receiptDetail)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Button("Undo") {
                        if let planBeforeAdjustment {
                            do {
                                try dataManager.updateCurrentWeeklyPlan(planBeforeAdjustment)
                            } catch {
                                #if DEBUG
                                print("Failed to restore plan: \(error)")
                                #endif
                                return
                            }
                        }
                        self.planBeforeAdjustment = nil
                        changeReceipt = nil
                    }
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.success)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                    .accessibilityLabel("Undo workout adjustment")
                    .accessibilityHint("Restores the originally planned workout.")
                }
                .padding(12)
                .background(AppTheme.Colors.success.opacity(0.08))
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
        .sheet(isPresented: $showingTrainingDecision) {
            if let workout = todaysWorkout {
                TrainingDecisionSheet(workout: workout, recommendation: recommendation) { adjustment in
                    guard let plan = dataManager.currentWeeklyPlan,
                          let result = TodayRecommendationPolicy.applying(
                            adjustment,
                            to: plan,
                            readinessScore: readinessService.todaysReadiness?.score
                          ) else { return }
                    do {
                        try dataManager.updateCurrentWeeklyPlan(result.plan)
                        planBeforeAdjustment = plan
                        changeReceipt = result
                    } catch {
                        #if DEBUG
                        print("Failed to update plan: \(error)")
                        #endif
                    }
                }
            }
        }
    }
}

@MainActor
struct TrainingPersonalizationRoute {
    let store: TrainingProfileStore

    var shouldShowPrompt: Bool {
        store.needsPersonalization
    }

    var editorRoute: TrainingProfileRoute {
        TrainingProfileRoute(store: store)
    }

    func dismiss() {
        store.dismissPersonalizationPrompt()
    }
}

enum TrainingPersonalizationStatus: String, Equatable {
    case needsPersonalization = "Personalization needed"
    case personalized = "Personalized"
}

struct TrainingActionPresentation: Equatable {
    let accessibilityLabel: String
    let accessibilityHint: String
    let minimumTargetSize: CGFloat
}

struct TrainingPersonalizationPromptDescriptor: Identifiable {
    let id = "today-training-personalization"
    let route: TrainingPersonalizationRoute
    let personalizeAction: TrainingActionPresentation
    let dismissAction: TrainingActionPresentation
}

enum TrainingPersonalizationPresentation {
    @MainActor
    static func todayPrompts(for store: TrainingProfileStore) -> [TrainingPersonalizationPromptDescriptor] {
        let route = TrainingPersonalizationRoute(store: store)
        guard route.shouldShowPrompt else { return [] }
        return [
            TrainingPersonalizationPromptDescriptor(
                route: route,
                personalizeAction: TrainingActionPresentation(
                    accessibilityLabel: "Personalize training",
                    accessibilityHint: "Opens your training profile editor.",
                    minimumTargetSize: AppTheme.Layout.touchTargetMinimum
                ),
                dismissAction: TrainingActionPresentation(
                    accessibilityLabel: "Dismiss training personalization",
                    accessibilityHint: "Hides this card without changing your profile or plans.",
                    minimumTargetSize: AppTheme.Layout.touchTargetMinimum
                )
            )
        ]
    }

    @MainActor
    static func settingsStatus(for store: TrainingProfileStore) -> TrainingPersonalizationStatus {
        store.hasPersonalizedProfile ? .personalized : .needsPersonalization
    }
}

struct TrainingPersonalizationPromptCard: View {
    @ObservedObject var store: TrainingProfileStore
    @State private var isPresentingEditor = false

    private var route: TrainingPersonalizationRoute {
        TrainingPersonalizationRoute(store: store)
    }

    var body: some View {
        ForEach(TrainingPersonalizationPresentation.todayPrompts(for: store)) { descriptor in
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.warmAmber)
                        .frame(width: 44, height: 44)
                        .background(AppTheme.Colors.warmAmber.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        Text("Make your week feel like yours")
                            .font(AppTheme.Typography.title3)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        Text("Tell Runaway how running, strength, and recovery fit together.")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: AppTheme.Spacing.sm) {
                    Button("Not now") {
                        route.dismiss()
                    }
                    .font(AppTheme.Typography.subheadlineBold)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .frame(minWidth: 88, minHeight: descriptor.dismissAction.minimumTargetSize)
                    .contentShape(Rectangle())
                    .accessibilityLabel(descriptor.dismissAction.accessibilityLabel)
                    .accessibilityHint(descriptor.dismissAction.accessibilityHint)

                    Button {
                        isPresentingEditor = true
                    } label: {
                        Text("Personalize training")
                            .font(AppTheme.Typography.subheadlineBold)
                            .frame(maxWidth: .infinity, minHeight: descriptor.personalizeAction.minimumTargetSize)
                    }
                    .primaryButton()
                    .buttonStyle(.plain)
                    .accessibilityLabel(descriptor.personalizeAction.accessibilityLabel)
                    .accessibilityHint(descriptor.personalizeAction.accessibilityHint)
                }
            }
            .padding(AppTheme.Spacing.lg)
            .background(AppTheme.Colors.DarkMode.cardBackgroundElevated)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                    .stroke(AppTheme.Colors.warmAmber.opacity(0.2), lineWidth: 1)
            )
            .sheet(isPresented: $isPresentingEditor) {
                TrainingProfileView(route: descriptor.route.editorRoute)
            }
        }
    }
}

private struct TrainingDecisionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let workout: DailyWorkout
    let recommendation: TodayRecommendation
    let onSelect: (TodayWorkoutAdjustment) -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("TODAY'S TRAINING DECISION", systemImage: "waveform.path.ecg")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundColor(AppTheme.Colors.success)
                    Text(recommendation.title)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(recommendation.detail)
                        .font(.system(size: 15, design: .rounded))
                        .foregroundColor(AppTheme.Colors.DarkMode.textSecondary)
                }

                HStack(spacing: 12) {
                    Image(systemName: workout.workoutType.icon)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.warmAmber)
                        .frame(width: 42, height: 42)
                        .background(AppTheme.Colors.warmAmber.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 11))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Originally planned")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
                        Text(workout.title)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    if let distance = workout.formattedDistance {
                        Text(distance)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.Colors.DarkMode.textSecondary)
                    }
                }
                .padding(14)
                .background(AppTheme.Colors.DarkMode.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))

                VStack(spacing: 10) {
                    if recommendation.directive == .recover {
                        decisionButton(
                            title: "Take a recovery day",
                            detail: "Remove today's load and leave the rest of the week intact",
                            icon: "moon.zzz.fill",
                            adjustment: .recoveryDay,
                            emphasized: true
                        )
                        decisionButton(
                            title: "Make it an easy session",
                            detail: "Reduce running distance by 35% and remove intensity",
                            icon: "figure.walk",
                            adjustment: .easierWorkout
                        )
                    } else {
                        decisionButton(
                            title: "Make it an easy session",
                            detail: "Reduce running distance by 35% and remove intensity",
                            icon: "figure.walk",
                            adjustment: .easierWorkout,
                            emphasized: true
                        )
                        decisionButton(
                            title: "Take a recovery day",
                            detail: "Remove today's load and leave the rest of the week intact",
                            icon: "moon.zzz.fill",
                            adjustment: .recoveryDay
                        )
                    }

                    Button("Keep original workout") { dismiss() }
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.Colors.DarkMode.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }

                Spacer(minLength: 0)
            }
            .padding(20)
            .background(AppTheme.Colors.DarkMode.background.ignoresSafeArea())
            .navigationTitle("Adjust Today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.Colors.DarkMode.textSecondary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func decisionButton(
        title: String,
        detail: String,
        icon: String,
        adjustment: TodayWorkoutAdjustment,
        emphasized: Bool = false
    ) -> some View {
        Button {
            onSelect(adjustment)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Text(detail)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(emphasized ? Color.white.opacity(0.74) : AppTheme.Colors.DarkMode.textTertiary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(emphasized ? .white : AppTheme.Colors.success)
            .padding(14)
            .background(emphasized ? AppTheme.Colors.success.opacity(0.82) : AppTheme.Colors.DarkMode.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
        }
        .buttonStyle(.plain)
    }
}

/// State for Today's Focus card
private enum TodayFocusState {
    case activityCompleted(Activity)
    case plannedWorkout(DailyWorkout, TodayRecommendationPresentation)
    case readyToRun
    case restDay
    case readinessRecommendation(TodayRecommendation)
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
        let weekStart = TrainingPlanService.currentWeekSunday()
        let runningActivities = dataManager.activities.filter(\.isRunningWorkoutActivity)

        return DayOfWeek.allCases.compactMap { dayOfWeek in
            guard let dayDate = calendar.date(byAdding: .day, value: dayOfWeek.calendarWeekday - 1, to: weekStart) else {
                return nil
            }

            // Find activity for this day
            let activity = runningActivities.first { activity in
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

        let stats = WeeklyRunProgress.activitiesOnly(
            dataManager.activities,
            weekStart: TrainingPlanService.currentWeekSunday()
        )
        return (stats.actualMiles, 0, stats.completedRuns, 0)
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
        case .cycling, .swimming, .walking, .hiking: return "figure.mixed.cardio"
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
