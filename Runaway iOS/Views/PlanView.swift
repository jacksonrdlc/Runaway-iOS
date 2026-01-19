//
//  PlanView.swift
//  Runaway iOS
//
//  Dynamic training plan view - the Plan tab
//  Shows adaptive weekly plans that update based on recent workouts
//  Now includes segmented control for Training and Research sections
//

import SwiftUI

// MARK: - Plan Section Enum

enum PlanSection: String, CaseIterable {
    case training = "Training"
    case research = "Research"
}

struct PlanView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var viewModel = PlanViewModel()
    @State private var selectedSection: PlanSection = .training
    @State private var showingWorkoutDetail: DailyWorkout?
    @State private var showingGenerateConfirmation = false
    @State private var showingTrainingGuidelines = false

    private var colors: (background: Color, cardBg: Color, textPrimary: Color, textSecondary: Color, surface: Color) {
        if themeManager.isDarkMode {
            return (
                AppTheme.Colors.DarkMode.background,
                AppTheme.Colors.DarkMode.cardBackground,
                AppTheme.Colors.DarkMode.textPrimary,
                AppTheme.Colors.DarkMode.textSecondary,
                AppTheme.Colors.DarkMode.surfaceBackground
            )
        } else {
            return (
                AppTheme.Colors.LightMode.background,
                AppTheme.Colors.LightMode.cardBackground,
                AppTheme.Colors.LightMode.textPrimary,
                AppTheme.Colors.LightMode.textSecondary,
                AppTheme.Colors.LightMode.surfaceBackground
            )
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Segmented Control
            Picker("Section", selection: $selectedSection) {
                ForEach(PlanSection.allCases, id: \.self) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, AppTheme.Spacing.sm)
            .padding(.bottom, AppTheme.Spacing.sm)

            // Content based on selection
            switch selectedSection {
            case .training:
                trainingContent
            case .research:
                ResearchContentView()
                    .environmentObject(themeManager)
            }
        }
        .background(colors.background)
        .navigationTitle("Plan")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(themeManager.isDarkMode ? .dark : .light, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if selectedSection == .training {
                    Button(action: { showingTrainingGuidelines = true }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(AppTheme.Colors.accent)
                    }
                    .accessibilityLabel("Training Guidelines")
                }
            }
        }
        .sheet(item: $showingWorkoutDetail) { workout in
            PlanWorkoutDetailSheet(workout: workout)
        }
        .sheet(isPresented: $showingTrainingGuidelines) {
            TrainingGuidelinesSheet()
        }
        .task {
            await viewModel.loadPlan()
        }
    }

    // MARK: - Training Content

    @ViewBuilder
    private var trainingContent: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {
                if viewModel.isLoading {
                    LoadingPlanView()
                } else if let plan = viewModel.displayedPlan {
                    // Plan Header
                    PlanHeaderCard(
                        plan: plan,
                        insights: viewModel.adaptiveInsights,
                        onRegenerate: {
                            Task { await viewModel.regeneratePlan() }
                        },
                        isRegenerating: viewModel.isGenerating
                    )

                    // Baseline Transparency Card
                    if let baseline = viewModel.trainingBaseline {
                        BaselineTransparencyCard(baseline: baseline)
                    }

                    // Today's Workout (if current week and not rest day)
                    if let todayWorkout = viewModel.todaysWorkout,
                       todayWorkout.workoutType != .rest {
                        TodayWorkoutCard(
                            workout: todayWorkout,
                            actualActivity: viewModel.todaysActivity,
                            onTap: { showingWorkoutDetail = todayWorkout }
                        )
                    }

                    // Week Overview
                    WeekOverviewSection(
                        plan: plan,
                        activities: dataManager.activities,
                        onWorkoutTap: { workout in
                            showingWorkoutDetail = workout
                        }
                    )

                    // Adaptive Insights
                    if let insights = viewModel.adaptiveInsights {
                        AdaptiveInsightsCard(insights: insights)
                    }

                    // Training Principles
                    TrainingPrinciplesCard()

                } else {
                    // No plan - show generate prompt
                    NoPlanView(
                        baseline: viewModel.trainingBaseline,
                        onGenerate: {
                            Task { await viewModel.generatePlan() }
                        },
                        isGenerating: viewModel.isGenerating
                    )
                }
            }
            .padding()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
}

