//
//  CardView.swift
//  RunawayUI
//
//  Created by Jack Rudelic on 7/22/24.
//

import SwiftUI
import MapKit
import CoreLocation
import UIKit

// Create simplified card view
struct CardView: View {
    let activity: LocalActivity
    let onTap: (() -> Void)?
    let previousActivities: [LocalActivity]
    @State var image: UIImage?
    @State private var isPressed = false

    init(activity: LocalActivity, previousActivities: [LocalActivity] = [], onTap: (() -> Void)? = nil) {
        self.activity = activity
        self.previousActivities = previousActivities
        self.onTap = onTap
    }

    var body: some View {
        Button(action: {
            print("🔥 CardView button pressed for activity: \(activity.name ?? "Unknown")")
            onTap?()
        }) {
            VStack(alignment: .leading, spacing: 0) {
                // Main content area
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    // Header with activity info and date
                    HStack {
                        HStack(spacing: AppTheme.Spacing.xs) {
                            Image(systemName: activityIcon)
                                .foregroundColor(AppTheme.Colors.activityColor(for: activity.type ?? ""))
                                .font(.title2)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(activity.name ?? "Unknown Activity")
                                    .font(AppTheme.Typography.headline)
                                    .foregroundColor(AppTheme.Colors.textPrimary)

                                Text(activity.type ?? "Unknown Type")
                                    .font(AppTheme.Typography.caption)
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                        }

                        Spacer()

                        if let startDate = activity.start_date {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(startDate, style: .date)
                                    .font(AppTheme.Typography.caption)
                                    .foregroundColor(AppTheme.Colors.textSecondary)

                                Text(startDate, style: .time)
                                    .font(AppTheme.Typography.caption)
                                    .foregroundColor(AppTheme.Colors.textTertiary)

                                Text(timeAgoString(from: startDate))
                                    .font(.caption2)
                                    .foregroundColor(AppTheme.Colors.textTertiary)
                            }
                        }
                    }

                    // Map view with modern styling
                    if let polyline = activity.summary_polyline, !polyline.isEmpty {
                        ActivityMapView(summaryPolyline: polyline)
                            .frame(height: AppTheme.Layout.mapPreviewHeight)
                            .cornerRadius(AppTheme.CornerRadius.medium)
                            .themeShadow(.light)
                    }

                    // Metrics row with modern styling
                    HStack(spacing: AppTheme.Spacing.lg) {
                        if let distance = activity.distance {
                            MetricPill(
                                icon: AppIcons.distance,
                                value: String(format: "%.2f", distance * 0.000621371),
                                unit: "mi",
                                color: .purple
                            )
                        }

                        if let time = activity.elapsed_time {
                            MetricPill(
                                icon: AppIcons.time,
                                value: formatTime(seconds: time),
                                unit: "",
                                color: AppTheme.Colors.accent
                            )
                        }

                        if let distance = activity.distance, let time = activity.elapsed_time {
                            MetricPill(
                                icon: AppIcons.pace,
                                value: calculatePace(distance: distance * 0.000621371, time: time),
                                unit: "/mi",
                                color: AppTheme.Colors.warning
                            )
                        }

                        Spacer()
                    }
                }
                .padding(AppTheme.Spacing.md)

                // AI Insights Banner - Full width at bottom
                if let insights = generateInsights() {
                    AIInsightsBanner(insights: insights)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
    
    private var activityIcon: String {
        switch (activity.type ?? "").lowercased() {
        case "run", "running": return "figure.run"
        case "walk", "walking": return "figure.walk"
        case "bike", "cycling": return "bicycle"
        default: return "figure.mixed.cardio"
        }
    }
    
    private func calculatePace(distance: Double, time: Double) -> String {
        guard distance > 0, time > 0 else { return "--:--" }
        let paceInSeconds = time / distance
        let minutes = Int(paceInSeconds) / 60
        let seconds = Int(paceInSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func timeAgoString(from date: Date) -> String {
        let timeInterval = Date().timeIntervalSince(date)

        if timeInterval < 60 {
            return "just now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m ago"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)h ago"
        } else if timeInterval < 2592000 { // 30 days
            let days = Int(timeInterval / 86400)
            return "\(days)d ago"
        } else {
            // For older activities, just show the date
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }

    private func generateInsights() -> ActivityInsight? {
        guard let currentDistance = activity.distance,
              let currentTime = activity.elapsed_time,
              currentDistance > 0, currentTime > 0 else {
            return nil
        }

        // Get similar activities from the last 30 days (same type)
        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()

        let recentSimilarActivities = previousActivities.filter { previous in
            guard let prevDate = previous.start_date,
                  prevDate > thirtyDaysAgo,
                  previous.type?.lowercased() == activity.type?.lowercased(),
                  let prevDistance = previous.distance,
                  let prevTime = previous.elapsed_time,
                  prevDistance > 0, prevTime > 0 else {
                return false
            }
            return true
        }

        guard recentSimilarActivities.count >= 3 else {
            return nil // Need at least 3 activities for comparison
        }

        // Calculate current pace (min/mile)
        let currentPace = (currentTime / 60) / (currentDistance * 0.000621371)

        // Calculate average pace from recent activities
        let avgPace = recentSimilarActivities.reduce(0.0) { sum, act in
            guard let dist = act.distance, let time = act.elapsed_time, dist > 0 else { return sum }
            return sum + ((time / 60) / (dist * 0.000621371))
        } / Double(recentSimilarActivities.count)

        // Pace change percentage
        let paceChange = ((avgPace - currentPace) / avgPace) * 100

        // Generate insight
        var insights: [String] = []

        if abs(paceChange) >= 3 {
            if paceChange > 0 {
                insights.append("🚀 \(Int(paceChange))% faster than avg")
            } else {
                insights.append("🐢 \(Int(abs(paceChange)))% slower than avg")
            }
        }

        // Distance comparison
        let avgDistance = recentSimilarActivities.reduce(0.0) { sum, act in
            sum + (act.distance ?? 0)
        } / Double(recentSimilarActivities.count)

        let distanceChange = ((currentDistance - avgDistance) / avgDistance) * 100

        if abs(distanceChange) >= 10 {
            if distanceChange > 0 {
                insights.append("📈 \(Int(distanceChange))% longer run")
            } else {
                insights.append("📉 \(Int(abs(distanceChange)))% shorter run")
            }
        }

        // Estimate VO2 max change (simple approximation)
        // VO2 max roughly correlates with pace improvement
        if paceChange >= 5 {
            insights.append("💪 Fitness improving")
        }

        return insights.isEmpty ? nil : ActivityInsight(messages: insights)
    }
}

// MARK: - Activity Insight Model

struct ActivityInsight {
    let messages: [String]
}

// MARK: - AI Insights Banner

struct AIInsightsBanner: View {
    let insights: ActivityInsight

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Left section - Label
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)

                    Text("AI Insights")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .textCase(.uppercase)
                }

                if let firstInsight = insights.messages.first {
                    Text(firstInsight)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.black)
                }
            }

