//
//  ActivityCommitmentCard.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 9/16/25.
//

import SwiftUI

// MARK: - Activity Commitment Card

struct ActivityCommitmentCard: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedActivityType: CommitmentActivityType = .run
    @State private var showingCommitmentPicker = false
    @State private var errorMessage: String?
    @State private var showingSuccess = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            // Header with days counter
            HStack {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    Text("Activity Tracker")
                        .font(AppTheme.Typography.headline)
                        .foregroundColor(AppTheme.Colors.textPrimary)

                    Text(dataManager.daysSinceLastActivityText)
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }

                Spacer()

                // Activity streak icon
                if dataManager.daysSinceLastActivity == 0 {
                    Image(systemName: "flame.fill")
                        .foregroundColor(AppTheme.Colors.warning)
                        .font(AppTheme.Typography.title2)
                } else if dataManager.daysSinceLastActivity > 0 {
                    Image(systemName: "clock.fill")
                        .foregroundColor(AppTheme.Colors.warning)
                        .font(AppTheme.Typography.title2)
                }
            }

            Divider()
                .background(AppTheme.Colors.textTertiary.opacity(0.3))

            // Commitment section
            if let commitment = dataManager.todaysCommitment {
                if commitment.isFulfilled {
                    // Fulfilled commitment
                    FulfilledCommitmentView(commitment: commitment)
                } else {
                    // Active commitment with countdown
                    ActiveCommitmentView(commitment: commitment)
                        .environmentObject(dataManager)
                }
            } else {
                // No commitment - show commitment picker
                NoCommitmentView(
                    selectedActivityType: $selectedActivityType,
                    showingCommitmentPicker: $showingCommitmentPicker,
                    onCommitmentCreated: createCommitment
                )
            }

            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.error)
                    .padding(.horizontal, AppTheme.Spacing.sm)
                    .padding(.vertical, AppTheme.Spacing.xs)
                    .background(AppTheme.Colors.error.opacity(0.1))
                    .cornerRadius(AppTheme.CornerRadius.small)
            }

            // Success message
            if showingSuccess {
                HStack(spacing: AppTheme.Spacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppTheme.Colors.success)
                    Text("Commitment created!")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.success)
                }
                .padding(.horizontal, AppTheme.Spacing.sm)
                .padding(.vertical, AppTheme.Spacing.xs)
                .background(AppTheme.Colors.success.opacity(AppTheme.Opacity.light))
                .cornerRadius(AppTheme.CornerRadius.small)
            }

        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.medium)
        .shadow(
            color: AppTheme.Shadows.light.color,
            radius: AppTheme.Shadows.light.radius,
            x: AppTheme.Shadows.light.x,
            y: AppTheme.Shadows.light.y
        )
    }

    private func createCommitment() {
        Task {
            do {
                errorMessage = nil
                try await dataManager.createCommitment(selectedActivityType)

                await MainActor.run {
                    showingSuccess = true
                    showingCommitmentPicker = false
                }

                // Hide success message after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showingSuccess = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to create commitment: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - No Commitment View

struct NoCommitmentView: View {
    @Binding var selectedActivityType: CommitmentActivityType
    @Binding var showingCommitmentPicker: Bool
    let onCommitmentCreated: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Today's Commitment")
                .font(AppTheme.Typography.headline)
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.Colors.textPrimary)

            HStack {
                Text("I commit to:")
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textSecondary)

                Spacer()

                Picker("Activity Type", selection: $selectedActivityType) {
                    ForEach(CommitmentActivityType.allCases, id: \.self) { activityType in
                        HStack {
                            Image(systemName: activityType.icon)
                            Text(activityType.displayName)
                        }
                        .tag(activityType)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .accentColor(AppTheme.Colors.accent)
            }

            Button(action: onCommitmentCreated) {
                HStack {
                    Spacer()
                    Text("Set Commitment")
                        .font(AppTheme.Typography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                    Spacer()
                }
                .padding(.vertical, AppTheme.Spacing.sm)
                .background(AppTheme.Colors.accent)
                .cornerRadius(AppTheme.CornerRadius.small)
            }
        }
    }
}

// MARK: - Active Commitment View

struct ActiveCommitmentView: View {
    let commitment: DailyCommitment
    @EnvironmentObject var dataManager: DataManager
    @State private var currentTime = Date()
    @State private var showingEditOptions = false
    @State private var selectedActivityType: CommitmentActivityType
    @State private var showingDeleteConfirmation = false
    @State private var errorMessage: String?

    init(commitment: DailyCommitment) {
        self.commitment = commitment
        self._selectedActivityType = State(initialValue: commitment.activityType)
    }

    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                Text("Today's Commitment")
                    .font(AppTheme.Typography.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Spacer()

                Text("Active")
                    .font(AppTheme.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                    .padding(.horizontal, AppTheme.Spacing.sm)
                    .padding(.vertical, 2)
                    .background(AppTheme.Colors.warning)
                    .cornerRadius(AppTheme.CornerRadius.small)
            }

            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: commitment.activityType.icon)
                    .foregroundColor(AppTheme.Colors.accent)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(commitment.activityType.displayName)
                        .font(AppTheme.Typography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.Colors.textPrimary)

                    if commitment.timeRemainingToday > 0 {
                        Text(commitment.timeRemainingText)
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    } else {
                        Text("Commitment expired")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.error)
                    }
                }

                Spacer()

                // Progress ring
                CommitmentProgressRing(timeRemaining: commitment.timeRemainingToday)
            }

            // Edit options
            if showingEditOptions {
                VStack(spacing: AppTheme.Spacing.sm) {
                    Divider()
                        .background(AppTheme.Colors.textTertiary.opacity(0.3))

                    Text("Change commitment to:")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)

                    Picker("Activity Type", selection: $selectedActivityType) {
                        ForEach(CommitmentActivityType.allCases, id: \.self) { activityType in
                            HStack {
                                Image(systemName: activityType.icon)
                                Text(activityType.displayName)
                            }
                            .tag(activityType)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .accentColor(AppTheme.Colors.accent)

                    HStack(spacing: AppTheme.Spacing.sm) {
                        Button(action: {
                            showingEditOptions = false
                        }) {
                            Text("Cancel")
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppTheme.Spacing.xs)
                                .background(AppTheme.Colors.textTertiary.opacity(0.2))
                                .cornerRadius(AppTheme.CornerRadius.small)
                        }

                        Button(action: updateCommitment) {
                            Text("Update")
                                .font(AppTheme.Typography.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppTheme.Spacing.xs)
                                .background(AppTheme.Colors.accent)
                                .cornerRadius(AppTheme.CornerRadius.small)
                        }
                    }
                }
            }

            // Action buttons
            if !showingEditOptions {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Button(action: {
                        showingEditOptions = true
                    }) {
                        HStack {
                            Image(systemName: "pencil")
                            Text("Change")
                        }
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.Spacing.xs)
                        .background(AppTheme.Colors.accent.opacity(0.1))
                        .cornerRadius(AppTheme.CornerRadius.small)
                    }

                    Button(action: {
                        showingDeleteConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Remove")
                        }
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.error)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.Spacing.xs)
                        .background(AppTheme.Colors.error.opacity(0.1))
                        .cornerRadius(AppTheme.CornerRadius.small)
                    }
                }
            }

            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.error)
                    .padding(.horizontal, AppTheme.Spacing.sm)
                    .padding(.vertical, AppTheme.Spacing.xs)
                    .background(AppTheme.Colors.error.opacity(0.1))
                    .cornerRadius(AppTheme.CornerRadius.small)
            }
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
        .alert("Remove Commitment", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                deleteCommitment()
            }
        } message: {
            Text("Are you sure you want to remove today's commitment? You can set a new one afterwards.")
        }
    }

    private func updateCommitment() {
        guard let commitmentId = commitment.id else { return }
        
        Task {
            do {
                errorMessage = nil
                try await dataManager.updateCommitmentActivityType(commitmentId, newActivityType: selectedActivityType)
                showingEditOptions = false
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to update commitment: \(error.localizedDescription)"
                }
            }
        }
    }

    private func deleteCommitment() {
        guard let commitmentId = commitment.id else { return }
        
        Task {
            do {
                errorMessage = nil
                try await dataManager.deleteCommitment(commitmentId)
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to delete commitment: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Fulfilled Commitment View

struct FulfilledCommitmentView: View {
    let commitment: DailyCommitment

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            // Celebration header
            HStack {
                Text("Commitment Completed")
                    .font(AppTheme.Typography.headline)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.Colors.success)

                Spacer()

                Image(systemName: "party.popper.fill")
                    .foregroundColor(AppTheme.Colors.warning)
                    .font(AppTheme.Typography.title2)
            }

            // Main celebration message
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text("LET'S FUCKING GO! 🔥")
                    .font(.title2)
                    .fontWeight(.heavy)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Text("You crushed your \(commitment.activityType.displayName.lowercased()) commitment today!")
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }

            // Activity details
            HStack(spacing: AppTheme.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(AppTheme.Colors.success.opacity(AppTheme.Opacity.medium))
                        .frame(width: 50, height: 50)

                    Image(systemName: commitment.activityType.icon)
                        .foregroundColor(AppTheme.Colors.success)
                        .font(AppTheme.Typography.title2)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(commitment.activityType.displayName)
                        .font(AppTheme.Typography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.Colors.textPrimary)

                    if let fulfilledTime = commitment.fulfilledAtAsDate {
                        Text("Completed at \(fulfilledTime, formatter: timeFormatter)")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    } else {
                        Text("Completed today")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }

                Spacer()

                // Big checkmark with animation effect
                ZStack {
                    Circle()
                        .fill(AppTheme.Colors.success)
                        .frame(width: 40, height: 40)

                    Image(systemName: "checkmark")
                        .foregroundColor(.black)
                        .font(AppTheme.Typography.title3)
                        .fontWeight(.bold)
                }
            }

            // Motivational footer
            HStack {
                Spacer()
                Text("Keep the momentum going! 💪")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.accent)
                    .italic()
                Spacer()
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(
            LinearGradient(
                colors: [AppTheme.Colors.success.opacity(AppTheme.Opacity.light), AppTheme.Colors.success.opacity(AppTheme.Opacity.veryLight)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                .stroke(AppTheme.Colors.success.opacity(AppTheme.Opacity.strong), lineWidth: 1)
        )
        .cornerRadius(AppTheme.CornerRadius.medium)
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
}

// MARK: - Commitment Progress Ring

struct CommitmentProgressRing: View {
    let timeRemaining: TimeInterval

    private var progress: Double {
        let totalSecondsInDay: TimeInterval = 24 * 60 * 60
        let elapsed = totalSecondsInDay - timeRemaining
        return min(max(elapsed / totalSecondsInDay, 0), 1)
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(AppTheme.Colors.textTertiary.opacity(AppTheme.Opacity.medium), lineWidth: 3)
                .frame(width: 32, height: 32)

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    timeRemaining > 0 ? AppTheme.Colors.warning : AppTheme.Colors.error,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 32, height: 32)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)

            // Center indicator
            Circle()
                .fill(timeRemaining > 0 ? AppTheme.Colors.warning : AppTheme.Colors.error)
                .frame(width: 8, height: 8)
        }
    }
}

// MARK: - Activity Type Picker Sheet

struct ActivityTypePickerSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var selectedType: CommitmentActivityType

    var body: some View {
        NavigationView {
            List {
                ForEach(CommitmentActivityType.allCases, id: \.self) { activityType in
                    Button(action: {
                        selectedType = activityType
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack(spacing: AppTheme.Spacing.md) {
                            Image(systemName: activityType.icon)
                                .foregroundColor(AppTheme.Colors.accent)
                                .font(AppTheme.Typography.title2)
                                .frame(width: 30)

                            Text(activityType.displayName)
                                .font(AppTheme.Typography.body)
                                .foregroundColor(AppTheme.Colors.textPrimary)

                            Spacer()

                            if selectedType == activityType {
                                Image(systemName: "checkmark")
                                    .foregroundColor(AppTheme.Colors.accent)
                            }
                        }
                        .padding(.vertical, AppTheme.Spacing.xs)
                    }
                }
            }
            .navigationTitle("Choose Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}
