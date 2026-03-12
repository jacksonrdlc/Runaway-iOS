//
//  ActivityDetailView.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 6/29/25.
//

import SwiftUI
import MapKit
import CoreLocation
import Combine

struct ActivityDetailView: View {
    let activity: LocalActivity
    @Environment(\.dismiss) private var dismiss
    @Environment(DataManager.self) var dataManager
    @ObservedObject private var themeManager = ThemeManager.shared

    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var showContent = false

    // MARK: - Computed Properties

    private var isDistanceBasedActivity: Bool {
        let activityType = activity.type ?? "Run"
        let distanceTypes = ["run", "walk", "ride", "bike", "cycling", "hike", "swim", "virtualrun", "virtualride", "trailrun", "gravel ride", "mountain bike ride"]
        return distanceTypes.contains(activityType.lowercased())
    }

    private var activityType: String {
        activity.type ?? "Workout"
    }

    private var activityIcon: String {
        switch activityType.lowercased() {
        case "run", "virtualrun": return "figure.run"
        case "walk": return "figure.walk"
        case "ride", "bike", "cycling", "virtualride": return "figure.outdoor.cycle"
        case "hike", "trailrun": return "figure.hiking"
        case "swim": return "figure.pool.swim"
        case "yoga": return "figure.mind.and.body"
        case "weight training", "weighttraining", "workout": return "dumbbell.fill"
        case "crossfit": return "figure.cross.training"
        case "elliptical": return "figure.elliptical"
        case "rowing": return "figure.rowing"
        case "rock climbing", "rockclimbing": return "figure.climbing"
        case "alpine ski", "alpineski": return "figure.skiing.downhill"
        case "snowboard": return "figure.snowboarding"
        case "mountain bike ride", "mountainbikeride": return "figure.outdoor.cycle"
        case "gravel ride", "gravelride": return "figure.outdoor.cycle"
        case "golf": return "figure.golf"
        default: return "figure.mixed.cardio"
        }
    }

