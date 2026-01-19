//
//  ActiveRecordingView.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 6/29/25.
//

import SwiftUI
import CoreLocation
import UIKit

struct ActiveRecordingView: View {
    // MARK: - Haptic Feedback
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    @ObservedObject var recordingService: ActivityRecordingService
    let activityType: String
    let customName: String

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var showingStopConfirmation = false
    @State private var showingPostRecording = false
    @State private var pulseAnimation = false
    @State private var expandedMetric: ExpandedMetric? = nil

    @StateObject private var timerManager = TimerUpdateManager()

    // Enum to track which metric card is expanded
    private enum ExpandedMetric {
        case distance
        case pace
    }

    // TODO: Re-enable when background audio mode is added back
    // @StateObject private var audioCoaching = AudioCoachingService()
    private let audioCoachingEnabled = false

    private var activityIcon: String {
        switch activityType.lowercased() {
        case "run": return "figure.run"
        case "walk": return "figure.walk"
        case "ride", "bike", "cycling": return "figure.outdoor.cycle"
        case "hike": return "figure.hiking"
        case "swim": return "figure.pool.swim"
        case "yoga": return "figure.mind.and.body"
        case "weight training", "workout": return "dumbbell.fill"
        default: return "figure.mixed.cardio"
        }
    }

    private var activityColor: Color {
        switch activityType.lowercased() {
        case "run": return .green
        case "walk": return .blue
        case "ride", "bike", "cycling": return .orange
        case "hike": return .brown
        case "swim": return .cyan
        case "yoga": return .purple
        case "weight training", "workout": return .red
        default: return .green
        }
    }

    private var background: Color {
        themeManager.isDarkMode ? AppTheme.Colors.DarkMode.background : AppTheme.Colors.LightMode.background
    }

    private var textPrimary: Color {
        themeManager.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary
    }

    private var textSecondary: Color {
        themeManager.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary
    }

    private var textTertiary: Color {
        themeManager.isDarkMode ? AppTheme.Colors.DarkMode.textTertiary : AppTheme.Colors.LightMode.textTertiary
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top status bar
                topStatusBar

                Spacer()

                // Main timer display
                mainTimerDisplay

                Spacer()

                // Metrics grid
                metricsGrid

                // Auto-pause indicator
                if recordingService.isAutopaused {
                    autoPauseIndicator
                        .padding(.top, AppTheme.Spacing.lg)
                }

                // Control buttons
                controlButtons
                    .padding(.top, AppTheme.Spacing.xxl)
                    .padding(.bottom, AppTheme.Spacing.huge)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            timerManager.start()
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
            // TODO: Re-enable when background audio mode is added back
            // audioCoaching.bind(to: recordingService)
        }
        .onDisappear {
            timerManager.stop()
            // TODO: Re-enable when background audio mode is added back
            // audioCoaching.unbind()
        }
        .confirmationDialog("Stop Recording", isPresented: $showingStopConfirmation) {
            Button("Stop and Save", role: .destructive) {
                stopRecording()
            }
            Button("Discard", role: .destructive) {
                discardRecording()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Do you want to save this activity or discard it?")
        }
        .fullScreenCover(isPresented: $showingPostRecording) {
            PostRecordingView(recordingService: recordingService)
        }
        .onChange(of: recordingService.state) { oldState, newState in
            // When state returns to ready (after save or discard), dismiss the recording view
            if oldState == .completed && newState == .ready {
                dismiss()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .activitySavedSuccessfully)) { _ in
            // Activity was saved - dismiss this view to return to Feed
            dismiss()
        }
    }

    // MARK: - Top Status Bar