// MARK: - Plan Header Card

struct PlanHeaderCard: View {
    let plan: WeeklyTrainingPlan
    let insights: AdaptiveInsights?
    let onRegenerate: () -> Void
    let isRegenerating: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            // Week Range & Focus
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.weekRangeString)
                        .font(AppTheme.Typography.headline)
                        .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary)

                    if let focus = plan.focusArea {
                        Text(focus)
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(AppTheme.Colors.accent.opacity(0.1))
                            .cornerRadius(4)
                    }
                }

                Spacer()

                Button(action: onRegenerate) {
                    if isRegenerating {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 16, weight: .medium))
                    }
                }
                .foregroundColor(AppTheme.Colors.accent)
                .disabled(isRegenerating)
            }

            Divider()

            // Weekly Stats
            HStack(spacing: AppTheme.Spacing.xl) {
                PlanStatItem(
                    title: "Planned",
                    value: String(format: "%.1f mi", plan.totalMileage),
                    icon: "target"
                )

                if let insights = insights {
                    PlanStatItem(
                        title: "Completed",
                        value: "\(insights.adherencePercentage)%",
                        icon: "checkmark.circle",
                        valueColor: insights.adherenceRate >= 0.8 ? .green : .orange
                    )
                }

                PlanStatItem(
                    title: "Workouts",
                    value: "\(plan.workouts.filter { $0.workoutType != .rest }.count)",
                    icon: "figure.run"
                )
            }
        }
        .padding()
        .background(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.cardBackground : AppTheme.Colors.LightMode.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.large)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}

struct PlanStatItem: View {
    let title: String
    let value: String
    let icon: String
    var valueColor: Color = ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(AppTheme.Colors.accent)

            Text(value)
                .font(AppTheme.Typography.headline)
                .foregroundColor(valueColor)

            Text(title)
                .font(AppTheme.Typography.caption)
                .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Today's Workout Card

struct TodayWorkoutCard: View {
    let workout: DailyWorkout
    let actualActivity: Activity?
    let onTap: () -> Void

    var isCompleted: Bool {
        actualActivity != nil
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                HStack {
                    Label("Today", systemImage: "calendar")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)

                    Spacer()

                    if isCompleted {
                        Label("Completed", systemImage: "checkmark.circle.fill")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(.green)
                    }
                }

                HStack(spacing: AppTheme.Spacing.md) {
                    // Workout Type Icon
                    Image(systemName: workout.workoutType.icon)
                        .font(.system(size: 28))
                        .foregroundColor(workout.workoutType.color)
                        .frame(width: 50, height: 50)
                        .background(workout.workoutType.color.opacity(0.1))
                        .cornerRadius(12)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(workout.title)
                            .font(AppTheme.Typography.headline)
                            .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary)

                        HStack(spacing: AppTheme.Spacing.sm) {
                            if let distance = workout.formattedDistance {
                                Text(distance)
                                    .font(AppTheme.Typography.body)
                                    .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
                            }

                            if let pace = workout.targetPace {
                                Text("@ \(pace)")
                                    .font(AppTheme.Typography.body)
                                    .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textTertiary : AppTheme.Colors.LightMode.textTertiary)
                }
            }
            .padding()
            .background(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.cardBackground : AppTheme.Colors.LightMode.cardBackground)
            .cornerRadius(AppTheme.CornerRadius.large)
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
            .contentShape(Rectangle()) // Make entire card tappable
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Week Overview Section

struct WeekOverviewSection: View {
    let plan: WeeklyTrainingPlan
    let activities: [Activity]
    let onWorkoutTap: (DailyWorkout) -> Void

    var weekEntries: [WeekDayEntry] {
        plan.mergedWithActivities(activities)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("This Week")
                .font(AppTheme.Typography.headline)
                .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary)

            VStack(spacing: AppTheme.Spacing.sm) {
                ForEach(weekEntries) { entry in
                    PlanWeekDayRow(
                        entry: entry,
                        onTap: {
                            if let workout = entry.plannedWorkout {
                                onWorkoutTap(workout)
                            }
                        }
                    )
                }
            }
        }
        .padding()
        .background(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.cardBackground : AppTheme.Colors.LightMode.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.large)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}