            Spacer()

            // Right section - Additional insights
            if insights.messages.count > 1 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Performance")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .textCase(.uppercase)

                    ForEach(insights.messages.dropFirst(), id: \.self) { message in
                        Text(message)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.black)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Color(red: 0.2, green: 0.85, blue: 0.4) // Neon green like walk bar
        )
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: AppTheme.CornerRadius.large,
                bottomTrailingRadius: AppTheme.CornerRadius.large,
                topTrailingRadius: 0
            )
        )
    }
}

struct ActivityMapView: UIViewRepresentable {
    let summaryPolyline: String?
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.isZoomEnabled = false
        mapView.mapType = .mutedStandard
        mapView.isScrollEnabled = false
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        guard let polyline = summaryPolyline else { return }
        
        // Decode the polyline
        let coordinates = decodePolyline(polyline)
        
        print("🗺️ Decoded coordinates: \(coordinates.count) points")
        
        // Show first few coordinates for debugging
        for (index, coord) in coordinates.prefix(5).enumerated() {
            print("🗺️ Coordinate \(index): lat=\(coord.latitude), lng=\(coord.longitude)")
        }
        
        // Create the polyline overlay
        let routePolyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(routePolyline)
        
        // Set the region to show the entire route
        if let firstCoordinate = coordinates.first {
            let minLat = coordinates.map { $0.latitude }.min() ?? firstCoordinate.latitude
            let maxLat = coordinates.map { $0.latitude }.max() ?? firstCoordinate.latitude
            let minLon = coordinates.map { $0.longitude }.min() ?? firstCoordinate.longitude
            let maxLon = coordinates.map { $0.longitude }.max() ?? firstCoordinate.longitude
            
            print("🗺️ Coordinate bounds:")
            print("🗺️ Lat range: \(minLat) to \(maxLat)")
            print("🗺️ Lng range: \(minLon) to \(maxLon)")
            
            let center = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            )
            
