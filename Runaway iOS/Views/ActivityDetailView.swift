//
//  ActivityDetailView.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 6/29/25.
//

import SwiftUI
import MapboxMaps
import CoreLocation
import Combine

struct ActivityDetailView: View {
    let activity: LocalActivity
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            AppTheme.Colors.LightMode.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Map Section (1/3 of screen if map exists)
                    if let polyline = activity.summary_polyline, !polyline.isEmpty {
                        GeometryReader { geometry in
                            ActivityDetailMapView(summaryPolyline: polyline)
                                .frame(width: geometry.size.width)
                        }
                        .frame(height: UIScreen.main.bounds.height * 0.33)
                        .clipped()
                    }

                    // Activity Details Section
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                        // Header
                        ActivityDetailHeader(activity: activity)

                        // Metrics Grid
                        ActivityMetricsGrid(activity: activity)

                        // Additional Details
                        ActivityDetailInfo(activity: activity)

                        Spacer(minLength: 50)
                    }
                    .padding(AppTheme.Spacing.lg)
                    .background(AppTheme.Colors.LightMode.background)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.light, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .foregroundColor(AppTheme.Colors.LightMode.accent)
            }
        }
    }
}

// MARK: - Activity Detail Header
struct ActivityDetailHeader: View {
    let activity: LocalActivity

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack {
                Image(systemName: activityIcon)
                    .foregroundColor(AppTheme.Colors.LightMode.accent)
                    .font(.title)

                VStack(alignment: .leading, spacing: 4) {
                    Text(activity.name ?? "Unknown Activity")
                        .font(AppTheme.Typography.title)
                        .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

                    Text(activity.type ?? "Unknown Type")
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
                }

                Spacer()
            }

            if let startDate = activity.start_date {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Date & Time")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.LightMode.textTertiary)
                        .textCase(.uppercase)

                    Text(startDate, style: .date)
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

                    Text(startDate, style: .time)
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
                }
            }
        }
        .padding()
        .background(AppTheme.Colors.LightMode.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.medium)
    }
    
    private var activityIcon: String {
        switch (activity.type ?? "").lowercased() {
        case "run", "running": return "figure.run"
        case "walk", "walking": return "figure.walk"
        case "bike", "cycling": return "bicycle"
        default: return "figure.mixed.cardio"
        }
    }
}

// MARK: - Activity Metrics Grid
struct ActivityMetricsGrid: View {
    let activity: LocalActivity

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: AppTheme.Spacing.md) {
            if let distance = activity.distance {
                DetailMetricCard(
                    title: "Distance",
                    value: String(format: "%.2f", distance * 0.000621371),
                    unit: "miles",
                    icon: "road.lanes.curved.right",
                    color: AppTheme.Colors.LightMode.accent
                )
            }

            if let time = activity.elapsed_time {
                DetailMetricCard(
                    title: "Duration",
                    value: formatDetailedTime(seconds: time),
                    unit: "",
                    icon: "clock",
                    color: AppTheme.Colors.LightMode.accent
                )
            }

            if let distance = activity.distance, let time = activity.elapsed_time {
                DetailMetricCard(
                    title: "Avg Pace",
                    value: calculateDetailedPace(distance: distance * 0.000621371, time: time),
                    unit: "/mile",
                    icon: "speedometer",
                    color: AppTheme.Colors.LightMode.accent
                )
            }

            if let distance = activity.distance, let time = activity.elapsed_time {
                let avgSpeed = (distance * 0.000621371) / (time / 3600) // mph
                DetailMetricCard(
                    title: "Avg Speed",
                    value: String(format: "%.1f", avgSpeed),
                    unit: "mph",
                    icon: "gauge.high",
                    color: AppTheme.Colors.LightMode.accent
                )
            }
        }
    }
    
    private func formatDetailedTime(seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
    
    private func calculateDetailedPace(distance: Double, time: Double) -> String {
        guard distance > 0, time > 0 else { return "--:--" }
        let paceInSeconds = time / distance
        let minutes = Int(paceInSeconds) / 60
        let seconds = Int(paceInSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Detail Metric Card
struct DetailMetricCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
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
                    .textCase(.uppercase)
            }
        }
        .padding()
        .background(AppTheme.Colors.LightMode.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.medium)
    }
}

