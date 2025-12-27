//
//  MapBoxRouteRenderer.swift
//  Runaway iOS
//
//  MapBox route renderer with pace gradient support
//  Renders activity routes with color-coded pace visualization
//

import SwiftUI
import MapboxMaps
import CoreLocation

// MARK: - Route Data Models

/// Represents a route segment with pace information
struct RouteSegment {
    let start: CLLocationCoordinate2D
    let end: CLLocationCoordinate2D
    let pace: Double?  // minutes per mile (nil = unknown)
    let distance: Double  // meters
}

/// Route styling configuration
struct RouteStyle {
    let lineWidth: Double
    let opacity: Double
    let usePaceGradient: Bool

    static let `default` = RouteStyle(
        lineWidth: 5.0,
        opacity: 1.0,
        usePaceGradient: false
    )

    static let recording = RouteStyle(
        lineWidth: 6.0,
        opacity: 1.0,
        usePaceGradient: false
    )

    static let detail = RouteStyle(
        lineWidth: 5.0,
        opacity: 1.0,
        usePaceGradient: true
    )
}

/// Pace color mapping
struct PaceColorMap {
    // Pace thresholds (minutes per mile)
    static let veryFast: Double = 6.0      // < 6:00/mi - Red
    static let fast: Double = 7.0          // 6:00-7:00/mi - Orange
    static let moderate: Double = 8.0      // 7:00-8:00/mi - Yellow
    static let easy: Double = 9.0          // 8:00-9:00/mi - Green
    static let slow: Double = 10.0         // 9:00-10:00/mi - Blue
    // > 10:00/mi - Purple

    /// Get color for pace (minutes per mile)
    static func color(forPace pace: Double) -> UIColor {
        switch pace {
        case ..<veryFast:
            return UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)  // Red - Very Fast
        case veryFast..<fast:
            return UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0)  // Orange - Fast
        case fast..<moderate:
            return UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0)  // Yellow - Moderate
        case moderate..<easy:
            return UIColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 1.0)  // Green - Easy
        case easy..<slow:
            return UIColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1.0)  // Blue - Slow
        default:
            return UIColor(red: 0.6, green: 0.2, blue: 1.0, alpha: 1.0)  // Purple - Very Slow
        }
    }

    /// Get SwiftUI Color for pace
    static func swiftUIColor(forPace pace: Double) -> Color {
        Color(color(forPace: pace))
    }
}

// MARK: - MapBox Route Renderer

/// Renders routes on MapBox map with optional pace gradient
class MapBoxRouteRenderer {
    private let polylineService = PolylineEncodingService()

    // Source and layer IDs
    private let routeSourceId = "route-source"
    private let routeLayerId = "route-layer"
    private let startMarkerSourceId = "start-marker-source"
    private let endMarkerSourceId = "end-marker-source"
    private let startMarkerLayerId = "start-marker-layer"
    private let endMarkerLayerId = "end-marker-layer"

    // MARK: - Public Methods

    /// Add route to map from encoded polyline
    func addRoute(
        to mapView: MapboxMaps.MapView,
        polyline: String,
        style: RouteStyle = .default,
        showMarkers: Bool = false
    ) {
        // Decode polyline
        let coordinates = polylineService.decode(polyline: polyline)

        guard !coordinates.isEmpty else {
            #if DEBUG
            print("⚠️ MapBoxRouteRenderer: Empty coordinates, skipping route")
            #endif
            return
        }

        // Add route line
        addRouteLine(to: mapView, coordinates: coordinates, style: style)

        // Add start/end markers if requested
        if showMarkers && coordinates.count >= 2 {
            addStartEndMarkers(to: mapView, coordinates: coordinates)
        }

        #if DEBUG
        print("✅ MapBoxRouteRenderer: Route added with \(coordinates.count) points")
        #endif
    }

    /// Add route with pace gradient from route segments
    func addRouteWithPaceGradient(
        to mapView: MapboxMaps.MapView,
        segments: [RouteSegment],
        style: RouteStyle = .detail,
        showMarkers: Bool = true
    ) {
        guard !segments.isEmpty else {
            #if DEBUG
            print("⚠️ MapBoxRouteRenderer: Empty segments, skipping route")
            #endif
            return
        }

        // For pace gradient, we need to add multiple line layers with different colors
        // This is more complex and requires GeoJSON features

        // Create all coordinates for bounds calculation
        var allCoordinates: [CLLocationCoordinate2D] = []
        segments.forEach { segment in
            allCoordinates.append(segment.start)
            allCoordinates.append(segment.end)
        }

        // Add each segment as a separate line with its pace color
        for (index, segment) in segments.enumerated() {
            let segmentCoordinates = [segment.start, segment.end]
            let color = segment.pace != nil ? PaceColorMap.color(forPace: segment.pace!) : UIColor.systemBlue

            addSegmentLine(
                to: mapView,
                coordinates: segmentCoordinates,
                color: color,
                style: style,
                segmentIndex: index
            )
        }

        // Add start/end markers
        if showMarkers {
            addStartEndMarkers(to: mapView, coordinates: allCoordinates)
        }

        #if DEBUG
        print("✅ MapBoxRouteRenderer: Pace gradient route added with \(segments.count) segments")
        #endif
    }

