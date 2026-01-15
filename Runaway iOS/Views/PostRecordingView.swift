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
    @Environment(\.dismiss) private var dismiss

    @State private var activityName = ""
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showingSaveError = false
    @FocusState private var isNameFocused: Bool

    // Check if we have a valid route (more than 1 point with actual movement)
    private var hasValidRoute: Bool {
        let points = recordingService.gpsService.routePoints
        guard points.count > 1 else { return false }

        // Check if there's actually meaningful distance (more than 10 meters)
        let totalDistance = recordingService.gpsService.totalDistance
        return totalDistance > 10
    }

    private var activityIcon: String {
        let activityType = recordingService.currentSession?.activityType ?? "Run"
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
        let activityType = recordingService.currentSession?.activityType ?? "Run"
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

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Activity name input - prominent at top
                    activityNameSection

                    // Activity summary metrics
                    activitySummarySection

                    // Route map preview - only show if valid route exists
                    if hasValidRoute {
                        routeSection
                    }

                    // Time statistics
                    timeStatisticsSection
                }
                .padding()
            }
            .background(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.surfaceBackground : AppTheme.Colors.LightMode.surfaceBackground)
            .navigationTitle("Activity Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Discard") {
                        recordingService.discardRecording()
                        dismiss()
                    }
                    .foregroundColor(.red)
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: saveActivity) {
                        if isSaving {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Saving...")
                            }
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isSaving || activityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .alert("Save Error", isPresented: $showingSaveError) {
            Button("OK") { }
        } message: {
            Text(saveError ?? "Unknown error occurred while saving activity")
        }
        .onAppear {
            if activityName.isEmpty {
                activityName = recordingService.currentSession?.name ?? ""
            }
        }
    }

    // MARK: - Activity Name Section

    private var activityNameSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Activity type badge and date
            HStack {
                // Activity type badge
                HStack(spacing: 8) {
                    Image(systemName: activityIcon)
                        .font(.body)
                    Text(recordingService.currentSession?.activityType ?? "Run")
                        .font(.body)
                        .fontWeight(.medium)
                }
                .foregroundColor(activityColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(activityColor.opacity(0.15))
                )

                Spacer()

                // Date
                Text(formatDate(recordingService.currentSession?.startTime ?? Date()))
                    .font(.subheadline)
                    .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
            }

            // Editable activity name
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Activity Name")
                        .font(.caption)
                        .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)

                    Spacer()

                    Button(action: { isNameFocused = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                            Text("Edit")
                        }
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.accent)
                    }
                }

                TextField("Enter activity name", text: $activityName)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary)
                    .focused($isNameFocused)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(ThemeManager.shared.isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isNameFocused ? AppTheme.Colors.accent : Color.clear, lineWidth: 2)
                    )
            }
        }
        .padding()
        .background(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.cardBackground : AppTheme.Colors.LightMode.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - Activity Summary Section

    private var activitySummarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Summary")
                .font(.headline)
                .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                SummaryMetricCard(
                    title: "Distance",
                    value: UnitFormatter.formatDistance(recordingService.gpsService.totalDistance, decimals: 2, includeUnit: false),
                    unit: UnitFormatter.distanceUnitName,
                    icon: "road.lanes",
                    color: .blue
                )

                SummaryMetricCard(
                    title: "Time",
                    value: formatTime(recordingService.currentSession?.elapsedTime ?? 0),
                    unit: "",
                    icon: "clock",
                    color: .green
                )

                SummaryMetricCard(
                    title: "Avg Pace",
                    value: UnitFormatter.formatPaceTime(minutesPerMile: recordingService.gpsService.averagePace),
                    unit: UnitFormatter.paceUnitLabel,
                    icon: "speedometer",
                    color: .orange
                )

                SummaryMetricCard(
                    title: "Avg Speed",
                    value: UnitFormatter.formatSpeedValue(recordingService.gpsService.averageSpeed),
                    unit: UnitFormatter.speedUnitLabel,
                    icon: "gauge.high",
                    color: .purple
                )
            }
        }
    }

    // MARK: - Route Section

    private var routeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Route")
                .font(.headline)
                .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary)

            RoutePreviewMap(
                routePoints: recordingService.gpsService.routePoints
            )
            .frame(height: 200)
            .cornerRadius(12)
        }
    }

    // MARK: - Time Statistics Section

    private var timeStatisticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Time")
                .font(.headline)
                .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary)

            HStack {
                StatItem(
                    title: "Started",
                    value: formatStartTime(recordingService.currentSession?.startTime ?? Date()),
                    icon: "clock.arrow.circlepath"
                )

                Spacer()

                StatItem(
                    title: "Ended",
                    value: formatStartTime(recordingService.currentSession?.endTime ?? Date()),
                    icon: "flag.checkered"
                )

                if hasValidRoute {
                    Spacer()

                    StatItem(
                        title: "GPS Points",
                        value: "\(recordingService.gpsService.routePoints.count)",
                        icon: "location.circle"
                    )
                }
            }
            .padding()
            .background(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.cardBackground : AppTheme.Colors.LightMode.cardBackground)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Methods

    private func saveActivity() {
        guard !activityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        isSaving = true

        // Update session name
        recordingService.currentSession?.name = activityName.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            do {
                let savedActivity = try await recordingService.saveActivity()

                await MainActor.run {
                    isSaving = false

                    if savedActivity != nil {
                        // Successfully saved - notify to dismiss all recording sheets
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
    
    private func formatPace(_ pace: Double) -> String {
        guard pace > 0 && pace < 999 else { return "--:--" }
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
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

// MARK: - Summary Metric Card
struct SummaryMetricCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary)

                    if !unit.isEmpty {
                        Text(unit)
                            .font(.caption)
                            .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textTertiary : AppTheme.Colors.LightMode.textTertiary)
                    }
                }

                Text(title)
                    .font(.caption)
                    .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
            }
        }
        .padding()
        .background(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.cardBackground : AppTheme.Colors.LightMode.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - Stat Item
struct StatItem: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(AppTheme.Colors.accent)
                .font(.title3)

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary)

            Text(title)
                .font(.caption2)
                .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Route Preview Map