// MARK: - Activity Detail Info
struct ActivityDetailInfo: View {
    let activity: LocalActivity

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("Activity Details")
                .font(AppTheme.Typography.headline)
                .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

            VStack(spacing: AppTheme.Spacing.sm) {
                DetailInfoRow(label: "Activity ID", value: "\(activity.id)")

                if let startDate = activity.start_date {
                    DetailInfoRow(label: "Start Time", value: DateFormatter.detailFormatter.string(from: startDate))

                    if let endDate = calculateEndDate() {
                        DetailInfoRow(label: "End Time", value: DateFormatter.detailFormatter.string(from: endDate))
                    }
                }

                if let polyline = activity.summary_polyline, !polyline.isEmpty {
                    DetailInfoRow(label: "Route Data", value: "Available")
                } else {
                    DetailInfoRow(label: "Route Data", value: "Not Available")
                }
            }
        }
        .padding()
        .background(AppTheme.Colors.LightMode.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.medium)
    }
    
    private func calculateEndDate() -> Date? {
        guard let startDate = activity.start_date,
              let elapsed = activity.elapsed_time else { return nil }
        return startDate.addingTimeInterval(elapsed)
    }
}

// MARK: - Detail Info Row
struct DetailInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(AppTheme.Colors.LightMode.textSecondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .foregroundColor(AppTheme.Colors.LightMode.textPrimary)
        }
    }
}

// MARK: - Activity Detail Map View
struct ActivityDetailMapView: UIViewRepresentable {
    let summaryPolyline: String?

    func makeUIView(context: Context) -> MapView {
        let mapInitOptions = MapInitOptions(styleURI: .standard)
        let mapView = MapView(frame: .zero, mapInitOptions: mapInitOptions)

        // Enable interactions for detail view using gestures options
        mapView.gestures.options.panEnabled = true
        mapView.gestures.options.pinchEnabled = true
        mapView.gestures.options.rotateEnabled = true
        mapView.gestures.options.pitchEnabled = false

        // Show ornaments (compass, scale)
        mapView.ornaments.compassView.isHidden = false
        mapView.ornaments.scaleBarView.isHidden = false

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
        var cancellables = Set<AnyCancellable>()
    }

