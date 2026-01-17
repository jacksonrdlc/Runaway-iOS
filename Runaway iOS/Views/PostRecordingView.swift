//
//  PostRecordingView.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 6/29/25.
//

import SwiftUI
import MapboxMaps
import CoreLocation
import Combine

struct PostRecordingView: View {
    @ObservedObject var recordingService: ActivityRecordingService
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var activityName = ""
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showingSaveError = false
    @State private var showContent = false
    @FocusState private var isNameFocused: Bool

    // MARK: - Computed Properties

    private var hasValidRoute: Bool {
        let points = recordingService.gpsService.routePoints
        guard points.count > 1 else { return false }
        let totalDistance = recordingService.gpsService.totalDistance
        return totalDistance > 10
    }

    private var isDistanceBasedActivity: Bool {
        let activityType = recordingService.currentSession?.activityType ?? "Run"
        let distanceTypes = ["run", "walk", "ride", "bike", "cycling", "hike", "swim"]
        return distanceTypes.contains(activityType.lowercased())
    }

    private var activityType: String {
        recordingService.currentSession?.activityType ?? "Run"
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
        case "run": return Color(red: 1.0, green: 0.42, blue: 0.21) // Energetic coral
        case "walk": return Color(red: 0.29, green: 0.56, blue: 0.85) // Calm blue
        case "ride", "bike", "cycling": return Color(red: 1.0, green: 0.72, blue: 0) // Vibrant yellow
        case "hike": return Color(red: 0.18, green: 0.55, blue: 0.30) // Earth green
        case "swim": return .cyan
        case "yoga": return Color(red: 0.61, green: 0.49, blue: 0.85) // Soft purple
        case "weight training", "workout": return Color(red: 0.90, green: 0.22, blue: 0.21) // Bold red
        default: return .green
        }
    }

    private var congratulatoryMessage: String {
        let messages: [String] = [
            "You crushed it!",
            "Great work!",
            "Way to show up!",
            "Awesome effort!",
            "Nailed it!"
        ]
        return messages.randomElement() ?? "Great work!"
    }

    private var background: Color {
        themeManager.isDarkMode ? AppTheme.Colors.DarkMode.background : AppTheme.Colors.LightMode.background
    }

    private var cardBackground: Color {
        themeManager.isDarkMode ? AppTheme.Colors.DarkMode.cardBackground : AppTheme.Colors.LightMode.cardBackground
    }

    private var textPrimary: Color {
        themeManager.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary
    }

    private var textSecondary: Color {
        themeManager.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom header
                customHeader

                ScrollView {
                    VStack(spacing: 24) {
                        // Celebration section
                        celebrationSection
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 20)

                        // Hero metric
                        heroMetricSection
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 20)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: showContent)

                        // Activity name input
                        activityNameSection
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 20)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: showContent)

                        // Secondary metrics grid
                        secondaryMetricsSection
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 20)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: showContent)

                        // Route map preview - only show if valid route exists
                        if hasValidRoute {
                            routeSection
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : 20)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.25), value: showContent)
                        }

                        // Time details
                        timeDetailsSection
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 20)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: showContent)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarHidden(true)
        .alert("Save Error", isPresented: $showingSaveError) {
            Button("OK") { }
        } message: {
            Text(saveError ?? "Unknown error occurred while saving activity")
        }
        .onAppear {
            if activityName.isEmpty {
                activityName = recordingService.currentSession?.name ?? ""
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showContent = true
            }
        }
    }

    // MARK: - Custom Header

    private var customHeader: some View {
        HStack {
            Button(action: {
                recordingService.discardRecording()
                dismiss()
            }) {
                Text("Discard")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.red.opacity(0.15))
                    )
            }
            .disabled(isSaving)

            Spacer()

            Button(action: saveActivity) {
                HStack(spacing: 8) {
                    if isSaving {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    }
                    Text(isSaving ? "Saving..." : "Save")
                        .font(.body)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(activityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving
                              ? Color.gray
                              : activityColor)
                )
            }
            .disabled(isSaving || activityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Celebration Section

    private var celebrationSection: some View {
        VStack(spacing: 16) {
            // Activity icon with glow effect
            ZStack {
                // Glow rings
                Circle()
                    .fill(activityColor.opacity(0.1))
                    .frame(width: 120, height: 120)

                Circle()
                    .fill(activityColor.opacity(0.15))
                    .frame(width: 100, height: 100)

                Circle()
                    .fill(activityColor.opacity(0.2))
                    .frame(width: 80, height: 80)

                Image(systemName: activityIcon)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(activityColor)
            }

            // Congratulatory message
            VStack(spacing: 4) {
                Text(congratulatoryMessage)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(textPrimary)

                Text("\(activityType) Complete")
                    .font(.subheadline)
                    .foregroundColor(textSecondary)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Hero Metric Section

    private var heroMetricSection: some View {
        VStack(spacing: 8) {
            if isDistanceBasedActivity {
                // Distance as hero for runs, walks, rides, etc.
                Text(UnitFormatter.formatDistance(recordingService.gpsService.totalDistance, decimals: 2, includeUnit: false))
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundColor(textPrimary)
                    .monospacedDigit()

                Text(UnitFormatter.distanceUnitName.uppercased())
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(textSecondary)
                    .tracking(2)
            } else {
                // Duration as hero for yoga, strength training, etc.
                Text(formatTime(recordingService.currentSession?.elapsedTime ?? 0))
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundColor(textPrimary)
                    .monospacedDigit()

                Text("DURATION")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(textSecondary)
                    .tracking(2)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Activity Name Section

    private var activityNameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Activity type badge
                HStack(spacing: 6) {
                    Image(systemName: activityIcon)
                        .font(.caption)
                    Text(activityType)
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundColor(activityColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(activityColor.opacity(0.15))
                )

                Spacer()

                // Date
                Text(formatDate(recordingService.currentSession?.startTime ?? Date()))
                    .font(.caption)
                    .foregroundColor(textSecondary)
            }

            // Editable activity name
            TextField("Name your activity...", text: $activityName)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(textPrimary)
                .focused($isNameFocused)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(themeManager.isDarkMode ? Color.white.opacity(0.06) : Color.black.opacity(0.03))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isNameFocused ? activityColor : Color.clear, lineWidth: 2)
                )
        }
        .padding(16)
        .background(cardBackground)
        .cornerRadius(16)
    }

    // MARK: - Secondary Metrics Section

    private var secondaryMetricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stats")
                .font(.headline)
                .foregroundColor(textPrimary)

            if isDistanceBasedActivity {
                // Distance-based activity metrics
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    CompactMetricCard(
                        icon: "clock.fill",
                        value: formatTime(recordingService.currentSession?.elapsedTime ?? 0),
                        label: "Duration",
                        color: .green
                    )

                    CompactMetricCard(
                        icon: "speedometer",
                        value: UnitFormatter.formatPaceTime(minutesPerMile: recordingService.gpsService.averagePace),
                        label: "Avg Pace",
                        color: .orange
                    )

                    CompactMetricCard(
                        icon: "gauge.with.dots.needle.67percent",
                        value: UnitFormatter.formatSpeedValue(recordingService.gpsService.averageSpeed),
                        label: "Avg Speed (\(UnitFormatter.speedUnitLabel))",
                        color: .purple
                    )

                    if recordingService.gpsService.elevationGain > 0 {
                        CompactMetricCard(
                            icon: "mountain.2.fill",
                            value: String(format: "%.0f", recordingService.gpsService.elevationGain),
                            label: "Elevation (m)",
                            color: .brown
                        )
                    } else {
                        CompactMetricCard(
                            icon: "flame.fill",
                            value: "--",
                            label: "Calories",
                            color: .red
                        )
                    }
                }
            } else {
                // Duration-based activity metrics (yoga, strength, etc.)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    CompactMetricCard(
                        icon: "flame.fill",
                        value: "--",
                        label: "Calories",
                        color: .red
                    )

                    CompactMetricCard(
                        icon: "heart.fill",
                        value: "--",
                        label: "Avg Heart Rate",
                        color: .pink
                    )

                    CompactMetricCard(
                        icon: "bolt.fill",
                        value: formatActiveMinutes(recordingService.currentSession?.elapsedTime ?? 0),
                        label: "Active Minutes",
                        color: .yellow
                    )

                    CompactMetricCard(
                        icon: "star.fill",
                        value: activityType,
                        label: "Activity Type",
                        color: activityColor
                    )
                }
            }
        }
    }

    // MARK: - Route Section

    private var routeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Route")
                .font(.headline)
                .foregroundColor(textPrimary)

            RoutePreviewMap(routePoints: recordingService.gpsService.routePoints)
                .frame(height: 180)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(themeManager.isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.05), lineWidth: 1)
                )
        }
    }

    // MARK: - Time Details Section

    private var timeDetailsSection: some View {
        HStack(spacing: 0) {
            // Started
            VStack(spacing: 6) {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)

                Text(formatStartTime(recordingService.currentSession?.startTime ?? Date()))
                    .font(.headline)
                    .foregroundColor(textPrimary)

                Text("Started")
                    .font(.caption)
                    .foregroundColor(textSecondary)
            }
            .frame(maxWidth: .infinity)

            // Divider
            Rectangle()
                .fill(themeManager.isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                .frame(width: 1, height: 50)

            // Ended
            VStack(spacing: 6) {
                Image(systemName: "stop.circle.fill")
                    .font(.title2)
                    .foregroundColor(.red)

                Text(formatStartTime(recordingService.currentSession?.endTime ?? Date()))
                    .font(.headline)
                    .foregroundColor(textPrimary)

                Text("Ended")
                    .font(.caption)
                    .foregroundColor(textSecondary)
            }
            .frame(maxWidth: .infinity)

            if hasValidRoute {
                // Divider
                Rectangle()
                    .fill(themeManager.isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                    .frame(width: 1, height: 50)

                // GPS Points
                VStack(spacing: 6) {
                    Image(systemName: "location.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)

                    Text("\(recordingService.gpsService.routePoints.count)")
                        .font(.headline)
                        .foregroundColor(textPrimary)

                    Text("GPS Points")
                        .font(.caption)
                        .foregroundColor(textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 16)
        .background(cardBackground)
        .cornerRadius(16)
    }

    // MARK: - Methods

    private func saveActivity() {
        guard !activityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        isSaving = true
        recordingService.currentSession?.name = activityName.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            do {
                let savedActivity = try await recordingService.saveActivity()

                await MainActor.run {
                    isSaving = false

                    if savedActivity != nil {
                        NotificationCenter.default.post(name: .activitySavedSuccessfully, object: nil)
                        dismiss()
                    } else {
                        saveError = "Failed to save activity"
                        showingSaveError = true
                    }
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    saveError = error.localizedDescription
                    showingSaveError = true
                }
            }
        }
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

    private func formatActiveMinutes(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        return "\(minutes)"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func formatStartTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Compact Metric Card

struct CompactMetricCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(themeManager.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(label)
                    .font(.caption)
                    .foregroundColor(themeManager.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(themeManager.isDarkMode ? AppTheme.Colors.DarkMode.cardBackground : AppTheme.Colors.LightMode.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - Route Preview Map

struct RoutePreviewMap: UIViewRepresentable {
    let routePoints: [GPSRoutePoint]

    func makeUIView(context: Context) -> MapView {
        let mapInitOptions = MapInitOptions(styleURI: .standard)
        let mapView = MapView(frame: .zero, mapInitOptions: mapInitOptions)

        mapView.gestures.options.panEnabled = false
        mapView.gestures.options.pinchEnabled = false
        mapView.gestures.options.rotateEnabled = false
        mapView.gestures.options.pitchEnabled = false

        mapView.ornaments.compassView.isHidden = true
        mapView.ornaments.scaleBarView.isHidden = true
        mapView.ornaments.logoView.isHidden = true
        mapView.ornaments.attributionButton.isHidden = true

        mapView.mapboxMap.onStyleLoaded.observe { _ in
            self.addRouteToMap(mapView)
        }.store(in: &context.coordinator.cancellables)

        return mapView
    }

    func updateUIView(_ mapView: MapView, context: Context) {
        addRouteToMap(mapView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var cancellables = Set<AnyCancelable>()
    }

    private func addRouteToMap(_ mapView: MapView) {
        guard routePoints.count > 1 else { return }

        let coordinates = routePoints.map { $0.coordinate }

        try? mapView.mapboxMap.removeLayer(withId: "route-layer")
        try? mapView.mapboxMap.removeSource(withId: "route-source")
        try? mapView.mapboxMap.removeLayer(withId: "markers-layer")
        try? mapView.mapboxMap.removeSource(withId: "markers-source")

        let lineString = LineString(coordinates)

        var routeSource = GeoJSONSource(id: "route-source")
        routeSource.data = .geometry(.lineString(lineString))
        try? mapView.mapboxMap.addSource(routeSource)

        var lineLayer = LineLayer(id: "route-layer", source: "route-source")
        lineLayer.lineColor = .constant(StyleColor(UIColor(AppTheme.Colors.accent)))
        lineLayer.lineWidth = .constant(4)
        lineLayer.lineCap = .constant(.round)
        lineLayer.lineJoin = .constant(.round)
        try? mapView.mapboxMap.addLayer(lineLayer)

        let startPoint = Point(coordinates.first!)
        let endPoint = Point(coordinates.last!)

        var features: [Feature] = []

        var startFeature = Feature(geometry: .point(startPoint))
        startFeature.properties = ["marker-type": .string("start")]
        features.append(startFeature)

        var endFeature = Feature(geometry: .point(endPoint))
        endFeature.properties = ["marker-type": .string("end")]
        features.append(endFeature)

        var markersSource = GeoJSONSource(id: "markers-source")
        markersSource.data = .featureCollection(FeatureCollection(features: features))
        try? mapView.mapboxMap.addSource(markersSource)

        var markersLayer = CircleLayer(id: "markers-layer", source: "markers-source")
        markersLayer.circleRadius = .constant(8)
        markersLayer.circleColor = .expression(
            Exp(.match) {
                Exp(.get) { "marker-type" }
                "start"
                UIColor.systemGreen
                "end"
                UIColor.systemRed
                UIColor.gray
            }
        )
        markersLayer.circleStrokeColor = .constant(StyleColor(.white))
        markersLayer.circleStrokeWidth = .constant(2)
        try? mapView.mapboxMap.addLayer(markersLayer)

        let minLat = coordinates.map { $0.latitude }.min() ?? coordinates[0].latitude
        let maxLat = coordinates.map { $0.latitude }.max() ?? coordinates[0].latitude
        let minLon = coordinates.map { $0.longitude }.min() ?? coordinates[0].longitude
        let maxLon = coordinates.map { $0.longitude }.max() ?? coordinates[0].longitude

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        guard center.latitude != 0 || center.longitude != 0 else {
            let camera = CameraOptions(center: center, zoom: 2)
            mapView.mapboxMap.setCamera(to: camera)
            return
        }

        let latDelta = (maxLat - minLat) * 1.3
        let lonDelta = (maxLon - minLon) * 1.3
        let maxDelta = max(latDelta, lonDelta, 0.001)
        let zoom = min(max(log2(360 / maxDelta) - 1, 10), 18)

        let camera = CameraOptions(center: center, zoom: zoom)
        mapView.mapboxMap.setCamera(to: camera)
    }
}

#Preview {
    PostRecordingView(recordingService: ActivityRecordingService())
}