struct PlanWeekDayRow: View {
    let entry: WeekDayEntry
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppTheme.Spacing.md) {
                // Day Label
                Text(entry.dayOfWeek.shortName)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(entry.isToday ? AppTheme.Colors.accent : ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
                    .frame(width: 35, alignment: .leading)

                // Icon
                Image(systemName: entry.icon)
                    .font(.system(size: 16))
                    .foregroundColor(entry.iconColor)
                    .frame(width: 24)

                // Workout Title
                Text(entry.displayTitle)
                    .font(AppTheme.Typography.body)
                    .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary)
                    .lineLimit(1)

                Spacer()

                // Distance or Status
                if let distance = entry.formattedDistance {
                    Text(distance)
                        .font(AppTheme.Typography.body)
                        .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
                } else if let status = entry.statusText {
                    Text(status)
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(entry.isCompleted ? .green : .orange)
                }
            }
            .padding(.vertical, AppTheme.Spacing.sm)
            .padding(.horizontal, AppTheme.Spacing.sm)
            .background(entry.isToday ? AppTheme.Colors.accent.opacity(0.05) : Color.clear)
            .cornerRadius(8)
            .contentShape(Rectangle()) // Make entire row tappable
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(entry.plannedWorkout == nil)
    }
}

// MARK: - Adaptive Insights Card

struct AdaptiveInsightsCard: View {
    let insights: AdaptiveInsights

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack {
                Image(systemName: "brain")
                    .foregroundColor(AppTheme.Colors.accent)
                Text("Adaptive Insights")
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary)
            }

            if insights.hasWarnings {
                ForEach(insights.spikeWarnings, id: \.self) { warning in
                    HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 14))
                        Text(warning)
                            .font(AppTheme.Typography.body)
                            .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary)
                    }
                    .padding(AppTheme.Spacing.sm)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            }

            ForEach(insights.recommendations.prefix(3), id: \.self) { recommendation in
                HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 14))
                    Text(recommendation)
                        .font(AppTheme.Typography.body)
                        .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
                }
            }
        }
        .padding()
        .background(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.cardBackground : AppTheme.Colors.LightMode.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.large)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}

// MARK: - Baseline Transparency Card

struct BaselineTransparencyCard: View {
    let baseline: TrainingBaseline
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(AppTheme.Colors.accent)
                    Text("Your Training Baseline")
                        .font(AppTheme.Typography.headline)
                        .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
                }
                .contentShape(Rectangle()) // Make entire row tappable
            }
            .buttonStyle(PlainButtonStyle())

            // Always show key stats
            HStack(spacing: AppTheme.Spacing.lg) {
                BaselineStatPill(
                    label: "Prior 4 Weeks",
                    value: String(format: "%.1f mi/wk", baseline.averageWeeklyMileage),
                    icon: "calendar"
                )

                BaselineStatPill(
                    label: "Runs/Week",
                    value: "\(baseline.runsPerWeek)",
                    icon: "figure.run"
                )

                BaselineStatPill(
                    label: "Easy Pace",
                    value: formatPace(baseline.averageEasyPace),
                    icon: "speedometer"
                )
            }

            if isExpanded {
                Divider()

                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text("How the algorithm uses this:")
                        .font(AppTheme.Typography.subheadline)
                        .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary)

                    BaselineExplanationRow(
                        text: "Your prior 4-week average (\(String(format: "%.1f", baseline.averageWeeklyMileage)) mi) sets your training baseline (current week excluded)"
                    )

                    BaselineExplanationRow(
                        text: "Long runs are capped at 30% of weekly mileage (min 5 mi)"
                    )

                    BaselineExplanationRow(
                        text: "Build weeks add 20% if under 30 mpw, 10% if above"
                    )

                    if baseline.longestRecentRun > 0 {
                        BaselineExplanationRow(
                            text: "Your longest recent run: \(String(format: "%.1f", baseline.longestRecentRun)) mi"
                        )
                    }

                    // Weekly breakdown
                    if !baseline.weeklyMileages.isEmpty {
                        Text("Prior 4 weeks (most recent first):")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
                            .padding(.top, AppTheme.Spacing.xs)

                        HStack(spacing: AppTheme.Spacing.sm) {
                            ForEach(Array(baseline.weeklyMileages.enumerated().reversed()), id: \.offset) { index, mileage in
                                VStack(spacing: 2) {
                                    Text(String(format: "%.1f", mileage))
                                        .font(AppTheme.Typography.caption)
                                        .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary)
                                    Text("W\(4 - index)")
                                        .font(.system(size: 10))
                                        .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textTertiary : AppTheme.Colors.LightMode.textTertiary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.cardBackground : AppTheme.Colors.LightMode.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.large)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private func formatPace(_ pace: Double) -> String {
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct BaselineStatPill: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Colors.accent)

            Text(value)
                .font(AppTheme.Typography.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary)

            Text(label)
                .font(.system(size: 10))
                .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct BaselineExplanationRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            Image(systemName: "info.circle")
                .font(.system(size: 12))
                .foregroundColor(AppTheme.Colors.accent)
            Text(text)
                .font(AppTheme.Typography.caption)
                .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
        }
    }
}