struct RoutePreviewMap: UIViewRepresentable {
    let routePoints: [GPSRoutePoint]

    func makeUIView(context: Context) -> MapView {
        let mapInitOptions = MapInitOptions(styleURI: .standard)
        let mapView = MapView(frame: .zero, mapInitOptions: mapInitOptions)

        // Disable interactions for preview using gestures options
        mapView.gestures.options.panEnabled = false
        mapView.gestures.options.pinchEnabled = false
        mapView.gestures.options.rotateEnabled = false
        mapView.gestures.options.pitchEnabled = false

        // Hide ornaments
        mapView.ornaments.compassView.isHidden = true
        mapView.ornaments.scaleBarView.isHidden = true
        mapView.ornaments.logoView.isHidden = true
        mapView.ornaments.attributionButton.isHidden = true

        // Add route when style loads
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

        // Remove existing sources and layers if they exist
        try? mapView.mapboxMap.removeLayer(withId: "route-layer")
        try? mapView.mapboxMap.removeSource(withId: "route-source")
        try? mapView.mapboxMap.removeLayer(withId: "markers-layer")
        try? mapView.mapboxMap.removeSource(withId: "markers-source")

        // Create LineString from coordinates
        let lineString = LineString(coordinates)

        // Create GeoJSON source for route
        var routeSource = GeoJSONSource(id: "route-source")
        routeSource.data = .geometry(.lineString(lineString))

        // Add route source to map
        try? mapView.mapboxMap.addSource(routeSource)

        // Create line layer for the route
        var lineLayer = LineLayer(id: "route-layer", source: "route-source")
        lineLayer.lineColor = .constant(StyleColor(UIColor(AppTheme.Colors.accent)))
        lineLayer.lineWidth = .constant(4)
        lineLayer.lineCap = .constant(.round)
        lineLayer.lineJoin = .constant(.round)

        // Add route layer to map
        try? mapView.mapboxMap.addLayer(lineLayer)

        // Add start and end markers
        let startPoint = Point(coordinates.first!)
        let endPoint = Point(coordinates.last!)

        var features: [Feature] = []

        // Start marker feature
        var startFeature = Feature(geometry: .point(startPoint))
        startFeature.properties = [
            "marker-type": .string("start")
        ]
        features.append(startFeature)

        // End marker feature
        var endFeature = Feature(geometry: .point(endPoint))
        endFeature.properties = [
            "marker-type": .string("end")
        ]
        features.append(endFeature)

        // Create markers source
        var markersSource = GeoJSONSource(id: "markers-source")
        markersSource.data = .featureCollection(FeatureCollection(features: features))

        // Add markers source
        try? mapView.mapboxMap.addSource(markersSource)

        // Create circle layer for markers
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

        // Add markers layer
        try? mapView.mapboxMap.addLayer(markersLayer)

        // Calculate bounds and fit camera
        let minLat = coordinates.map { $0.latitude }.min() ?? coordinates[0].latitude
        let maxLat = coordinates.map { $0.latitude }.max() ?? coordinates[0].latitude
        let minLon = coordinates.map { $0.longitude }.min() ?? coordinates[0].longitude
        let maxLon = coordinates.map { $0.longitude }.max() ?? coordinates[0].longitude

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        // Validate coordinates are not at 0,0 (invalid GPS)
        guard center.latitude != 0 || center.longitude != 0 else {
            // Default to a reasonable zoom if GPS data is invalid
            let camera = CameraOptions(center: center, zoom: 2)
            mapView.mapboxMap.setCamera(to: camera)
            return
        }

        // Add padding to ensure the route is fully visible
        let latDelta = (maxLat - minLat) * 1.3
        let lonDelta = (maxLon - minLon) * 1.3

        // Calculate zoom level from delta, with minimum delta to prevent infinite zoom
        let maxDelta = max(latDelta, lonDelta, 0.001) // Minimum delta prevents division issues
        let zoom = min(max(log2(360 / maxDelta) - 1, 10), 18) // Clamp zoom between 10-18

        let camera = CameraOptions(
            center: center,
            zoom: zoom
        )
        mapView.mapboxMap.setCamera(to: camera)
    }
}

#Preview {
    PostRecordingView(recordingService: ActivityRecordingService())
}