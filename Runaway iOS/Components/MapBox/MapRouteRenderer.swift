//
//  MapRouteRenderer.swift
//  Runaway iOS
//
//  MapKit route renderer with pace gradient support
//

import MapKit
import CoreLocation

// MARK: - Route Data Models

/// Represents a route segment with pace information
struct RouteSegment {
    let start: CLLocationCoordinate2D
    let end: CLLocationCoordinate2D
    let pace: Double?   // minutes per mile (nil = unknown)
    let distance: Double // meters
}

/// Route styling configuration
struct RouteStyle {
    let lineWidth: CGFloat
    let opacity: CGFloat
    let usePaceGradient: Bool

    static let `default` = RouteStyle(lineWidth: 5, opacity: 1, usePaceGradient: false)
    static let recording  = RouteStyle(lineWidth: 6, opacity: 1, usePaceGradient: false)
    static let detail     = RouteStyle(lineWidth: 5, opacity: 1, usePaceGradient: true)
}

/// Pace color mapping
struct PaceColorMap {
    static let veryFast: Double = 6.0
    static let fast: Double     = 7.0
    static let moderate: Double = 8.0
    static let easy: Double     = 9.0
    static let slow: Double     = 10.0

    static func color(forPace pace: Double) -> UIColor {
        switch pace {
        case ..<veryFast:  return UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1)
        case veryFast..<fast:     return UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1)
        case fast..<moderate:     return UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1)
        case moderate..<easy:     return UIColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 1)
        case easy..<slow:         return UIColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1)
        default:                  return UIColor(red: 0.6, green: 0.2, blue: 1.0, alpha: 1)
        }
    }
}

// MARK: - Pace-colored polyline overlay

/// MKPolyline subclass that carries a color for pace-gradient rendering
final class PacePolyline: MKPolyline {
    var color: UIColor = .systemBlue
}

// MARK: - MapKit Route Renderer

class MapRouteRenderer {

    // MARK: Public

    /// Add a single-color route from an encoded polyline string
    func addRoute(
        to mapView: MKMapView,
        polyline: String,
        color: UIColor = .systemBlue,
        style: RouteStyle = .default,
        showMarkers: Bool = false
    ) {
        let coords = decodePolyline(polyline)
        guard !coords.isEmpty else { return }

        removeRoute(from: mapView)

        var mutableCoords = coords
        let overlay = PacePolyline(coordinates: &mutableCoords, count: mutableCoords.count)
        overlay.color = color
        mapView.addOverlay(overlay, level: .aboveRoads)

        if showMarkers, coords.count >= 2 {
            addStartEndMarkers(to: mapView, coordinates: coords)
        }

        fitCamera(to: mapView, coordinates: coords, animated: true)
    }

    /// Add a pace-gradient route from segments
    func addRouteWithPaceGradient(
        to mapView: MKMapView,
        segments: [RouteSegment],
        showMarkers: Bool = true
    ) {
        guard !segments.isEmpty else { return }
        removeRoute(from: mapView)

        var allCoords: [CLLocationCoordinate2D] = []
        for segment in segments {
            var pair = [segment.start, segment.end]
            let overlay = PacePolyline(coordinates: &pair, count: 2)
            overlay.color = segment.pace.map { PaceColorMap.color(forPace: $0) } ?? .systemBlue
            mapView.addOverlay(overlay, level: .aboveRoads)
            allCoords.append(contentsOf: pair)
        }

        if showMarkers {
            addStartEndMarkers(to: mapView, coordinates: allCoords)
        }
    }

    /// Remove all route overlays and annotations added by this renderer
    func removeRoute(from mapView: MKMapView) {
        let routeOverlays = mapView.overlays.filter { $0 is PacePolyline || $0 is MKCircle }
        mapView.removeOverlays(routeOverlays)
        let routeAnnotations = mapView.annotations.filter { $0 is MKPointAnnotation }
        mapView.removeAnnotations(routeAnnotations)
    }

