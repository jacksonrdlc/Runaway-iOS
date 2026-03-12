//
//  CardView.swift
//  Runaway iOS
//

import SwiftUI
import MapKit
import CoreLocation
import UIKit

struct CardView: View {
    let activity: LocalActivity
    let onTap: (() -> Void)?
    let previousActivities: [LocalActivity]
    @State private var isPressed = false

    private var hasValidRoute: Bool {
        guard let polyline = activity.summary_polyline, !polyline.isEmpty else { return false }
        guard let distance = activity.distance, distance >= 80 else { return false }
        return true
    }

    private var activityColor: Color {
        AppTheme.Colors.activityColor(for: activity.type ?? "")
    }

    private var activityIcon: String {
        switch (activity.type ?? "").lowercased() {
        case "run", "running", "trail run", "trailrun": return "figure.run"
        case "walk", "walking": return "figure.walk"
        case "bike", "cycling", "ride": return "bicycle"
        case "yoga": return "figure.mind.and.body"
        case "weight training", "weighttraining": return "dumbbell.fill"
        case "swim", "swimming": return "figure.pool.swim"
        case "hike", "hiking": return "figure.hiking"
        default: return "figure.mixed.cardio"
        }
    }

    init(activity: LocalActivity, previousActivities: [LocalActivity] = [], onTap: (() -> Void)? = nil) {
        self.activity = activity
        self.previousActivities = previousActivities
        self.onTap = onTap
    }

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: 0) {

                // ── MAP HERO ───────────────────────────────────────────────
                if hasValidRoute {
                    ZStack(alignment: .bottomLeading) {
                        ActivityMapView(summaryPolyline: activity.summary_polyline!)
                            .frame(height: 220)

                        HStack(spacing: 8) {
                            Image(systemName: activityIcon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(activityColor)
                            Text(activity.name ?? "Activity")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .background(Color.black.opacity(0.45))
                        .cornerRadius(10)
                        .padding(14)
                    }
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 16,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 16
                        )
                    )
                }

                // ── CONTENT ────────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 14) {

                    HStack(alignment: .top) {
                        if !hasValidRoute {
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(activityColor.opacity(0.15))
                                        .frame(width: 38, height: 38)
                                    Image(systemName: activityIcon)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(activityColor)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(activity.name ?? "Activity")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    Text(activity.type ?? "")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
                                }
                            }
                        } else {
                            HStack(spacing: 6) {
                                Image(systemName: activityIcon)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(activityColor)
                                Text((activity.type ?? "Run").capitalized)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
                            }
                        }

                        Spacer()

                        if let date = activity.start_date {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(date, format: .dateTime.month(.abbreviated).day())
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(AppTheme.Colors.DarkMode.textSecondary)
                                Text(timeAgoString(from: date))
                                    .font(.system(size: 11))
                                    .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
                            }
                        }
                    }

                    // ── HERO METRIC ────────────────────────────────────────
                    if let distance = activity.distance, AppConstants.Conversion.metersToMiles * distance >= 0.1 {
                        let miles = distance * AppConstants.Conversion.metersToMiles
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(String(format: miles >= 10 ? "%.1f" : "%.2f", miles))
                                .font(.system(size: 38, weight: .bold, design: .rounded))
                                .foregroundColor(activityColor)
                                .monospacedDigit()
                            Text(UnitFormatter.distanceUnitAbbreviation)
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(AppTheme.Colors.DarkMode.textSecondary)
                                .padding(.bottom, 4)
                        }
                    }

                    // ── SUPPORTING STATS ───────────────────────────────────
                    HStack(spacing: 0) {
                        if let time = activity.elapsed_time {
                            miniStat(value: formatElapsed(seconds: time), label: "time", icon: "clock")
                        }
                        if let distance = activity.distance, let time = activity.elapsed_time, distance >= 80 {
                            Spacer()
                            miniStat(
                                value: calcPace(distance: distance, time: time),
                                label: UnitFormatter.paceUnitLabel,
                                icon: "gauge.medium"
                            )
                        }
                        if let qi = quickInsight() {
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: qi.icon)
                                    .font(.system(size: 11))
                                    .foregroundColor(qi.color)
                                Text(qi.label)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(qi.color)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .background(AppTheme.Colors.DarkMode.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(isPressed ? 0.12 : 0.07), lineWidth: 1)
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeOut(duration: 0.12), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { isPressed = $0 }, perform: {})
    }

    private func miniStat(value: String, label: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.Colors.DarkMode.textPrimary)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
        }
    }

    private struct QuickInsightData { let label: String; let icon: String; let color: Color }
    private func quickInsight() -> QuickInsightData? {
        guard let cd = activity.distance, let ct = activity.elapsed_time, cd > 0,
              previousActivities.count >= 3 else { return nil }
        let cp = (ct / 60) / (cd * 0.000621371)
        let similar = previousActivities.filter {
            let pt = ($0.type ?? "").lowercased().replacingOccurrences(of: " ", with: "")
            let at = (activity.type ?? "").lowercased().replacingOccurrences(of: " ", with: "")
            return pt == at && ($0.distance ?? 0) > 0 && ($0.elapsed_time ?? 0) > 0
        }
        guard similar.count >= 3 else { return nil }
        let ap = similar.reduce(0.0) { s, a in
            guard let d = a.distance, let t = a.elapsed_time, d > 0 else { return s }
            return s + (t / 60) / (d * 0.000621371)
        } / Double(similar.count)
        let pct = ((ap - cp) / ap) * 100
        if pct >= 5 { return QuickInsightData(label: "\(Int(pct))% faster", icon: "arrow.up.right", color: AppTheme.Colors.success) }
        if pct <= -5 { return QuickInsightData(label: "\(Int(abs(pct)))% slower", icon: "arrow.down.right", color: AppTheme.Colors.DarkMode.textTertiary) }
        return nil
    }

    private func calcPace(distance: Double, time: Double) -> String {
        guard distance > 0, time > 0 else { return "--:--" }
        return UnitFormatter.formatPaceTime(minutesPerMile: (time / 60) / (distance * 0.000621371))
    }

    private func formatElapsed(seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600; let m = (Int(seconds) % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    private func timeAgoString(from date: Date) -> String {
        let i = Date().timeIntervalSince(date)
        if i < 3600 { return "\(Int(i / 60))m ago" }
        if i < 86400 { return "\(Int(i / 3600))h ago" }
        if i < 2592000 { return "\(Int(i / 86400))d ago" }
        let f = DateFormatter(); f.dateStyle = .medium; return f.string(from: date)
    }
}

// MARK: - Legacy compat
struct ActivityInsight { let messages: [String] }
struct AIInsightsBanner: View {
    let insights: ActivityInsight
    var body: some View { EmptyView() }
}

// MARK: - ActivityMapView

struct ActivityMapView: UIViewRepresentable {
    let summaryPolyline: String?

    func makeUIView(context: Context) -> MKMapView {
        let mv = MKMapView(frame: .zero)
        mv.overrideUserInterfaceStyle = .dark
        mv.isUserInteractionEnabled = false
        mv.isZoomEnabled = false
        mv.isScrollEnabled = false
        mv.isRotateEnabled = false
        mv.isPitchEnabled = false
        mv.delegate = context.coordinator
        return mv
    }

    func updateUIView(_ mv: MKMapView, context: Context) { addRouteToMap(mv) }
    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            let renderer = MKPolylineRenderer(overlay: overlay)
            renderer.strokeColor = UIColor(AppTheme.Colors.warmAmber)
            renderer.lineWidth = 3.5
            renderer.lineCap = .round
            renderer.lineJoin = .round
            return renderer
        }
    }

    private func addRouteToMap(_ mv: MKMapView) {
        guard let poly = summaryPolyline else { return }
        let coords = decodePolyline(poly)
        guard !coords.isEmpty else { return }
        mv.removeOverlays(mv.overlays)
        var mutableCoords = coords
        mv.addOverlay(MKPolyline(coordinates: &mutableCoords, count: mutableCoords.count), level: .aboveRoads)
        let lats = coords.map(\.latitude), lons = coords.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(latitudeDelta: (maxLat - minLat) * 1.5, longitudeDelta: (maxLon - minLon) * 1.5)
        mv.setRegion(MKCoordinateRegion(center: center, span: span), animated: false)
    }

    private func decodePolyline(_ encoded: String) -> [CLLocationCoordinate2D] {
        var s = encoded
        for (a, b) in [("\\\\\\\\", "\\\\"), ("\\\\\\", "\\"), ("\\\\", "\\"), ("\\\"", "\""), ("\\/", "/")] {
            s = s.replacingOccurrences(of: a, with: b)
        }
        if s.hasPrefix("\"") && s.hasSuffix("\"") { s = String(s.dropFirst().dropLast()) }
        var result: [CLLocationCoordinate2D] = []; let chars = Array(s); var idx = 0, lat = 0, lng = 0
        while idx < chars.count {
            var shift = 0, res = 0, byte: Int
            repeat { if idx >= chars.count { break }; byte = Int(chars[idx].asciiValue ?? 0) - 63; res |= (byte & 0x1F) << shift; shift += 5; idx += 1 } while byte >= 0x20
            lat += (res & 1) != 0 ? ~(res >> 1) : (res >> 1); shift = 0; res = 0
            repeat { if idx >= chars.count { break }; byte = Int(chars[idx].asciiValue ?? 0) - 63; res |= (byte & 0x1F) << shift; shift += 5; idx += 1 } while byte >= 0x20
            lng += (res & 1) != 0 ? ~(res >> 1) : (res >> 1)
            result.append(CLLocationCoordinate2D(latitude: Double(lat) / 1e5, longitude: Double(lng) / 1e5))
        }
        return result
    }
}

