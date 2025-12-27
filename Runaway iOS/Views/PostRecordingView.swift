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
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Route map preview
                    if !recordingService.gpsService.routePoints.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Route")
                                .font(.headline)
                                .foregroundColor(AppTheme.Colors.LightMode.textPrimary)
                            
                            RoutePreviewMap(
                                routePoints: recordingService.gpsService.routePoints
                            )
                            .frame(height: 200)
                            .cornerRadius(12)
                        }
                    }
                    
                    // Activity summary
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Activity Summary")
                            .font(.headline)
                            .foregroundColor(AppTheme.Colors.LightMode.textPrimary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                            SummaryMetricCard(
                                title: "Distance",
                                value: String(format: "%.2f", recordingService.gpsService.totalDistanceMiles),
                                unit: "miles",
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
                                value: formatPace(recordingService.gpsService.averagePace),
                                unit: "/mile",
                                icon: "speedometer",
                                color: .orange
                            )
                            
                            SummaryMetricCard(
                                title: "Avg Speed",
                                value: String(format: "%.1f", recordingService.gpsService.averageSpeed * 2.237),
                                unit: "mph",
                                icon: "gauge.high",
                                color: .purple
                            )
                        }
                    }
                    
                    // Activity details
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Activity Details")
                            .font(.headline)
                            .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

                        VStack(spacing: 12) {
                            // Activity name input
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Activity Name")
                                    .font(.subheadline)
                                    .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
                                
                                TextField("Enter activity name", text: $activityName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .onAppear {
                                        if activityName.isEmpty {
                                            activityName = recordingService.currentSession?.name ?? ""
                                        }
                                    }
                            }
                            
                            // Activity type and date
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Type")
                                        .font(.caption)
                                        .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
                                    Text(recordingService.currentSession?.activityType ?? "Run")
                                        .font(.subheadline)
                                        .foregroundColor(AppTheme.Colors.LightMode.textPrimary)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Date")
                                        .font(.caption)
                                        .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
                                    Text(formatDate(recordingService.currentSession?.startTime ?? Date()))
                                        .font(.subheadline)
                                        .foregroundColor(AppTheme.Colors.LightMode.textPrimary)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .padding()
                        .background(AppTheme.Colors.LightMode.cardBackground)
                        .cornerRadius(12)
                    }
                    
                    // Additional stats
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Route Statistics")
                            .font(.headline)
                            .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

                        HStack {
                            StatItem(
                                title: "Route Points",
                                value: "\(recordingService.gpsService.routePoints.count)",
                                icon: "location.circle"
                            )

                            Spacer()

                            StatItem(
                                title: "Start Time",
                                value: formatStartTime(recordingService.currentSession?.startTime ?? Date()),
                                icon: "clock.arrow.circlepath"
                            )

                            Spacer()

                            StatItem(
                                title: "End Time",
                                value: formatStartTime(recordingService.currentSession?.endTime ?? Date()),
                                icon: "flag.checkered"
                            )
                        }
                        .padding()
                        .background(AppTheme.Colors.LightMode.cardBackground)
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .background(AppTheme.Colors.LightMode.surfaceBackground)
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
                        // Successfully saved, dismiss view
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
                        .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

                    if !unit.isEmpty {
                        Text(unit)
                            .font(.caption)
                            .foregroundColor(AppTheme.Colors.LightMode.textTertiary)
                    }
                }

                Text(title)
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
            }
        }
        .padding()
        .background(AppTheme.Colors.LightMode.cardBackground)
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
                .foregroundColor(AppTheme.Colors.LightMode.accent)
                .font(.title3)

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

            Text(title)
                .font(.caption2)
                .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
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
        lineLayer.lineColor = .constant(StyleColor(UIColor(AppTheme.Colors.LightMode.accent)))
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

        // Add padding to ensure the route is fully visible
        let latDelta = (maxLat - minLat) * 1.3
        let lonDelta = (maxLon - minLon) * 1.3

        // Calculate zoom level from delta
        let maxDelta = max(latDelta, lonDelta)
        let zoom = log2(360 / maxDelta) - 1

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