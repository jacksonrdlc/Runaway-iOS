//
//  WeeklyTrainingPlanView.swift
//  Runaway iOS
//
//  Weekly training plan view showing Sun-Sat workouts
//

import SwiftUI

struct WeeklyTrainingPlanView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var weeklyPlan: WeeklyTrainingPlan?
    @State private var isLoading = false
    @State private var isGenerating = false
    @State private var selectedWorkout: DailyWorkout?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Week Header
                weekHeader

                if isLoading {
                    loadingView
                } else if let plan = weeklyPlan {
                    // Weekly Stats Summary
                    weekSummaryCard(plan: plan)

                    // Daily Workouts
                    ForEach(DayOfWeek.allCases, id: \.self) { day in
                        if let workout = plan.workout(for: day) {
                            WorkoutDayCard(workout: workout) {
                                selectedWorkout = workout
                            }
                        }
                    }
                } else {
                    // No plan - show generate button
                    noPlanView
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Training Plan")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selectedWorkout) { workout in
            WorkoutDetailSheet(workout: workout)
        }
        .task {
            await loadPlan()
        }
    }

    // MARK: - Subviews

    private var weekHeader: some View {
        VStack(spacing: 8) {
            if let plan = weeklyPlan {
                Text(plan.weekRangeString)
                    .font(.title2)
                    .fontWeight(.bold)

                if plan.isCurrentWeek {
                    Text("This Week")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                }
            } else {
                Text("This Week's Plan")
                    .font(.title2)
                    .fontWeight(.bold)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private func weekSummaryCard(plan: WeeklyTrainingPlan) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Week Overview")
                    .font(.headline)
                Spacer()
                if let focus = plan.focusArea {
                    Text(focus)
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
            }

            HStack(spacing: 20) {
                StatPill(title: "Total Miles", value: String(format: "%.1f", plan.totalMileage), icon: "figure.run")
                StatPill(title: "Workouts", value: "\(plan.workouts.count)", icon: "calendar")
                StatPill(title: "Run Days", value: "\(plan.workouts.filter { $0.workoutType.isRunning }.count)", icon: "shoe")
                StatPill(title: "Strength", value: "\(plan.workouts.filter { $0.workoutType.isStrength }.count)", icon: "dumbbell")
            }

            if let notes = plan.notes {
                Text(notes)
                    .font(.subheadline)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading plan...")
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(60)
    }

    private var noPlanView: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.blue.opacity(0.6))

            Text("No Training Plan Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Generate a personalized weekly plan based on your goals. Includes running, strength training, and active recovery.")
                .font(.subheadline)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: {
                Task { await generatePlan() }
            }) {
                HStack {
                    if isGenerating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(isGenerating ? "Generating..." : "Generate Plan")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            .disabled(isGenerating)
            .padding(.horizontal)
        }
        .padding(40)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    // MARK: - Actions

    private func loadPlan() async {
        guard let userId = UserSession.shared.userId else { return }

        isLoading = true
        errorMessage = nil

        do {
            let sunday = TrainingPlanService.currentWeekSunday()
            weeklyPlan = try await TrainingPlanService.getWeeklyPlan(athleteId: userId, weekStartDate: sunday)
        } catch {
            // No plan exists yet - that's okay
            #if DEBUG
            print("No existing plan: \(error)")
            #endif
        }

        isLoading = false
    }

    private func generatePlan() async {
        guard let userId = UserSession.shared.userId else { return }

        isGenerating = true
        errorMessage = nil

        do {
            weeklyPlan = try await TrainingPlanService.generateWeeklyPlan(
                athleteId: userId,
                goal: dataManager.currentGoal
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isGenerating = false
    }
}

// MARK: - Workout Day Card

struct WorkoutDayCard: View {
    let workout: DailyWorkout
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Day indicator
                VStack {
                    Text(workout.dayOfWeek.shortName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    Text(dayNumber)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(isToday ? .white : .primary)
                }
                .frame(width: 50, height: 50)
                .background(isToday ? Color.blue : Color(.systemGray6))
                .cornerRadius(12)

                // Workout info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: workout.workoutType.icon)
                            .foregroundColor(workout.workoutType.color)
                        Text(workout.title)
                            .font(.headline)
                            .foregroundColor(AppTheme.Colors.LightMode.textPrimary)
                    }

                    HStack(spacing: 12) {
                        if let distance = workout.formattedDistance {
                            Label(distance, systemImage: "ruler")
                                .font(.caption)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        if let duration = workout.formattedDuration {
                            Label(duration, systemImage: "clock")
                                .font(.caption)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        if let pace = workout.targetPace {
                            Label(pace, systemImage: "speedometer")
                                .font(.caption)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                }

                Spacer()

                // Completion indicator
                if workout.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(workout.date)
    }

    private var dayNumber: String {
        let day = Calendar.current.component(.day, from: workout.date)
        return "\(day)"
    }
}

// MARK: - Stat Pill

struct StatPill: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            Text(title)
                .font(.caption2)
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Workout Detail Sheet

struct WorkoutDetailSheet: View {
    let workout: DailyWorkout
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: workout.workoutType.icon)
                                .font(.title)
                                .foregroundColor(workout.workoutType.color)
                            Text(workout.workoutType.displayName)
                                .font(.caption)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(workout.workoutType.color.opacity(0.1))
                                .cornerRadius(8)
                        }

                        Text(workout.title)
                            .font(.title)
                            .fontWeight(.bold)

                        Text(workout.dayOfWeek.fullName + ", " + formattedDate)
                            .font(.subheadline)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }

                    // Workout Details
                    HStack(spacing: 20) {
                        if let distance = workout.distance {
                            DetailBox(title: "Distance", value: String(format: "%.1f mi", distance))
                        }
                        if let duration = workout.duration {
                            DetailBox(title: "Duration", value: "\(duration) min")
                        }
                        if let pace = workout.targetPace {
                            DetailBox(title: "Pace", value: pace)
                        }
                    }

                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                        Text(workout.description)
                            .font(.body)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }

                    // Exercises (for strength workouts)
                    if let exercises = workout.exercises, !exercises.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Exercises")
                                .font(.headline)

                            ForEach(exercises) { exercise in
                                ExerciseRow(exercise: exercise)
                            }
                        }
                    }

                    Spacer()
                }
                .padding()
            }
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

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: workout.date)
    }
}

// MARK: - Detail Box

struct DetailBox: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
            Text(title)
                .font(.caption)
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Exercise Row

struct ExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let notes = exercise.notes {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }

            Spacer()

            if let sets = exercise.sets, let reps = exercise.reps {
                Text("\(sets) x \(reps)")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            } else if let reps = exercise.reps {
                Text(reps)
                    .font(.subheadline)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    NavigationView {
        WeeklyTrainingPlanView()
            .environmentObject(DataManager.shared)
    }
}
