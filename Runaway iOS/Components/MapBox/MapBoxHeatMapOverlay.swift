//
//  MapBoxHeatMapOverlay.swift
//  Runaway iOS
//
//  MapBox heat map overlay for lifetime activity visualization
//  Displays intensity-based heat map showing where you run most
//

import SwiftUI
import MapboxMaps
import CoreLocation

// MARK: - Heat Map Overlay

/// Renders heat map overlay on MapBox map
class MapBoxHeatMapOverlay {
    private let heatMapSourceId = "heatmap-source"
    private let heatMapLayerId = "heatmap-layer"
    private let heatMapCircleLayerId = "heatmap-circle-layer"

    // MARK: - Public Methods

    /// Add heat map to map from heat map data
    func addHeatMap(
        to mapView: MapboxMaps.MapView,
        heatMapData: HeatMapData,
        config: HeatMapVisualizationConfig = .default
    ) {
        // Remove existing heat map
        removeHeatMap(from: mapView)

        guard !heatMapData.cells.isEmpty else {
            #if DEBUG
            print("⚠️ MapBoxHeatMapOverlay: No heat map cells, skipping")
            #endif
            return
        }

        #if DEBUG
        print("🔥 MapBoxHeatMapOverlay: Adding heat map with \(heatMapData.cells.count) cells")
        print("   Max intensity: \(heatMapData.maxIntensity)")
        print("   Total activities: \(heatMapData.totalActivities)")
        #endif

        // Add heat map visualization based on config
        switch config.visualizationType {
        case .heatmap:
            addHeatMapLayer(to: mapView, cells: heatMapData.cells, maxIntensity: heatMapData.maxIntensity, config: config)
        case .circles:
            addCirclesLayer(to: mapView, cells: heatMapData.cells, maxIntensity: heatMapData.maxIntensity, config: config)
        case .both:
            addHeatMapLayer(to: mapView, cells: heatMapData.cells, maxIntensity: heatMapData.maxIntensity, config: config)
            addCirclesLayer(to: mapView, cells: heatMapData.cells, maxIntensity: heatMapData.maxIntensity, config: config)
        }

        #if DEBUG
        print("✅ MapBoxHeatMapOverlay: Heat map added successfully")
        #endif
    }

    /// Remove heat map from map
    func removeHeatMap(from mapView: MapboxMaps.MapView) {
        // Remove layers
        if mapView.mapboxMap.layerExists(withId: heatMapLayerId) {
            try? mapView.mapboxMap.removeLayer(withId: heatMapLayerId)
        }

        if mapView.mapboxMap.layerExists(withId: heatMapCircleLayerId) {
            try? mapView.mapboxMap.removeLayer(withId: heatMapCircleLayerId)
        }

        // Remove source
        if mapView.mapboxMap.sourceExists(withId: heatMapSourceId) {
            try? mapView.mapboxMap.removeSource(withId: heatMapSourceId)
        }

        #if DEBUG
        print("🗑️ MapBoxHeatMapOverlay: Heat map removed")
        #endif
    }

    /// Update heat map opacity
    func updateOpacity(_ opacity: Double, mapView: MapboxMaps.MapView) {
        // Update heatmap layer opacity
        if mapView.mapboxMap.layerExists(withId: heatMapLayerId) {
            try? mapView.mapboxMap.updateLayer(withId: heatMapLayerId, type: HeatmapLayer.self) { layer in
                layer.heatmapOpacity = .constant(opacity)
            }
        }

        // Update circle layer opacity
        if mapView.mapboxMap.layerExists(withId: heatMapCircleLayerId) {
            try? mapView.mapboxMap.updateLayer(withId: heatMapCircleLayerId, type: CircleLayer.self) { layer in
                layer.circleOpacity = .constant(opacity)
            }
        }
    }

    // MARK: - Private Methods