    private var activityColor: Color {
        switch activityType.lowercased() {
        case "run", "virtualrun", "trailrun": return Color(red: 1.0, green: 0.42, blue: 0.21) // Energetic coral
        case "walk": return Color(red: 0.29, green: 0.56, blue: 0.85) // Calm blue
        case "ride", "bike", "cycling", "virtualride", "gravel ride", "gravelride", "mountain bike ride", "mountainbikeride": return Color(red: 1.0, green: 0.72, blue: 0) // Vibrant yellow
        case "hike": return Color(red: 0.18, green: 0.55, blue: 0.30) // Earth green
        case "swim": return .cyan
        case "yoga": return Color(red: 0.61, green: 0.49, blue: 0.85) // Soft purple
        case "weight training", "weighttraining", "workout", "crossfit": return Color(red: 0.90, green: 0.22, blue: 0.21) // Bold red
        case "alpine ski", "alpineski", "snowboard": return Color(red: 0.4, green: 0.6, blue: 0.9) // Ice blue
        case "golf": return Color(red: 0.13, green: 0.55, blue: 0.13) // Golf green
        default: return AppTheme.Colors.accent
        }
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

            ScrollView {
                VStack(spacing: 0) {
                    // Map Section (if route exists)
                    if let polyline = activity.summary_polyline, !polyline.isEmpty {
                        GeometryReader { geometry in
                            ActivityDetailMapView(summaryPolyline: polyline)
                                .frame(width: geometry.size.width)
                        }
                        .frame(height: UIScreen.main.bounds.height * 0.33)
                        .clipped()
                    }

                    // Activity Details Section
                    VStack(spacing: 20) {
                        // Header with activity info
                        activityHeaderSection
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 20)

                        // Hero metric
                        heroMetricSection
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 20)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: showContent)

                        // Secondary metrics grid
                        secondaryMetricsSection
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 20)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: showContent)

                        // Time details
                        timeDetailsSection
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 20)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: showContent)

                        Spacer(minLength: 50)
                    }
                    .padding(20)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Activity", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(activityColor)
                        .font(.title3)
                }
            }
        }
        .alert("Delete Activity", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteActivity()
            }
        } message: {
            Text("Are you sure you want to delete \"\(activity.name ?? "this activity")\"? This action cannot be undone.")
        }
        .overlay {
            if isDeleting {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay {
                        ProgressView("Deleting...")
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                    }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showContent = true
            }
        }
    }

    // MARK: - Activity Header Section

    private var activityHeaderSection: some View {
        VStack(spacing: 16) {
            // Activity icon with glow effect
            ZStack {
                Circle()
                    .fill(activityColor.opacity(0.1))
                    .frame(width: 100, height: 100)

                Circle()
                    .fill(activityColor.opacity(0.15))
                    .frame(width: 80, height: 80)

                Circle()
                    .fill(activityColor.opacity(0.2))
                    .frame(width: 60, height: 60)

                Image(systemName: activityIcon)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(activityColor)
            }

            // Activity name and type
            VStack(spacing: 6) {
                Text(activity.name ?? "Activity")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(textPrimary)
                    .multilineTextAlignment(.center)

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
            }

            // Date
            if let startDate = activity.start_date {
                Text(formatDate(startDate))
                    .font(.subheadline)
                    .foregroundColor(textSecondary)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Hero Metric Section

    private var heroMetricSection: some View {
        VStack(spacing: 8) {
            if isDistanceBasedActivity {
                // Distance as hero for runs, walks, rides, etc.
                if let distance = activity.distance {
                    Text(UnitFormatter.formatDistance(distance, decimals: 2, includeUnit: false))
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(textPrimary)
                        .monospacedDigit()

                    Text(UnitFormatter.distanceUnitName.uppercased())
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(textSecondary)
                        .tracking(2)
                }
            } else {
                // Duration as hero for yoga, strength training, etc.
                if let time = activity.elapsed_time {
                    Text(formatTime(seconds: time))
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(textPrimary)
                        .monospacedDigit()

                    Text("DURATION")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(textSecondary)
                        .tracking(2)
                }
            }
        }
        .padding(.vertical, 8)
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
                    if let time = activity.elapsed_time {
                        CompactMetricCard(
                            icon: "clock.fill",
                            value: formatTime(seconds: time),
                            label: "Duration",
                            color: .green
                        )
                    }

                    if let distance = activity.distance, let time = activity.elapsed_time, distance > 0 {
                        let paceSecondsPerMeter = time / distance
                        CompactMetricCard(
                            icon: "speedometer",
                            value: UnitFormatter.formatPace(secondsPerMeter: paceSecondsPerMeter),
                            label: "Avg Pace",
                            color: .orange
                        )
                    }

                    // Calculate average speed from distance and time
                    if let distance = activity.distance, let time = activity.elapsed_time, distance > 0, time > 0 {
                        let avgSpeedMPS = distance / time
                        CompactMetricCard(
                            icon: "gauge.with.dots.needle.67percent",
                            value: UnitFormatter.formatSpeed(avgSpeedMPS),
                            label: "Avg Speed",
                            color: .purple
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

                    if let time = activity.elapsed_time {
                        CompactMetricCard(
                            icon: "bolt.fill",
                            value: "\(Int(time / 60))",
                            label: "Active Minutes",
                            color: .yellow
                        )
                    }

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

    // MARK: - Time Details Section

    private var timeDetailsSection: some View {
        HStack(spacing: 0) {
            // Started
            if let startDate = activity.start_date {
                VStack(spacing: 6) {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)

                    Text(formatTimeOnly(startDate))
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
                if let elapsed = activity.elapsed_time {
                    let endDate = startDate.addingTimeInterval(elapsed)
                    VStack(spacing: 6) {
                        Image(systemName: "stop.circle.fill")
                            .font(.title2)
                            .foregroundColor(.red)

                        Text(formatTimeOnly(endDate))
                            .font(.headline)
                            .foregroundColor(textPrimary)

                        Text("Ended")
                            .font(.caption)
                            .foregroundColor(textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            // Route indicator
            if activity.summary_polyline != nil && !(activity.summary_polyline?.isEmpty ?? true) {
                Rectangle()
                    .fill(themeManager.isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                    .frame(width: 1, height: 50)

                VStack(spacing: 6) {
                    Image(systemName: "location.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)

                    Text("Yes")
                        .font(.headline)
                        .foregroundColor(textPrimary)

                    Text("Route")
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

    // MARK: - Helper Methods

    private func deleteActivity() {
        let activityId = activity.id

        isDeleting = true

        Task {
            do {
                try await ActivityService.deleteActivity(id: activityId)

                if let userId = UserSession.shared.userId {
                    await dataManager.loadActivities(for: userId)
                }

                await MainActor.run {
                    isDeleting = false
                    dismiss()
                }
            } catch {
                print("❌ Failed to delete activity: \(error)")
                await MainActor.run {
                    isDeleting = false
                }
            }
        }
    }

    private func formatTime(seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatTimeOnly(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Activity Detail Map View
struct ActivityDetailMapView: UIViewRepresentable {
    let summaryPolyline: String?

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.overrideUserInterfaceStyle = .dark
        mapView.delegate = context.coordinator
        mapView.isPitchEnabled = false
        mapView.showsCompass = true
        mapView.showsScale = true
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        addRouteToMap(mapView, coordinator: context.coordinator)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, MKMapViewDelegate {
        var startCircle: MKCircle?
        var endCircle: MKCircle?

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(AppTheme.Colors.accent)
                renderer.lineWidth = 5
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            if let circle = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circle)
                renderer.fillColor = (circle === startCircle) ? .systemGreen : .systemRed
                renderer.strokeColor = .white
                renderer.lineWidth = 2
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }

    private func addRouteToMap(_ mapView: MKMapView, coordinator: Coordinator) {
        guard let polylineStr = summaryPolyline else { return }
        let coordinates = decodePolyline(polylineStr)
        guard !coordinates.isEmpty else { return }

        mapView.removeOverlays(mapView.overlays)

        var mutableCoords = coordinates
        mapView.addOverlay(MKPolyline(coordinates: &mutableCoords, count: mutableCoords.count), level: .aboveRoads)

        if coordinates.count >= 2 {
            let start = MKCircle(center: coordinates.first!, radius: 12)
            let end   = MKCircle(center: coordinates.last!,  radius: 12)
            coordinator.startCircle = start
            coordinator.endCircle   = end
            mapView.addOverlay(start, level: .aboveRoads)
            mapView.addOverlay(end,   level: .aboveRoads)
        }

        let lats = coordinates.map(\.latitude), lons = coordinates.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(latitudeDelta: (maxLat - minLat) * 1.4, longitudeDelta: (maxLon - minLon) * 1.4)
        mapView.setRegion(MKCoordinateRegion(center: center, span: span), animated: false)
    }

    private func decodePolyline(_ encodedPolyline: String) -> [CLLocationCoordinate2D] {
        var unescapedPolyline = encodedPolyline
        for (a, b) in [("\\\\\\\\", "\\\\"), ("\\\\\\", "\\"), ("\\\\", "\\"),
                       ("\\\"", "\""), ("\\'", "'"), ("\\n", "\n"), ("\\r", "\r"),
                       ("\\t", "\t"), ("\\/", "/"), ("\\u0022", "\""), ("\\u0027", "'")] {
            unescapedPolyline = unescapedPolyline.replacingOccurrences(of: a, with: b)
        }
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