// MARK: - Training Principles Card

struct TrainingPrinciplesCard: View {
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "book.fill")
                        .foregroundColor(AppTheme.Colors.accent)
                    Text("Training Science")
                        .font(AppTheme.Typography.headline)
                        .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
                }
                .contentShape(Rectangle()) // Make entire row tappable
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    PrincipleRow(
                        icon: "heart.fill",
                        title: "Lactate Threshold",
                        description: "Correlates 0.91 with marathon time - more predictive than VO2 max (0.63)"
                    )

                    PrincipleRow(
                        icon: "exclamationmark.shield.fill",
                        title: "Injury Prevention",
                        description: "Single-session spikes are the key predictor. 30%+ increase = 64% higher risk."
                    )

                    PrincipleRow(
                        icon: "arrow.up.right",
                        title: "Progressive Overload",
                        description: "20-25% weekly increases below 30mpw, 10-15% above. Step-back every 3-4 weeks."
                    )

                    PrincipleRow(
                        icon: "clock.fill",
                        title: "Long Run Limits",
                        description: "20-30% of weekly mileage, max 2.5-3 hours. Beyond this, recovery costs outweigh benefits."
                    )
                }
            }
        }
        .padding()
        .background(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.cardBackground : AppTheme.Colors.LightMode.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.large)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}

struct PrincipleRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(AppTheme.Colors.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTheme.Typography.subheadline)
                    .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary)
                Text(description)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
            }
        }
    }
}

// MARK: - No Plan View

struct NoPlanView: View {
    let baseline: TrainingBaseline?
    let onGenerate: () -> Void
    let isGenerating: Bool

    var body: some View {
        VStack(spacing: AppTheme.Spacing.xl) {
            Spacer()

            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 80))
                .foregroundColor(AppTheme.Colors.accent)

            VStack(spacing: AppTheme.Spacing.sm) {
                Text("No Training Plan")
                    .font(AppTheme.Typography.title)
                    .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary)

                Text("Generate an adaptive plan based on your recent training and goals. The algorithm adjusts to your fitness level.")
                    .font(AppTheme.Typography.body)
                    .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Show detected baseline before generating
            if let baseline = baseline {
                VStack(spacing: AppTheme.Spacing.sm) {
                    Text("Based on your last 4 completed weeks:")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)

                    HStack(spacing: AppTheme.Spacing.xl) {
                        VStack(spacing: 2) {
                            Text(String(format: "%.1f", baseline.averageWeeklyMileage))
                                .font(AppTheme.Typography.headline)
                                .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary)
                            Text("mi/week avg")
                                .font(.system(size: 10))
                                .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
                        }

                        VStack(spacing: 2) {
                            Text("\(baseline.runsPerWeek)")
                                .font(AppTheme.Typography.headline)
                                .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary)
                            Text("runs/week")
                                .font(.system(size: 10))
                                .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
                        }

