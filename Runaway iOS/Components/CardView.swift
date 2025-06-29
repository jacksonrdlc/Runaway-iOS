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
    @State var image: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            // Header with activity info and date
            HStack {
                HStack(spacing: AppTheme.Spacing.xs) {
                    Image(systemName: activityIcon)
                        .foregroundColor(AppTheme.Colors.primary)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(activity.name ?? "Unknown Activity")
                            .font(AppTheme.Typography.headline)
                            .foregroundColor(AppTheme.Colors.primaryText)
                        
                        Text(activity.type ?? "Unknown Type")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.secondaryText)
                    }
                }
                
                Spacer()
                
                if let startDate = activity.start_date {
                    Text(startDate, style: .date)
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.mutedText)
                }
            }
            
            // Map view with modern styling
            if let polyline = activity.summary_polyline, !polyline.isEmpty {
                ActivityMapView(summaryPolyline: polyline)
                    .frame(height: 200)
                    .cornerRadius(AppTheme.CornerRadius.medium)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            }

            // Metrics row with modern styling
            HStack(spacing: AppTheme.Spacing.lg) {
                if let distance = activity.distance {
                    MetricPill(
                        icon: AppIcons.distance,
                        value: String(format: "%.2f", distance * 0.000621371),
                        unit: "mi",
                        color: AppTheme.Colors.primary
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
        .surfaceCard()
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
}

struct ActivityMapView: UIViewRepresentable {
    let summaryPolyline: String?
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
//        mapView.isZoomEnabled = false
        mapView.mapType = .mutedStandard
        mapView.isScrollEnabled = false
        mapView.isUserInteractionEnabled = false
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
                renderer.strokeColor = UIColor(AppTheme.Colors.primary)
                renderer.lineWidth = 4
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
    
    private func decodePolyline(_ encodedPolyline: String) -> [CLLocationCoordinate2D] {
        // Unescape the polyline string
        let unescapedPolyline = encodedPolyline
            .replacingOccurrences(of: "\\\\", with: "\\")
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\r", with: "\r")
            .replacingOccurrences(of: "\\t", with: "\t")
        
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