            let span = MKCoordinateSpan(
                latitudeDelta: (maxLat - minLat) * 1.5,
                longitudeDelta: (maxLon - minLon) * 1.5
            )
            
            print("🗺️ Map center: \(center.latitude), \(center.longitude)")
            print("🗺️ Map span: \(span.latitudeDelta), \(span.longitudeDelta)")
            
            let region = MKCoordinateRegion(center: center, span: span)
            mapView.setRegion(region, animated: true)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(.orange)
                renderer.lineWidth = 4
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
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
        
        print("🗺️ Original polyline: \(encodedPolyline.prefix(50))...")
        print("🗺️ Unescaped polyline: \(unescapedPolyline.prefix(50))...")
        print("🗺️ Polyline length: \(unescapedPolyline.count)")
        
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
        
        print("🗺️ Decoded \(coordinates.count) coordinates")
        if let first = coordinates.first, let last = coordinates.last {
            print("🗺️ First coordinate: \(first.latitude), \(first.longitude)")
            print("🗺️ Last coordinate: \(last.latitude), \(last.longitude)")
        }
        
        return coordinates
    }
}

struct RoutePoint: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

struct MapPolyline: Shape {
    let coordinates: [CLLocationCoordinate2D]
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let points = coordinates.map { coordinate -> CGPoint in
            let lat = coordinate.latitude
            let lon = coordinate.longitude
            let x = rect.width * (lon + 180) / 360
            let y = rect.height * (1 - (lat + 90) / 180)
            return CGPoint(x: x, y: y)
        }
        
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        
        return path
    }
}

private func formatTime(seconds: TimeInterval) -> String {
    let hours = Int(seconds) / 3600
    let minutes = (Int(seconds) % 3600) / 60
    
    if hours > 0 {
        return "\(hours)h \(minutes)m"
    } else {
        return "\(minutes)m"
    }
}

struct SnapshotView: View {
    var snapshot: UIImage?
    
    var body: some View {
        if let snapshot {
            Image(uiImage: snapshot)
        } else {
            EmptyView() // Or a placeholder
                .frame(height: 200) // Match map height
                .background(Color.gray.opacity(0.2))
        }
    }
}

fileprivate struct ModifierCornerRadiusWithBorder: ViewModifier {
    var radius: CGFloat
    var borderLineWidth: CGFloat = 1
    var borderColor: Color = .gray
    var antialiased: Bool = true
    
    func body(content: Content) -> some View {
        content
            .cornerRadius(self.radius, antialiased: self.antialiased)
            .overlay(
                RoundedRectangle(cornerRadius: self.radius)
                    .inset(by: self.borderLineWidth)
                    .strokeBorder(self.borderColor, lineWidth: self.borderLineWidth, antialiased: self.antialiased)
            )
    }
}

extension View {
    func cornerRadiusWithBorder(radius: CGFloat, borderLineWidth: CGFloat = 1, borderColor: Color = .gray, antialiased: Bool = true) -> some View {
        modifier(ModifierCornerRadiusWithBorder(radius: radius, borderLineWidth: borderLineWidth, borderColor: borderColor, antialiased: antialiased))
    }
}