// MARK: - Compat stubs
struct RoutePoint: Identifiable { let id = UUID(); let coordinate: CLLocationCoordinate2D }
struct SnapshotView: View { var snapshot: UIImage?; var body: some View { EmptyView() } }
struct MapPolyline: Shape { let coordinates: [CLLocationCoordinate2D]; func path(in rect: CGRect) -> Path { Path() } }

private func formatTime(seconds: TimeInterval) -> String {
    let h = Int(seconds) / 3600; let m = (Int(seconds) % 3600) / 60
    return h > 0 ? "\(h)h \(m)m" : "\(m)m"
}

fileprivate struct ModifierCornerRadiusWithBorder: ViewModifier {
    var radius: CGFloat; var borderLineWidth: CGFloat = 1; var borderColor: Color = .gray; var antialiased: Bool = true
    func body(content: Content) -> some View {
        content.cornerRadius(radius, antialiased: antialiased)
            .overlay(RoundedRectangle(cornerRadius: radius).inset(by: borderLineWidth).strokeBorder(borderColor, lineWidth: borderLineWidth, antialiased: antialiased))
    }
}
extension View {
    func cornerRadiusWithBorder(radius: CGFloat, borderLineWidth: CGFloat = 1, borderColor: Color = .gray, antialiased: Bool = true) -> some View {
        modifier(ModifierCornerRadiusWithBorder(radius: radius, borderLineWidth: borderLineWidth, borderColor: borderColor, antialiased: antialiased))
    }
}