                        if baseline.longestRecentRun > 0 {
                            VStack(spacing: 2) {
                                Text(String(format: "%.1f", baseline.longestRecentRun))
                                    .font(AppTheme.Typography.headline)
                                    .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary)
                                Text("mi longest")
                                    .font(.system(size: 10))
                                    .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
                            }
                        }
                    }
                }
                .padding()
                .background(AppTheme.Colors.accent.opacity(0.05))
                .cornerRadius(AppTheme.CornerRadius.medium)
            }

            Button(action: onGenerate) {
                HStack {
                    if isGenerating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(isGenerating ? "Generating..." : "Generate Plan")
                }
                .font(AppTheme.Typography.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppTheme.Colors.accent)
                .cornerRadius(AppTheme.CornerRadius.medium)
            }
            .disabled(isGenerating)

            Spacer()
        }
        .padding(AppTheme.Spacing.xl)
    }
}

// MARK: - Loading Plan View

struct LoadingPlanView: View {
    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.accent))

            Text("Loading your plan...")
                .font(AppTheme.Typography.body)
                .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppTheme.Spacing.xxl)
    }
}

// MARK: - Workout Detail Sheet

struct PlanWorkoutDetailSheet: View {
    let workout: DailyWorkout
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    // Header
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        HStack {
                            Image(systemName: workout.workoutType.icon)
                                .font(.system(size: 40))
                                .foregroundColor(workout.workoutType.color)

                            VStack(alignment: .leading) {
                                Text(workout.title)
                                    .font(AppTheme.Typography.title)
                                    .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary)

                                Text(workout.dayOfWeek.fullName)
                                    .font(AppTheme.Typography.body)
                                    .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
                            }
                        }
                    }

                    Divider()

                    // Workout Details
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                        if let distance = workout.formattedDistance {
                            DetailRow(label: "Distance", value: distance)
                        }

                        if let duration = workout.formattedDuration {
                            DetailRow(label: "Duration", value: duration)
                        }

                        if let pace = workout.targetPace {
                            DetailRow(label: "Target Pace", value: pace)
                        }
                    }

                    Divider()

                    // Description
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        Text("Notes")
                            .font(AppTheme.Typography.headline)
                            .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary)

                        Text(workout.description)
                            .font(AppTheme.Typography.body)
                            .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Workout Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(AppTheme.Typography.body)
                .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
            Spacer()
            Text(value)
                .font(AppTheme.Typography.headline)
                .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary)
        }
    }
}

// MARK: - Training Guidelines Sheet