    /// Remove route from map
    func removeRoute(from mapView: MapboxMaps.MapView) {
        // Remove all route-related layers and sources
        removeLayerIfExists(mapView: mapView, layerId: routeLayerId)
        removeSourceIfExists(mapView: mapView, sourceId: routeSourceId)

        // Remove markers
        removeLayerIfExists(mapView: mapView, layerId: startMarkerLayerId)
        removeLayerIfExists(mapView: mapView, layerId: endMarkerLayerId)
        removeSourceIfExists(mapView: mapView, sourceId: startMarkerSourceId)
        removeSourceIfExists(mapView: mapView, sourceId: endMarkerSourceId)

        // Remove pace gradient segments (if any)
        for i in 0..<1000 {  // Max 1000 segments
            let segmentLayerId = "route-segment-\(i)"
            let segmentSourceId = "route-segment-source-\(i)"

            if !mapView.mapboxMap.layerExists(withId: segmentLayerId) {
                break  // No more segments
            }

            removeLayerIfExists(mapView: mapView, layerId: segmentLayerId)
            removeSourceIfExists(mapView: mapView, sourceId: segmentSourceId)
        }

        #if DEBUG
        print("🗑️ MapBoxRouteRenderer: Route removed from map")
        #endif
    }

    /// Fit map camera to route bounds
    func fitCameraToBounds(
        mapView: MapboxMaps.MapView,
        coordinates: [CLLocationCoordinate2D],
        padding: UIEdgeInsets = UIEdgeInsets(top: 100, left: 50, bottom: 100, right: 50),
        animated: Bool = true
    ) {
        guard !coordinates.isEmpty else { return }

        // Calculate bounds
        let latitudes = coordinates.map { $0.latitude }
        let longitudes = coordinates.map { $0.longitude }

        guard let minLat = latitudes.min(),
              let maxLat = latitudes.max(),
              let minLon = longitudes.min(),
              let maxLon = longitudes.max() else { return }

        // Calculate center and span
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let latDelta = (maxLat - minLat) * 1.3  // Add 30% padding
        let lonDelta = (maxLon - minLon) * 1.3

        // Calculate zoom level from span
        // Rough approximation: zoom decreases as span increases
        let maxDelta = max(latDelta, lonDelta)
        let zoom = max(1, 16 - log2(maxDelta / 0.01))

        let cameraOptions = CameraOptions(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            zoom: zoom
        )

        if animated {
            mapView.camera.ease(to: cameraOptions, duration: 1.0)
        } else {
            mapView.mapboxMap.setCamera(to: cameraOptions)
        }
    }

    // MARK: - Private Methods

    private func addRouteLine(
        to mapView: MapboxMaps.MapView,
        coordinates: [CLLocationCoordinate2D],
        style: RouteStyle
    ) {
        // Remove existing route
        removeLayerIfExists(mapView: mapView, layerId: routeLayerId)
        removeSourceIfExists(mapView: mapView, sourceId: routeSourceId)

        // Create GeoJSON line string
        var geoJSON: [String: Any] = [
            "type": "Feature",
            "geometry": [
                "type": "LineString",
                "coordinates": coordinates.map { [$0.longitude, $0.latitude] }
            ]
        ]

        // Add source
        var source = GeoJSONSource(id: routeSourceId)
        source.data = .feature(Feature(geometry: .lineString(LineString(coordinates))))

        do {
            try mapView.mapboxMap.addSource(source)
        } catch {
            #if DEBUG
            print("❌ MapBoxRouteRenderer: Failed to add route source: \(error)")
            #endif
            return
        }

        // Add layer
        var layer = LineLayer(id: routeLayerId, source: routeSourceId)
        layer.lineColor = .constant(StyleColor(UIColor.systemBlue))
        layer.lineWidth = .constant(style.lineWidth)
        layer.lineOpacity = .constant(style.opacity)
        layer.lineCap = .constant(.round)
        layer.lineJoin = .constant(.round)

        do {
            try mapView.mapboxMap.addLayer(layer)
        } catch {
            #if DEBUG
            print("❌ MapBoxRouteRenderer: Failed to add route layer: \(error)")
            #endif
        }
    }

