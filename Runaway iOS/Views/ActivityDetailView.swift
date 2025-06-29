//
//  ActivityDetailView.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 6/29/25.
//

import SwiftUI
import MapKit

struct ActivityDetailView: View {
    let activity: LocalActivity
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()
            
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
                    .background(AppTheme.Colors.background)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .foregroundColor(AppTheme.Colors.primary)
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
                    .foregroundColor(AppTheme.Colors.primary)
                    .font(.title)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(activity.name ?? "Unknown Activity")
                        .font(AppTheme.Typography.title)
                        .foregroundColor(AppTheme.Colors.primaryText)
                    
                    Text(activity.type ?? "Unknown Type")
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppTheme.Colors.secondaryText)
                }
                
                Spacer()
            }
            
            if let startDate = activity.start_date {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Date & Time")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.mutedText)
                        .textCase(.uppercase)
                    
                    Text(startDate, style: .date)
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppTheme.Colors.primaryText)
                    
                    Text(startDate, style: .time)
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppTheme.Colors.secondaryText)
                }
            }
        }
        .padding()
        .background(AppTheme.Colors.cardBackground)
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
                    color: AppTheme.Colors.primary
                )
            }
            
            if let time = activity.elapsed_time {
                DetailMetricCard(
                    title: "Duration",
                    value: formatDetailedTime(seconds: time),
                    unit: "",
                    icon: "clock",
                    color: AppTheme.Colors.accent
                )
            }
            
            if let distance = activity.distance, let time = activity.elapsed_time {
                DetailMetricCard(
                    title: "Avg Pace",
                    value: calculateDetailedPace(distance: distance * 0.000621371, time: time),
                    unit: "/mile",
                    icon: "speedometer",
                    color: AppTheme.Colors.warning
                )
            }
            
            if let distance = activity.distance, let time = activity.elapsed_time {
                let avgSpeed = (distance * 0.000621371) / (time / 3600) // mph
                DetailMetricCard(
                    title: "Avg Speed",
                    value: String(format: "%.1f", avgSpeed),
                    unit: "mph",
                    icon: "gauge.high",
                    color: AppTheme.Colors.success
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
                        .foregroundColor(AppTheme.Colors.primaryText)
                    
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.caption)
                            .foregroundColor(AppTheme.Colors.mutedText)
                    }
                }
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.secondaryText)
                    .textCase(.uppercase)
            }
        }
        .padding()
        .background(AppTheme.Colors.cardBackground)
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
                .foregroundColor(AppTheme.Colors.primaryText)
            
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
        .background(AppTheme.Colors.cardBackground)
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
                .foregroundColor(AppTheme.Colors.secondaryText)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(AppTheme.Colors.primaryText)
        }
    }
}

// MARK: - Activity Detail Map View
struct ActivityDetailMapView: UIViewRepresentable {
    let summaryPolyline: String?
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .standard
        mapView.showsUserLocation = false
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isUserInteractionEnabled = true
        mapView.showsCompass = true
        mapView.showsScale = true
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        guard let polyline = summaryPolyline else { return }
        
        // Clear existing overlays
        mapView.removeOverlays(mapView.overlays)
        
        // Decode the polyline
        let coordinates = decodePolyline(polyline)
        
        // Create the polyline overlay
        let routePolyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(routePolyline)
        
        // Set the region to show the entire route with padding
        if let firstCoordinate = coordinates.first {
            let minLat = coordinates.map { $0.latitude }.min() ?? firstCoordinate.latitude
            let maxLat = coordinates.map { $0.latitude }.max() ?? firstCoordinate.latitude
            let minLon = coordinates.map { $0.longitude }.min() ?? firstCoordinate.longitude
            let maxLon = coordinates.map { $0.longitude }.max() ?? firstCoordinate.longitude
            
            let center = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            )
            
            let span = MKCoordinateSpan(
                latitudeDelta: (maxLat - minLat) * 1.3,
                longitudeDelta: (maxLon - minLon) * 1.3
            )
            
            let region = MKCoordinateRegion(center: center, span: span)
            mapView.setRegion(region, animated: false)
        }
        
        // Add start and end point annotations
        if coordinates.count >= 2 {
            let startAnnotation = MKPointAnnotation()
            startAnnotation.coordinate = coordinates.first!
            startAnnotation.title = "Start"
            
            let endAnnotation = MKPointAnnotation()
            endAnnotation.coordinate = coordinates.last!
            endAnnotation.title = "Finish"
            
            mapView.addAnnotations([startAnnotation, endAnnotation])
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(AppTheme.Colors.primary)
                renderer.lineWidth = 5
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            
            let identifier = "ActivityPoint"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }
            
            // Customize pin color based on title
            if let pinView = annotationView as? MKPinAnnotationView {
                pinView.pinTintColor = annotation.title == "Start" ? .green : .red
            }
            
            return annotationView
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