struct TrainingGuidelinesSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                    // Header
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        Text("Evidence-Based Training")
                            .font(AppTheme.Typography.title)
                            .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary)

                        Text("Guidelines backed by exercise physiology research")
                            .font(AppTheme.Typography.body)
                            .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
                    }

                    // Marathon Mileage Guidelines
                    GuidelinesSection(
                        title: "Marathon Training Mileage",
                        icon: "figure.run"
                    ) {
                        MileageTable()
                    }

                    // Long Run Guidelines
                    GuidelinesSection(
                        title: "Long Run Constraints",
                        icon: "clock"
                    ) {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                            GuidelineRow(label: "% of weekly mileage", value: "20-30%")
                            GuidelineRow(label: "Maximum duration", value: "2.5-3 hours")
                            GuidelineRow(label: "At 10:00/mi pace", value: "~18 miles max")
                            GuidelineRow(label: "At 8:00/mi pace", value: "~22 miles max")

                            Text("Beyond 3 hours, recovery costs outweigh aerobic benefits and injury risk increases significantly.")
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
                                .padding(.top, AppTheme.Spacing.xs)
                        }
                    }

                    // Progression Guidelines
                    GuidelinesSection(
                        title: "Weekly Progression",
                        icon: "arrow.up.right"
                    ) {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                            GuidelineRow(label: "Under 30 mi/week", value: "+20-25%")
                            GuidelineRow(label: "Over 30 mi/week", value: "+10-15%")
                            GuidelineRow(label: "Step-back frequency", value: "Every 3-4 weeks")
                            GuidelineRow(label: "Step-back reduction", value: "-20-40%")

                            Text("Research shows single-session spikes (>30% above baseline) are the primary injury predictor, not weekly increases.")
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
                                .padding(.top, AppTheme.Spacing.xs)
                        }
                    }

                    // What Matters Most
                    GuidelinesSection(
                        title: "What Matters Most",
                        icon: "star.fill"
                    ) {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                            KeyInsightRow(
                                title: "Lactate Threshold",
                                subtitle: "0.91 correlation with marathon time",
                                detail: "More predictive than VO2max (0.63). Focus on tempo runs at marathon to half-marathon pace."
                            )

                            KeyInsightRow(
                                title: "Consistency",
                                subtitle: "Beats sporadic high volume",
                                detail: "Regular training with gradual progression produces better results than inconsistent hard efforts."
                            )

                            KeyInsightRow(
                                title: "Easy Days",
                                subtitle: "When adaptation happens",
                                detail: "Don't skip easy days. Your body builds fitness during recovery, not during the workout."
                            )
                        }
                    }

                    // Tempo Pacing
                    GuidelinesSection(
                        title: "Tempo Run Pacing",
                        icon: "speedometer"
                    ) {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                            GuidelineRow(label: "Relative to 5K pace", value: "25-30 sec/mi slower")
                            GuidelineRow(label: "Effort level", value: "Comfortably hard")
                            GuidelineRow(label: "Talk test", value: "3-4 word phrases")

                            Text("Should feel sustainable but challenging. If you can have a full conversation, you're going too easy. If you can only grunt, too hard.")
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
                                .padding(.top, AppTheme.Spacing.xs)
                        }
                    }
                }
                .padding()
            }
            .background(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.background : AppTheme.Colors.LightMode.background)
            .navigationTitle("Training Guidelines")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Guidelines Components

struct GuidelinesSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: icon)
                    .foregroundColor(AppTheme.Colors.accent)
                    .font(.system(size: 18))
                Text(title)
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary)
            }

            content
        }
        .padding()
        .background(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.cardBackground : AppTheme.Colors.LightMode.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.large)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}

struct MileageTable: View {
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Level")
                    .font(AppTheme.Typography.caption)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Weekly")
                    .font(AppTheme.Typography.caption)
                    .fontWeight(.semibold)
                    .frame(width: 80, alignment: .trailing)
                Text("Long Run")
                    .font(AppTheme.Typography.caption)
                    .fontWeight(.semibold)
                    .frame(width: 80, alignment: .trailing)
            }
            .padding(.vertical, AppTheme.Spacing.sm)
            .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)

            Divider()

            MileageTableRow(level: "Beginner", weekly: "25-35 mi", longRun: "16-20 mi")
            MileageTableRow(level: "Intermediate", weekly: "35-50 mi", longRun: "18-22 mi")
            MileageTableRow(level: "Competitive", weekly: "50-70 mi", longRun: "20-23 mi")
            MileageTableRow(level: "Elite", weekly: "70-120+ mi", longRun: "22-26 mi")
        }
    }
}

struct MileageTableRow: View {
    let level: String
    let weekly: String
    let longRun: String

    var body: some View {
        HStack {
            Text(level)
                .font(AppTheme.Typography.body)
                .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(weekly)
                .font(AppTheme.Typography.body)
                .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
                .frame(width: 80, alignment: .trailing)
            Text(longRun)
                .font(AppTheme.Typography.body)
                .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.vertical, AppTheme.Spacing.sm)
    }
}

struct GuidelineRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(AppTheme.Typography.body)
                .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
            Spacer()
            Text(value)
                .font(AppTheme.Typography.body)
                .fontWeight(.medium)
                .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary)
        }
    }
}

struct KeyInsightRow: View {
    let title: String
    let subtitle: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(AppTheme.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary)
                Spacer()
                Text(subtitle)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.accent)
            }
            Text(detail)
                .font(AppTheme.Typography.caption)
                .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
        }
        .padding(AppTheme.Spacing.sm)
        .background(AppTheme.Colors.accent.opacity(0.05))
        .cornerRadius(AppTheme.CornerRadius.small)
    }
}

// MARK: - Preview

struct PlanView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PlanView()
                .environmentObject(DataManager.shared)
        }
    }
}
