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
                        .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

                    Text(dataManager.daysSinceLastActivityText)
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
                }

                Spacer()

                // Activity streak icon
                if dataManager.daysSinceLastActivity == 0 {
                    Image(systemName: "flame.fill")
                        .foregroundColor(AppTheme.Colors.LightMode.accent)
                        .font(AppTheme.Typography.title2)
                } else if dataManager.daysSinceLastActivity > 0 {
                    Image(systemName: "clock.fill")
                        .foregroundColor(AppTheme.Colors.LightMode.accent)
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
        .background(Color.white)
        .cornerRadius(AppTheme.CornerRadius.medium)
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        .task {
            // Refresh commitment data on appear
            await dataManager.refreshTodaysCommitment()
        }
        .refreshable {
            await dataManager.refreshTodaysCommitment()
        }
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
                .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

            HStack {
                Text("I commit to:")
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.LightMode.textSecondary)

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
    @EnvironmentObject var dataManager: DataManager
    let initialCommitment: DailyCommitment
    @State private var currentTime = Date()
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var selectedActivityType: CommitmentActivityType
    @State private var errorMessage: String?
    @State private var isUpdating = false

    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    /// Use dataManager's commitment if available, fallback to initial
    private var commitment: DailyCommitment {
        dataManager.todaysCommitment ?? initialCommitment
    }

    init(commitment: DailyCommitment) {
        self.initialCommitment = commitment
        _selectedActivityType = State(initialValue: commitment.activityType)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                Text("Today's Commitment")
                    .font(AppTheme.Typography.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

                Spacer()

                Text("Active")
                    .font(AppTheme.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, AppTheme.Spacing.sm)
                    .padding(.vertical, 2)
                    .background(AppTheme.Colors.LightMode.accent)
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
                        .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

                    if commitment.timeRemainingToday > 0 {
                        Text(commitment.timeRemainingText)
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
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

            // Edit/Delete controls
            HStack(spacing: AppTheme.Spacing.sm) {
                Button(action: { showingEditSheet = true }) {
                    HStack(spacing: AppTheme.Spacing.xs) {
                        Image(systemName: "pencil")
                        Text("Edit")
                    }
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.accent)
                    .padding(.horizontal, AppTheme.Spacing.sm)
                    .padding(.vertical, AppTheme.Spacing.xs)
                    .background(AppTheme.Colors.accent.opacity(0.1))
                    .cornerRadius(AppTheme.CornerRadius.small)
                }
                .disabled(isUpdating)

                Button(action: { showingDeleteConfirmation = true }) {
                    HStack(spacing: AppTheme.Spacing.xs) {
                        Image(systemName: "trash")
                        Text("Remove")
                    }
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.error)
                    .padding(.horizontal, AppTheme.Spacing.sm)
                    .padding(.vertical, AppTheme.Spacing.xs)
                    .background(AppTheme.Colors.error.opacity(0.1))
                    .cornerRadius(AppTheme.CornerRadius.small)
                }
                .disabled(isUpdating)

                Spacer()

                if isUpdating {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.top, AppTheme.Spacing.xs)

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
        .sheet(isPresented: $showingEditSheet) {
            EditCommitmentSheet(
                selectedType: $selectedActivityType,
                currentType: commitment.activityType,
                onSave: updateCommitment
            )
        }
        .alert("Remove Commitment?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                deleteCommitment()
            }
        } message: {
            Text("Are you sure you want to remove today's commitment? You can set a new one afterward.")
        }
        .onChange(of: dataManager.todaysCommitment?.activityType) { _, newType in
            // Sync selectedActivityType when commitment changes externally
            if let newType = newType, newType != selectedActivityType {
                selectedActivityType = newType
            }
        }
    }

    private func updateCommitment() {
        guard selectedActivityType != commitment.activityType else {
            showingEditSheet = false
            return
        }

        Task {
            isUpdating = true
            errorMessage = nil
            defer { isUpdating = false }

            do {
                try await dataManager.updateCommitment(to: selectedActivityType)
                await MainActor.run {
                    showingEditSheet = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to update: \(error.localizedDescription)"
                    selectedActivityType = commitment.activityType
                }
            }
        }
    }

    private func deleteCommitment() {
        Task {
            isUpdating = true
            errorMessage = nil
            defer { isUpdating = false }

            do {
                try await dataManager.deleteCommitment()
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to remove: \(error.localizedDescription)"
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
                    .foregroundColor(AppTheme.Colors.LightMode.accent)
                    .font(AppTheme.Typography.title2)
            }

            // Main celebration message
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text("LET'S GO! 🔥")
                    .font(.title2)
                    .fontWeight(.heavy)
                    .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

                Text("You crushed your \(commitment.activityType.displayName.lowercased()) commitment today!")
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
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
                        .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

                    if let fulfilledTime = commitment.fulfilledAtAsDate {
                        Text("Completed at \(fulfilledTime, formatter: timeFormatter)")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
                    } else {
                        Text("Completed today")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
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
                    timeRemaining > 0 ? AppTheme.Colors.LightMode.accent : AppTheme.Colors.error,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 32, height: 32)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)

            // Center indicator
            Circle()
                .fill(timeRemaining > 0 ? AppTheme.Colors.LightMode.accent : AppTheme.Colors.error)
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
                                .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

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
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.LightMode.accent)
                }
            }
        }
    }
}