    private func addHeatMapLayer(
        to mapView: MapboxMaps.MapView,
        cells: [HeatMapCell],
        maxIntensity: Int,
        config: HeatMapVisualizationConfig
    ) {
        // Create GeoJSON features from cells
        var features: [Feature] = []

        for cell in cells {
            var feature = Feature(geometry: .point(Point(cell.coordinate)))

            // Add intensity as property (used for heatmap weight)
            feature.properties = [
                "intensity": .number(Double(cell.intensity))
            ]

            features.append(feature)
        }

        // Create feature collection
        let featureCollection = FeatureCollection(features: features)

        // Add source
        var source = GeoJSONSource(id: heatMapSourceId)
        source.data = .featureCollection(featureCollection)

        do {
            try mapView.mapboxMap.addSource(source)
        } catch {
            #if DEBUG
            print("❌ MapBoxHeatMapOverlay: Failed to add source: \(error)")
            #endif
            return
        }

        // Create heatmap layer
        var layer = HeatmapLayer(id: heatMapLayerId, source: heatMapSourceId)

        // Configure heatmap weight based on intensity
        layer.heatmapWeight = .expression(
            Exp(.interpolate) {
                Exp(.linear)
                Exp(.get) { "intensity" }
                0
                0
                Double(maxIntensity)
                1
            }
        )

        // Configure heatmap intensity (increases with zoom)
        layer.heatmapIntensity = .expression(
            Exp(.interpolate) {
                Exp(.linear)
                Exp(.zoom)
                0
                config.intensity * 0.5
                15
                config.intensity
            }
        )

        // Configure heatmap radius (decreases with zoom for detail)
        layer.heatmapRadius = .expression(
            Exp(.interpolate) {
                Exp(.linear)
                Exp(.zoom)
                0
                config.radius * 2
                15
                config.radius
            }
        )

        // Configure heatmap color gradient
        layer.heatmapColor = .expression(
            Exp(.interpolate) {
                Exp(.linear)
                Exp(.heatmapDensity)
                0
                UIColor.clear
                0.2
                UIColor(red: 0.2, green: 0.4, blue: 1.0, alpha: 1.0)  // Blue
                0.4
                UIColor(red: 0.2, green: 0.8, blue: 0.6, alpha: 1.0)  // Cyan
                0.6
                UIColor(red: 0.4, green: 1.0, blue: 0.2, alpha: 1.0)  // Green
                0.8
                UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0)  // Yellow
                0.9
                UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0)  // Orange
                1.0
                UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)  // Red
            }
        )

        // Set opacity
        layer.heatmapOpacity = .constant(config.opacity)

        do {
            try mapView.mapboxMap.addLayer(layer)
        } catch {
            #if DEBUG
            print("❌ MapBoxHeatMapOverlay: Failed to add heatmap layer: \(error)")
            #endif
        }
    }

    private func addCirclesLayer(
        to mapView: MapboxMaps.MapView,
        cells: [HeatMapCell],
        maxIntensity: Int,
        config: HeatMapVisualizationConfig
    ) {
        // Source should already exist from addHeatMapLayer
        // If not, we need to add it
        if !mapView.mapboxMap.sourceExists(withId: heatMapSourceId) {
            var features: [Feature] = []

            for cell in cells {
                var feature = Feature(geometry: .point(Point(cell.coordinate)))
                feature.properties = ["intensity": .number(Double(cell.intensity))]
                features.append(feature)
            }

            let featureCollection = FeatureCollection(features: features)
            var source = GeoJSONSource(id: heatMapSourceId)
            source.data = .featureCollection(featureCollection)

            do {
                try mapView.mapboxMap.addSource(source)
            } catch {
                #if DEBUG
                print("❌ MapBoxHeatMapOverlay: Failed to add circle source: \(error)")
                #endif
                return
            }
        }

        // Create circle layer
        var layer = CircleLayer(id: heatMapCircleLayerId, source: heatMapSourceId)

        // Configure circle radius based on intensity
        layer.circleRadius = .expression(
            Exp(.interpolate) {
                Exp(.linear)
                Exp(.get) { "intensity" }
                0
                config.circleRadiusMin
                Double(maxIntensity)
                config.circleRadiusMax
            }
        )

        // Configure circle color based on intensity
        layer.circleColor = .expression(
            Exp(.interpolate) {
                Exp(.linear)
                Exp(.get) { "intensity" }
                0
                UIColor(red: 0.2, green: 0.4, blue: 1.0, alpha: 1.0)  // Blue
                Double(maxIntensity) * 0.33
                UIColor(red: 0.4, green: 1.0, blue: 0.2, alpha: 1.0)  // Green
                Double(maxIntensity) * 0.66
                UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0)  // Yellow
                Double(maxIntensity)
                UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)  // Red
            }
        )

        // Set opacity
        layer.circleOpacity = .constant(config.opacity * 0.7)

        // Add stroke
        layer.circleStrokeWidth = .constant(1.0)
        layer.circleStrokeColor = .constant(StyleColor(.white))
        layer.circleStrokeOpacity = .constant(0.5)

        do {
            try mapView.mapboxMap.addLayer(layer)
        } catch {
            #if DEBUG
            print("❌ MapBoxHeatMapOverlay: Failed to add circle layer: \(error)")
            #endif
        }
    }
}

// MARK: - Heat Map Visualization Configuration

struct HeatMapVisualizationConfig {
    enum VisualizationType {
        case heatmap      // Smooth gradient heatmap
        case circles      // Discrete circles
        case both         // Both heatmap and circles
    }

    let visualizationType: VisualizationType
    let intensity: Double      // Heatmap intensity multiplier (0.0 - 2.0)
    let radius: Double         // Heatmap radius in pixels
    let opacity: Double        // Overall opacity (0.0 - 1.0)
    let circleRadiusMin: Double  // Minimum circle radius
    let circleRadiusMax: Double  // Maximum circle radius

    static let `default` = HeatMapVisualizationConfig(
        visualizationType: .heatmap,
        intensity: 1.0,
        radius: 20.0,
        opacity: 0.7,
        circleRadiusMin: 3.0,
        circleRadiusMax: 15.0
    )

    static let intense = HeatMapVisualizationConfig(
        visualizationType: .heatmap,
        intensity: 1.5,
        radius: 25.0,
        opacity: 0.8,
        circleRadiusMin: 4.0,
        circleRadiusMax: 20.0
    )

    static let circles = HeatMapVisualizationConfig(
        visualizationType: .circles,
        intensity: 1.0,
        radius: 15.0,
        opacity: 0.8,
        circleRadiusMin: 3.0,
        circleRadiusMax: 12.0
    )

    static let subtle = HeatMapVisualizationConfig(
        visualizationType: .heatmap,
        intensity: 0.7,
        radius: 15.0,
        opacity: 0.5,
        circleRadiusMin: 2.0,
        circleRadiusMax: 10.0
    )
}
