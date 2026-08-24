//
//  RunRecordingView.swift
//  Runaway iOS
//
//  Minimal in-app "Start Run" UI. Exercises the full pipeline:
//  RunRecorder → HealthKitWorkoutService → RunCoachScheduler → AudioCueService.
//

import SwiftUI

struct RunRecordingView: View {
    @StateObject private var recorder = RunRecorder()
    @ObservedObject private var coachSettings = CoachSettingsStore.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var runnerIconSize = 72.0
    @ScaledMetric(relativeTo: .largeTitle) private var statValueSize = 48.0

    @State private var showingCancelAlert = false
    @State private var showingFinishAlert = false
    @State private var identityCues: [String] = []

    private var background: Color {
        AppTheme.Colors.adaptiveBackground
    }

    private var textPrimary: Color {
        AppTheme.Colors.adaptiveTextPrimary
    }

    private var textSecondary: Color {
        AppTheme.Colors.adaptiveTextSecondary
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            if recorder.isRecording {
                activeRunView
            } else {
                startScreen
            }
        }
        .navigationTitle("Record Run")
        .navigationBarTitleDisplayMode(.inline)
        .transaction { transaction in
            if accessibilityReduceMotion {
                transaction.animation = nil
            }
        }
        .alert("Discard this run?", isPresented: $showingCancelAlert) {
            Button("Keep recording", role: .cancel) {}
            Button("Discard", role: .destructive) {
                recorder.cancel()
                dismiss()
            }
        } message: {
            Text("Your progress will be lost.")
        }
        .alert("Finish this run?", isPresented: $showingFinishAlert) {
            Button("Keep recording", role: .cancel) {}
            Button("Finish Run") {
                Task {
                    await recorder.stop()
                    dismiss()
                }
            }
        } message: {
            Text("Runaway will save the workout recorded so far.")
        }
        .task {
            guard let athleteId = DataManager.shared.athlete?.id else { return }
            let settings = CoachSettingsStore.shared.settings
            guard settings.isEnabled, settings.enableIdentityVoiceCues else { return }
            async let profileFetch = RunnerMindsetService.fetchProfile(athleteId: athleteId)
            async let milestonesFetch = RunnerMindsetService.fetchMilestones(athleteId: athleteId)
            let profile = try? await profileFetch
            let milestones = (try? await milestonesFetch) ?? []
            if let profile {
                identityCues = (try? await RunCueService.fetchCues(
                    athleteId: athleteId,
                    profile: profile,
                    milestones: milestones
                )) ?? []
            }
        }
    }

    // MARK: - Start Screen

    private var startScreen: some View {
        VStack(spacing: AppTheme.Spacing.xl) {
            Spacer()

            Image(systemName: "figure.run")
                .font(.system(size: runnerIconSize))
                .foregroundColor(AppTheme.Colors.accent)
                .accessibilityHidden(true)

            VStack(spacing: AppTheme.Spacing.sm) {
                Text("Ready to run")
                    .font(AppTheme.Typography.title)
                    .foregroundColor(textPrimary)

                if coachSettings.settings.isEnabled {
                    let unitWord = coachSettings.settings.distanceUnit == .miles ? "mile" : "kilometer"
                    Text("Audio coaching is on. Splits will be announced at each \(unitWord).")
                        .font(AppTheme.Typography.body)
                        .foregroundColor(textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppTheme.Spacing.xl)
                }
            }

            if let error = recorder.errorMessage {
                Text(error)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.error)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.Spacing.xl)
                    .accessibilityLabel("Run recording error: \(error)")
            }

            Spacer()

            Button {
                Task {
                    await recorder.start()
                    RunCoachScheduler.shared.loadIdentityCues(identityCues)
                }
            } label: {
                Text("Start Run")
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 64)
                    .background(AppTheme.Colors.accent)
                    .cornerRadius(AppTheme.CornerRadius.large)
            }
            .padding(.horizontal, AppTheme.Spacing.xl)
            .padding(.bottom, AppTheme.Spacing.xl)
            .accessibilityLabel("Start run")
            .accessibilityHint("Begins workout and location recording")
        }
    }

    // MARK: - Active Run

    private var activeRunView: some View {
        VStack(spacing: AppTheme.Spacing.xl) {
            Spacer()

            VStack(spacing: AppTheme.Spacing.lg) {
                statCard(label: "Distance", value: formatDistance(recorder.distanceMeters))
                statCard(label: "Time", value: formatDuration(recorder.elapsedSeconds))
                statCard(label: "Pace", value: formatPace(recorder.currentPaceSecondsPerMeter))
            }

            Spacer()

            HStack(spacing: AppTheme.Spacing.md) {
                Button {
                    showingCancelAlert = true
                } label: {
                    Text("Cancel")
                        .font(AppTheme.Typography.headline)
                        .foregroundColor(AppTheme.Colors.error)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 64)
                        .background(AppTheme.Colors.error.opacity(0.1))
                        .cornerRadius(AppTheme.CornerRadius.large)
                }
                .accessibilityLabel("Cancel run")
                .accessibilityHint("Asks before discarding this workout")

                Button {
                    showingFinishAlert = true
                } label: {
                    Text("Finish")
                        .font(AppTheme.Typography.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 64)
                        .background(AppTheme.Colors.accent)
                        .cornerRadius(AppTheme.CornerRadius.large)
                }
                .accessibilityLabel("Finish run")
                .accessibilityHint("Asks before saving and ending this workout")
            }
            .padding(.horizontal, AppTheme.Spacing.xl)
            .padding(.bottom, AppTheme.Spacing.xl)
        }
    }

    // MARK: - Components

    private func statCard(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label.uppercased())
                .font(AppTheme.Typography.caption)
                .foregroundColor(textSecondary)
                .tracking(1)

            Text(value)
                .font(.system(size: statValueSize, weight: .bold, design: .rounded))
                .foregroundColor(textPrimary)
                .monospacedDigit()
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }

    // MARK: - Formatters

    private func formatDistance(_ meters: Double) -> String {
        let unit = coachSettings.settings.distanceUnit
        let value = meters / unit.metersPerUnit
        return String(format: "%.2f %@", value, unit.abbreviation)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    private func formatPace(_ secondsPerMeter: Double) -> String {
        guard secondsPerMeter > 0 else { return "--:--" }
        let unit = coachSettings.settings.distanceUnit
        let secondsPerUnit = secondsPerMeter * unit.metersPerUnit
        let minutes = Int(secondsPerUnit) / 60
        let secs = Int(secondsPerUnit) % 60
        return String(format: "%d:%02d /%@", minutes, secs, unit.abbreviation)
    }
}

struct RunRecordingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            RunRecordingView()
                .environmentObject(ThemeManager.shared)
        }
    }
}