// MARK: - Edit Commitment Sheet

struct EditCommitmentSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedType: CommitmentActivityType
    let currentType: CommitmentActivityType
    let onSave: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: AppTheme.Spacing.lg) {
                Text("Change your commitment type")
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
                    .padding(.top, AppTheme.Spacing.md)

                VStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(CommitmentActivityType.allCases, id: \.self) { activityType in
                        Button(action: {
                            selectedType = activityType
                        }) {
                            HStack(spacing: AppTheme.Spacing.md) {
                                ZStack {
                                    Circle()
                                        .fill(selectedType == activityType ?
                                              AppTheme.Colors.accent.opacity(0.2) :
                                              AppTheme.Colors.textTertiary.opacity(0.1))
                                        .frame(width: 44, height: 44)

                                    Image(systemName: activityType.icon)
                                        .foregroundColor(selectedType == activityType ?
                                                        AppTheme.Colors.accent :
                                                        AppTheme.Colors.LightMode.textSecondary)
                                        .font(.title3)
                                }

                                Text(activityType.displayName)
                                    .font(AppTheme.Typography.body)
                                    .fontWeight(selectedType == activityType ? .semibold : .regular)
                                    .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

                                Spacer()

                                if selectedType == activityType {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(AppTheme.Colors.accent)
                                        .font(.title3)
                                } else {
                                    Circle()
                                        .stroke(AppTheme.Colors.textTertiary.opacity(0.3), lineWidth: 1.5)
                                        .frame(width: 22, height: 22)
                                }
                            }
                            .padding(AppTheme.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                                    .fill(selectedType == activityType ?
                                          AppTheme.Colors.accent.opacity(0.05) :
                                          Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                                    .stroke(selectedType == activityType ?
                                           AppTheme.Colors.accent.opacity(0.3) :
                                           AppTheme.Colors.textTertiary.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)

                Spacer()

                Button(action: onSave) {
                    HStack {
                        Spacer()
                        Text("Save Changes")
                            .font(AppTheme.Typography.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                        Spacer()
                    }
                    .padding(.vertical, AppTheme.Spacing.md)
                    .background(AppTheme.Colors.accent)
                    .cornerRadius(AppTheme.CornerRadius.medium)
                }
                .disabled(selectedType == currentType)
                .opacity(selectedType == currentType ? 0.5 : 1.0)
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.bottom, AppTheme.Spacing.lg)
            }
            .navigationTitle("Edit Commitment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        selectedType = currentType
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
                }
            }
        }
    }
}