    private func addRouteToMap(_ mapView: MapView) {
        guard let polyline = summaryPolyline else { return }

        // Decode the polyline
        let coordinates = decodePolyline(polyline)

        guard !coordinates.isEmpty else { return }

        // Remove existing sources and layers if they exist
        try? mapView.mapboxMap.removeLayer(withId: "route-layer")
        try? mapView.mapboxMap.removeSource(withId: "route-source")
        try? mapView.mapboxMap.removeLayer(withId: "markers-layer")
        try? mapView.mapboxMap.removeSource(withId: "markers-source")

        // Convert coordinates to LineString
        let lineCoordinates = coordinates.map { coord in
            CLLocationCoordinate2D(latitude: coord.latitude, longitude: coord.longitude)
        }

        let lineString = LineString(lineCoordinates)

        // Create GeoJSON source for route
        var routeSource = GeoJSONSource(id: "route-source")
        routeSource.data = .geometry(.lineString(lineString))

        // Add route source to map
        try? mapView.mapboxMap.addSource(routeSource)

        // Create line layer for the route
        var lineLayer = LineLayer(id: "route-layer", source: "route-source")
        lineLayer.lineColor = .constant(StyleColor(UIColor(AppTheme.Colors.LightMode.accent)))
        lineLayer.lineWidth = .constant(5)
        lineLayer.lineCap = .constant(.round)
        lineLayer.lineJoin = .constant(.round)

        // Add route layer to map
        try? mapView.mapboxMap.addLayer(lineLayer)

        // Add start and end markers
        if coordinates.count >= 2 {
            let startPoint = Point(coordinates.first!)
            let endPoint = Point(coordinates.last!)

            var features: [Feature] = []

            // Start marker feature
            var startFeature = Feature(geometry: .point(startPoint))
            startFeature.properties = [
                "marker-type": .string("start"),
                "marker-color": .string("#34C759") // Green
            ]
            features.append(startFeature)

            // End marker feature
            var endFeature = Feature(geometry: .point(endPoint))
            endFeature.properties = [
                "marker-type": .string("end"),
                "marker-color": .string("#FF3B30") // Red
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
        }

        // Calculate bounds and fit camera with padding
        if let firstCoordinate = coordinates.first {
            let minLat = coordinates.map { $0.latitude }.min() ?? firstCoordinate.latitude
            let maxLat = coordinates.map { $0.latitude }.max() ?? firstCoordinate.latitude
            let minLon = coordinates.map { $0.longitude }.min() ?? firstCoordinate.longitude
            let maxLon = coordinates.map { $0.longitude }.max() ?? firstCoordinate.longitude

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

    private func decodePolyline(_ encodedPolyline: String) -> [CLLocationCoordinate2D] {
        // Enhanced unescape logic for polyline string
        var unescapedPolyline = encodedPolyline

        // Handle multiple levels of escaping in order
        // First pass: handle double backslashes
        unescapedPolyline = unescapedPolyline.replacingOccurrences(of: "\\\\\\\\", with: "\\\\")
        unescapedPolyline = unescapedPolyline.replacingOccurrences(of: "\\\\\\", with: "\\")
        unescapedPolyline = unescapedPolyline.replacingOccurrences(of: "\\\\", with: "\\")

        // Second pass: handle escaped quotes and other characters
        unescapedPolyline = unescapedPolyline.replacingOccurrences(of: "\\\"", with: "\"")
        unescapedPolyline = unescapedPolyline.replacingOccurrences(of: "\\'", with: "'")
        unescapedPolyline = unescapedPolyline.replacingOccurrences(of: "\\n", with: "\n")
        unescapedPolyline = unescapedPolyline.replacingOccurrences(of: "\\r", with: "\r")
        unescapedPolyline = unescapedPolyline.replacingOccurrences(of: "\\t", with: "\t")
        unescapedPolyline = unescapedPolyline.replacingOccurrences(of: "\\/", with: "/")

        // Handle JSON-style escaping if present
        unescapedPolyline = unescapedPolyline.replacingOccurrences(of: "\\u0022", with: "\"")
        unescapedPolyline = unescapedPolyline.replacingOccurrences(of: "\\u0027", with: "'")

        // Remove any remaining quote wrapping
        if unescapedPolyline.hasPrefix("\"") && unescapedPolyline.hasSuffix("\"") {
            unescapedPolyline = String(unescapedPolyline.dropFirst().dropLast())
        }

        var coordinates: [CLLocationCoordinate2D] = []
        let chars = Array(unescapedPolyline)
        var index = 0
        var lat = 0
        var lng = 0

        while index < chars.count {
            // Decode latitude
            var shift = 0
            var result = 0
            var byte: Int

            repeat {
                if index >= chars.count { break }
                byte = Int(chars[index].asciiValue!) - 63
                result |= (byte & 0x1F) << shift
                shift += 5
                index += 1
            } while byte >= 0x20

            let deltaLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
            lat += deltaLat

            // Decode longitude
            shift = 0
            result = 0

            repeat {
                if index >= chars.count { break }
                byte = Int(chars[index].asciiValue!) - 63
                result |= (byte & 0x1F) << shift
                shift += 5
                index += 1
            } while byte >= 0x20

            let deltaLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
            lng += deltaLng

            let coordinate = CLLocationCoordinate2D(
                latitude: Double(lat) / 1e5,
                longitude: Double(lng) / 1e5
            )
            coordinates.append(coordinate)
        }

        return coordinates
    }
}

// MARK: - DateFormatter Extension
extension DateFormatter {
    static let detailFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview {
    NavigationView {
        ActivityDetailView(activity: LocalActivity(
            id: 1,
            name: "Morning Run",
            type: "Run",
            summary_polyline: "sample_polyline",
            distance: 5000.0,
            start_date: Date(),
            elapsed_time: 1800
        ))
    }
}