    private var topStatusBar: some View {
        HStack {
            // Activity type indicator
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: activityIcon)
                    .font(.body)
                Text(activityType)
                    .font(.body)
                    .fontWeight(.medium)
            }
            .foregroundColor(activityColor)
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.md)
            .background(
                Capsule()
                    .fill(activityColor.opacity(0.15))
            )

            Spacer()

            // Recording state indicator
            HStack(spacing: AppTheme.Spacing.xs) {
                Circle()
                    .fill(recordingStateColor)
                    .frame(width: 8, height: 8)
                    .opacity(pulseAnimation && recordingService.state == .recording ? 1.0 : 0.6)
                Text(recordingStateText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(textSecondary)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background(
                Capsule()
                    .fill(themeManager.isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
            )
        }
        .padding(.horizontal, AppTheme.Spacing.xl)
        .padding(.top, AppTheme.Spacing.lg)
    }

    private var recordingStateColor: Color {
        switch recordingService.state {
        case .recording: return .red
        case .paused: return .orange
        default: return .gray
        }
    }

    private var recordingStateText: String {
        switch recordingService.state {
        case .recording: return "Recording"
        case .paused: return "Paused"
        default: return "Ready"
        }
    }

    // MARK: - Main Timer Display

    private var mainTimerDisplay: some View {
        VStack(spacing: 24) {
            // Large activity icon with pulse effect
            ZStack {
                // Outer pulse ring (only when recording)
                if recordingService.state == .recording {
                    Circle()
                        .stroke(activityColor.opacity(0.2), lineWidth: 2)
                        .frame(width: 140, height: 140)
                        .scaleEffect(pulseAnimation ? 1.15 : 1.0)
                        .opacity(pulseAnimation ? 0 : 0.5)
                }

                // Middle ring
                Circle()
                    .stroke(activityColor.opacity(0.3), lineWidth: 3)
                    .frame(width: 120, height: 120)

                // Inner filled circle
                Circle()
                    .fill(activityColor.opacity(0.15))
                    .frame(width: 100, height: 100)

                // Icon
                Image(systemName: activityIcon)
                    .font(.system(size: 44))
                    .foregroundColor(activityColor)
            }

            // Large timer
            Text(formatTime(timerManager.elapsedTime))
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundColor(textPrimary)
                .monospacedDigit()
        }
    }

    // MARK: - Metrics Grid

    private var metricsGrid: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            // Primary metrics row (Distance and Pace) - tappable for expanded context
            HStack(spacing: AppTheme.Spacing.xl) {
                expandablePrimaryMetricCard(
                    value: UnitFormatter.formatDistance(recordingService.gpsService.totalDistance, decimals: 2, includeUnit: false),
                    unit: UnitFormatter.distanceUnitAbbreviation,
                    label: "Distance",
                    icon: "point.topleft.down.to.point.bottomright.curvepath",
                    metric: .distance,
                    expandedContent: {
                        // Show elapsed time context when expanded
                        HStack(spacing: AppTheme.Spacing.md) {
                            VStack(spacing: 2) {
                                Text(formatTime(timerManager.elapsedTime))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(textPrimary)
                                Text("Elapsed")
                                    .font(.caption2)
                                    .foregroundColor(textTertiary)
                            }
                            Divider().frame(height: 24)
                            VStack(spacing: 2) {
                                Text("\(recordingService.gpsService.routePoints.count)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(textPrimary)
                                Text("GPS pts")
                                    .font(.caption2)
                                    .foregroundColor(textTertiary)
                            }
                        }
                    }
                )

                expandablePrimaryMetricCard(
                    value: UnitFormatter.formatPaceTime(minutesPerMile: recordingService.gpsService.currentPace),
                    unit: UnitFormatter.paceUnitLabel,
                    label: "Pace",
                    icon: "speedometer",
                    metric: .pace,
                    expandedContent: {
                        // Show average pace comparison when expanded
                        HStack(spacing: AppTheme.Spacing.md) {
                            VStack(spacing: 2) {
                                Text(UnitFormatter.formatPaceTime(minutesPerMile: recordingService.gpsService.averagePace))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(textPrimary)
                                Text("Average")
                                    .font(.caption2)
                                    .foregroundColor(textTertiary)
                            }
                            Divider().frame(height: 24)
                            VStack(spacing: 2) {
                                Text(UnitFormatter.formatSpeedValue(recordingService.gpsService.currentSpeed))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(textPrimary)
                                Text(UnitFormatter.speedUnitLabel)
                                    .font(.caption2)
                                    .foregroundColor(textTertiary)
                            }
                        }
                    }
                )
            }

            // Secondary metrics row (max 2 for glanceability)
            HStack(spacing: AppTheme.Spacing.md) {
                secondaryMetricCard(
                    value: UnitFormatter.formatPaceTime(minutesPerMile: recordingService.gpsService.averagePace),
                    label: "Avg Pace"
                )

                secondaryMetricCard(
                    value: UnitFormatter.formatSpeedValue(recordingService.gpsService.currentSpeed),
                    label: "Speed (\(UnitFormatter.speedUnitLabel))"
                )
            }
        }
        .padding(.horizontal, AppTheme.Spacing.xl)
    }

    private func primaryMetricCard(value: String, unit: String, label: String, icon: String) -> some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            HStack(alignment: .lastTextBaseline, spacing: AppTheme.Spacing.xs) {
                Text(value)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(textPrimary)
                    .monospacedDigit()
                Text(unit)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(textSecondary)
            }

            HStack(spacing: AppTheme.Spacing.xs) {
                Image(systemName: icon)
                    .font(.caption)
                Text(label)
                    .font(.caption)
            }
            .foregroundColor(textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                .fill(themeManager.isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.04))
        )
    }

    /// Expandable primary metric card with tap-to-reveal additional context
    @ViewBuilder
    private func expandablePrimaryMetricCard<Content: View>(
        value: String,
        unit: String,
        label: String,
        icon: String,
        metric: ExpandedMetric,
        @ViewBuilder expandedContent: () -> Content
    ) -> some View {
        let isExpanded = expandedMetric == metric

        VStack(spacing: AppTheme.Spacing.sm) {
            // Main metric display
            HStack(alignment: .lastTextBaseline, spacing: AppTheme.Spacing.xs) {
                Text(value)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(textPrimary)
                    .monospacedDigit()
                Text(unit)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(textSecondary)
            }

            // Label with expand indicator
            HStack(spacing: AppTheme.Spacing.xs) {
                Image(systemName: icon)
                    .font(.caption)
                Text(label)
                    .font(.caption)
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(textTertiary)
            }
            .foregroundColor(textSecondary)

            // Expanded content with animation
            if isExpanded {
                Divider()
                    .background(textTertiary.opacity(0.3))
                    .padding(.horizontal, AppTheme.Spacing.md)

                expandedContent()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                .fill(themeManager.isDarkMode ? Color.white.opacity(isExpanded ? 0.12 : 0.08) : Color.black.opacity(isExpanded ? 0.06 : 0.04))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            impactFeedback.impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if expandedMetric == metric {
                    expandedMetric = nil
                } else {
                    expandedMetric = metric
                }
            }
        }
    }

    private func secondaryMetricCard(value: String, label: String) -> some View {
        VStack(spacing: AppTheme.Spacing.xs) {
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(textPrimary)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundColor(textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                .fill(themeManager.isDarkMode ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
        )
    }

    // MARK: - Auto Pause Indicator

    private var autoPauseIndicator: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "pause.circle.fill")
                .foregroundColor(.orange)
            Text("Auto-paused - Start moving to resume")
                .font(.subheadline)
                .foregroundColor(textSecondary)
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, AppTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                .fill(Color.orange.opacity(0.15))
        )
        .padding(.horizontal, AppTheme.Spacing.xl)
    }

    // MARK: - Control Buttons

    private var controlButtons: some View {
        HStack(spacing: AppTheme.Spacing.xxl) {
            // Pause/Resume button
            Button(action: togglePauseResume) {
                VStack(spacing: AppTheme.Spacing.xs) {
                    Image(systemName: pauseResumeIcon)
                        .font(.title)
                        .foregroundColor(.white)
                        .frame(
                            width: AppTheme.Layout.touchTargetMotionPreferred,
                            height: AppTheme.Layout.touchTargetMotionPreferred
                        )
                        .background(pauseResumeColor, in: Circle())
                        .shadow(color: pauseResumeColor.opacity(0.4), radius: 10, x: 0, y: 4)

                    Text(pauseResumeLabel)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(textSecondary)
                }
            }
            .disabled(recordingService.isAutopaused)
            .opacity(recordingService.isAutopaused ? 0.5 : 1.0)

            // Stop button
            Button(action: triggerStopConfirmation) {
                VStack(spacing: AppTheme.Spacing.xs) {
                    Image(systemName: "stop.fill")
                        .font(.title)
                        .foregroundColor(.white)
                        .frame(
                            width: AppTheme.Layout.touchTargetMotionPreferred,
                            height: AppTheme.Layout.touchTargetMotionPreferred
                        )
                        .background(.red, in: Circle())
                        .shadow(color: Color.red.opacity(0.4), radius: 10, x: 0, y: 4)

                    Text("Stop")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(textSecondary)
                }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.xl)
    }
    
    // MARK: - Computed Properties

    private var pauseResumeIcon: String {
        switch recordingService.state {
        case .recording:
            return "pause.fill"
        case .paused:
            return "play.fill"
        default:
            return "pause.fill"
        }
    }

    private var pauseResumeColor: Color {
        switch recordingService.state {
        case .recording:
            return .orange
        case .paused:
            return .green
        default:
            return .orange
        }
    }

    private var pauseResumeLabel: String {
        switch recordingService.state {
        case .recording:
            return "Pause"
        case .paused:
            return "Resume"
        default:
            return "Pause"
        }
    }

    // MARK: - Methods

    private func togglePauseResume() {
        impactFeedback.impactOccurred()
        switch recordingService.state {
        case .recording:
            recordingService.pauseRecording()
        case .paused:
            recordingService.resumeRecording()
        default:
            break
        }
    }

    private func stopRecording() {
        notificationFeedback.notificationOccurred(.success)
        recordingService.stopRecording()
        showingPostRecording = true
    }

    private func discardRecording() {
        notificationFeedback.notificationOccurred(.warning)
        recordingService.discardRecording()
        dismiss()
    }

    private func triggerStopConfirmation() {
        impactFeedback.impactOccurred()
        showingStopConfirmation = true
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    private func formatPace(_ pace: Double) -> String {
        guard pace > 0 && pace < 999 else { return "--:--" }
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    ActiveRecordingView(
        recordingService: ActivityRecordingService(),
        activityType: "Run",
        customName: "Morning Run"
    )
}