    /// Fit the camera to a set of coordinates
    func fitCamera(
        to mapView: MKMapView,
        coordinates: [CLLocationCoordinate2D],
        padding: UIEdgeInsets = UIEdgeInsets(top: 60, left: 30, bottom: 60, right: 30),
        animated: Bool = true
    ) {
        guard !coordinates.isEmpty else { return }

        let lats = coordinates.map(\.latitude)
        let lons = coordinates.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.4,
            longitudeDelta: (maxLon - minLon) * 1.4
        )
        mapView.setRegion(MKCoordinateRegion(center: center, span: span), animated: animated)
    }

    // MARK: Private

    private func addStartEndMarkers(to mapView: MKMapView, coordinates: [CLLocationCoordinate2D]) {
        guard let start = coordinates.first, let end = coordinates.last else { return }
        let startCircle = MKCircle(center: start, radius: 12)
        let endCircle   = MKCircle(center: end,   radius: 12)
        mapView.addOverlay(startCircle, level: .aboveRoads)
        mapView.addOverlay(endCircle, level: .aboveRoads)
    }
}

// MARK: - MKMapViewDelegate helper for rendering

extension MapRouteRenderer {
    /// Call from `mapView(_:rendererFor:)` in your coordinator
    static func renderer(for overlay: MKOverlay, style: RouteStyle = .default) -> MKOverlayRenderer {
        if let pacePolyline = overlay as? PacePolyline {
            let renderer = MKPolylineRenderer(polyline: pacePolyline)
            renderer.strokeColor = pacePolyline.color.withAlphaComponent(style.opacity)
            renderer.lineWidth = style.lineWidth
            renderer.lineCap = .round
            renderer.lineJoin = .round
            return renderer
        }
        return MKOverlayRenderer(overlay: overlay)
    }
}

// MARK: - Pace calculation utilities

extension MapRouteRenderer {
    static func calculatePace(distanceMeters: Double, timeSeconds: Double) -> Double? {
        guard distanceMeters > 0, timeSeconds > 0 else { return nil }
        let miles = distanceMeters * 0.000621371
        return (timeSeconds / 60) / miles
    }

    static func createSegments(from points: [(coordinate: CLLocationCoordinate2D, timestamp: Date)]) -> [RouteSegment] {
        guard points.count >= 2 else { return [] }
        return (0..<points.count - 1).map { i in
            let a = points[i]; let b = points[i + 1]
            let dist = CLLocation(latitude: a.coordinate.latitude, longitude: a.coordinate.longitude)
                .distance(from: CLLocation(latitude: b.coordinate.latitude, longitude: b.coordinate.longitude))
            let pace = calculatePace(distanceMeters: dist, timeSeconds: b.timestamp.timeIntervalSince(a.timestamp))
            return RouteSegment(start: a.coordinate, end: b.coordinate, pace: pace, distance: dist)
        }
    }
}

// MARK: - Inline polyline decoder

private func decodePolyline(_ encoded: String) -> [CLLocationCoordinate2D] {
    var result: [CLLocationCoordinate2D] = []
    let chars = Array(encoded); var idx = 0, lat = 0, lng = 0
    while idx < chars.count {
        var shift = 0, res = 0, byte: Int
        repeat {
            if idx >= chars.count { break }
            byte = Int(chars[idx].asciiValue ?? 0) - 63
            res |= (byte & 0x1F) << shift; shift += 5; idx += 1
        } while byte >= 0x20
        lat += (res & 1) != 0 ? ~(res >> 1) : (res >> 1)
        shift = 0; res = 0
        repeat {
            if idx >= chars.count { break }
            byte = Int(chars[idx].asciiValue ?? 0) - 63
            res |= (byte & 0x1F) << shift; shift += 5; idx += 1
        } while byte >= 0x20
        lng += (res & 1) != 0 ? ~(res >> 1) : (res >> 1)
        result.append(CLLocationCoordinate2D(latitude: Double(lat) / 1e5, longitude: Double(lng) / 1e5))
    }
    return result
}
