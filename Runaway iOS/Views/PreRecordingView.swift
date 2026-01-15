//
//  PreRecordingView.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 6/29/25.
//

import SwiftUI
import CoreLocation

struct PreRecordingView: View {
    @StateObject private var recordingService = ActivityRecordingService()
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared

    @State private var showingPermissionAlert = false
    @State private var showingRecordingView = false
    @State private var activityType = "Run"
    @State private var showingActivityTypeSelector = false
    @State private var locationName: String?
    @State private var pulseAnimation = false

    // Activities that require GPS tracking
    private let gpsActivities = ["run", "walk", "ride", "hike", "swim", "bike", "cycling"]

    private var needsGPS: Bool {
        gpsActivities.contains(activityType.lowercased())
    }

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

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                topBar

                Spacer()

                // Main content - activity icon and status
                mainContent

                Spacer()

                // Bottom controls
                bottomControls
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            setupLocationServices()
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
        .onDisappear {
            if !showingRecordingView {
                recordingService.gpsService.stopLocationUpdates()
            }
        }
        .alert("Location Permission Required", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                openAppSettings()
            }
            Button("Cancel", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("Please enable location access in Settings to record your activity route.")
        }
        .sheet(isPresented: $showingActivityTypeSelector) {
            ActivityTypePickerSheet(
                selectedTypeName: $activityType,
                title: "Select Activity",
                subtitle: "Choose your activity type"
            )
        }
        .fullScreenCover(isPresented: $showingRecordingView) {
            ActiveRecordingView(
                recordingService: recordingService,
                activityType: activityType,
                customName: ""
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .activitySavedSuccessfully)) { _ in
            // Activity was saved - dismiss this view to return to Feed
            dismiss()
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(textSecondary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(themeManager.isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                    )
            }

            Spacer()

            // Activity type selector
            Button(action: { showingActivityTypeSelector = true }) {
                HStack(spacing: 8) {
                    Image(systemName: activityIcon)
                        .font(.body)
                    Text(activityType)
                        .font(.body)
                        .fontWeight(.medium)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .foregroundColor(textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(themeManager.isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 32) {
            // Large activity icon with pulse effect
            ZStack {
                // Outer pulse ring
                Circle()
                    .stroke(activityColor.opacity(0.2), lineWidth: 2)
                    .frame(width: 180, height: 180)
                    .scaleEffect(pulseAnimation ? 1.15 : 1.0)
                    .opacity(pulseAnimation ? 0 : 0.5)

                // Middle ring
                Circle()
                    .stroke(activityColor.opacity(0.3), lineWidth: 3)
                    .frame(width: 160, height: 160)

                // Inner filled circle
                Circle()
                    .fill(activityColor.opacity(0.15))
                    .frame(width: 140, height: 140)

                // Icon
                Image(systemName: activityIcon)
                    .font(.system(size: 60))
                    .foregroundColor(activityColor)
            }

            // Status text
            VStack(spacing: 12) {
                Text("Ready to \(activityType)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(textPrimary)

                if needsGPS {
                    // GPS status for location-based activities
                    gpsStatusView
                } else {
                    // Simple ready message for non-GPS activities
                    Text("Tap start when you're ready")
                        .font(.body)
                        .foregroundColor(textSecondary)
                }
            }
        }
    }

    // MARK: - GPS Status View

    private var gpsStatusView: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(locationStatusColor)
                .frame(width: 8, height: 8)

            Text(locationStatusText)
                .font(.subheadline)
                .foregroundColor(textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(themeManager.isDarkMode ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
        )
    }

    private var locationStatusColor: Color {
        switch recordingService.gpsService.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return recordingService.gpsService.currentLocation != nil ? .green : .yellow
        case .denied, .restricted:
            return .red
        default:
            return .orange
        }
    }

    private var locationStatusText: String {
        switch recordingService.gpsService.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if let name = locationName {
                return name
            } else if recordingService.gpsService.currentLocation != nil {
                return "GPS Ready"
            } else {
                return "Finding location..."
            }
        case .denied, .restricted:
            return "Location access denied"
        case .notDetermined:
            return "Requesting location..."
        @unknown default:
            return "Checking location..."
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 16) {
            // Start button
            Button(action: startRecording) {
                HStack(spacing: 12) {
                    Image(systemName: "play.fill")
                        .font(.title2)
                    Text("Start \(activityType)")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(canStartRecording ? activityColor : Color.gray)
                )
                .shadow(color: canStartRecording ? activityColor.opacity(0.4) : .clear, radius: 12, x: 0, y: 6)
            }
            .disabled(!canStartRecording)
            .scaleEffect(canStartRecording ? 1.0 : 0.98)
            .animation(.easeInOut(duration: 0.2), value: canStartRecording)

            // Help text for GPS activities that need permission
            if needsGPS && !recordingService.gpsService.authorizationStatus.isAuthorized {
                Text("Location permission required for route tracking")
                    .font(.caption)
                    .foregroundColor(textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }

    // MARK: - Computed Properties

    private var canStartRecording: Bool {
        if needsGPS {
            return recordingService.canStartRecording
        } else {
            // Non-GPS activities can always start
            return true
        }
    }

    // MARK: - Methods

    private func setupLocationServices() {
        guard needsGPS else { return }

        recordingService.requestLocationPermission()

        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            let isAuthorized = recordingService.gpsService.authorizationStatus.isAuthorized

            if isAuthorized {
                recordingService.gpsService.startLocationUpdates()
                timer.invalidate()
                monitorLocationForGeocoding()
            } else if recordingService.gpsService.authorizationStatus == .denied ||
                      recordingService.gpsService.authorizationStatus == .restricted {
                timer.invalidate()
                showingPermissionAlert = true
            }

            if timer.fireDate.timeIntervalSinceNow < -10 {
                timer.invalidate()
                if !isAuthorized {
                    showingPermissionAlert = true
                }
            }
        }
    }

    private func monitorLocationForGeocoding() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if let location = recordingService.gpsService.currentLocation {
                reverseGeocodeLocation(location)
                timer.invalidate()
            }

            if timer.fireDate.timeIntervalSinceNow < -30 {
                timer.invalidate()
            }
        }
    }

    private func reverseGeocodeLocation(_ location: CLLocation) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            DispatchQueue.main.async {
                guard error == nil, let placemark = placemarks?.first else { return }

                var components: [String] = []
                if let name = placemark.name {
                    components.append(name)
                } else if let thoroughfare = placemark.thoroughfare {
                    components.append(thoroughfare)
                }
                if let locality = placemark.locality {
                    components.append(locality)
                }

                self.locationName = components.prefix(2).joined(separator: ", ")
            }
        }
    }

    private func startRecording() {
        guard canStartRecording else {
            if needsGPS && !recordingService.gpsService.authorizationStatus.isAuthorized {
                showingPermissionAlert = true
            }
            return
        }

        recordingService.startRecording(
            activityType: activityType,
            name: ""
        )

        showingRecordingView = true
    }

    private func openAppSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

#Preview {
    PreRecordingView()
}