    private func addSegmentLine(
        to mapView: MapboxMaps.MapView,
        coordinates: [CLLocationCoordinate2D],
        color: UIColor,
        style: RouteStyle,
        segmentIndex: Int
    ) {
        let sourceId = "route-segment-source-\(segmentIndex)"
        let layerId = "route-segment-\(segmentIndex)"

        // Remove if exists
        removeLayerIfExists(mapView: mapView, layerId: layerId)
        removeSourceIfExists(mapView: mapView, sourceId: sourceId)

        // Add source
        var source = GeoJSONSource(id: sourceId)
        source.data = .feature(Feature(geometry: .lineString(LineString(coordinates))))

        do {
            try mapView.mapboxMap.addSource(source)
        } catch {
            #if DEBUG
            print("❌ MapBoxRouteRenderer: Failed to add segment source: \(error)")
            #endif
            return
        }

        // Add layer
        var layer = LineLayer(id: layerId, source: sourceId)
        layer.lineColor = .constant(StyleColor(color))
        layer.lineWidth = .constant(style.lineWidth)
        layer.lineOpacity = .constant(style.opacity)
        layer.lineCap = .constant(.round)
        layer.lineJoin = .constant(.round)

        do {
            try mapView.mapboxMap.addLayer(layer)
        } catch {
            #if DEBUG
            print("❌ MapBoxRouteRenderer: Failed to add segment layer: \(error)")
            #endif
        }
    }

    private func addStartEndMarkers(
        to mapView: MapboxMaps.MapView,
        coordinates: [CLLocationCoordinate2D]
    ) {
        guard let start = coordinates.first, let end = coordinates.last else { return }

        // Remove existing markers
        removeLayerIfExists(mapView: mapView, layerId: startMarkerLayerId)
        removeLayerIfExists(mapView: mapView, layerId: endMarkerLayerId)
        removeSourceIfExists(mapView: mapView, sourceId: startMarkerSourceId)
        removeSourceIfExists(mapView: mapView, sourceId: endMarkerSourceId)

        // Add start marker (green circle)
        addMarker(to: mapView, coordinate: start, sourceId: startMarkerSourceId, layerId: startMarkerLayerId, color: .systemGreen)

        // Add end marker (red circle)
        addMarker(to: mapView, coordinate: end, sourceId: endMarkerSourceId, layerId: endMarkerLayerId, color: .systemRed)
    }

    private func addMarker(
        to mapView: MapboxMaps.MapView,
        coordinate: CLLocationCoordinate2D,
        sourceId: String,
        layerId: String,
        color: UIColor
    ) {
        // Add source
        var source = GeoJSONSource(id: sourceId)
        source.data = .feature(Feature(geometry: .point(Point(coordinate))))

        do {
            try mapView.mapboxMap.addSource(source)
        } catch {
            #if DEBUG
            print("❌ MapBoxRouteRenderer: Failed to add marker source: \(error)")
            #endif
            return
        }

        // Add layer (circle)
        var layer = CircleLayer(id: layerId, source: sourceId)
        layer.circleRadius = .constant(8.0)
        layer.circleColor = .constant(StyleColor(color))
        layer.circleStrokeWidth = .constant(2.0)
        layer.circleStrokeColor = .constant(StyleColor(.white))

        do {
            try mapView.mapboxMap.addLayer(layer)
        } catch {
            #if DEBUG
            print("❌ MapBoxRouteRenderer: Failed to add marker layer: \(error)")
            #endif
        }
    }

    private func removeLayerIfExists(mapView: MapboxMaps.MapView, layerId: String) {
        if mapView.mapboxMap.layerExists(withId: layerId) {
            try? mapView.mapboxMap.removeLayer(withId: layerId)
        }
    }

    private func removeSourceIfExists(mapView: MapboxMaps.MapView, sourceId: String) {
        if mapView.mapboxMap.sourceExists(withId: sourceId) {
            try? mapView.mapboxMap.removeSource(withId: sourceId)
        }
    }
}

// MARK: - Pace Calculation Utilities

extension MapBoxRouteRenderer {
    /// Calculate pace from distance and time
    static func calculatePace(distanceMeters: Double, timeSeconds: Double) -> Double? {
        guard distanceMeters > 0, timeSeconds > 0 else { return nil }

        let distanceMiles = distanceMeters * 0.000621371
        let timeMinutes = timeSeconds / 60.0

        return timeMinutes / distanceMiles  // minutes per mile
    }

    /// Create route segments from GPS points with timestamps
    static func createSegments(from points: [(coordinate: CLLocationCoordinate2D, timestamp: Date)]) -> [RouteSegment] {
        guard points.count >= 2 else { return [] }

        var segments: [RouteSegment] = []

        for i in 0..<(points.count - 1) {
            let start = points[i]
            let end = points[i + 1]

            // Calculate distance
            let startLocation = CLLocation(latitude: start.coordinate.latitude, longitude: start.coordinate.longitude)
            let endLocation = CLLocation(latitude: end.coordinate.latitude, longitude: end.coordinate.longitude)
            let distance = startLocation.distance(from: endLocation)

            // Calculate time difference
            let timeDiff = end.timestamp.timeIntervalSince(start.timestamp)

            // Calculate pace
            let pace = calculatePace(distanceMeters: distance, timeSeconds: timeDiff)

            let segment = RouteSegment(
                start: start.coordinate,
                end: end.coordinate,
                pace: pace,
                distance: distance
            )

            segments.append(segment)
        }

        return segments
    }
}
