//
//  HeatMapService.swift
//  Runaway iOS
//
//  Service for aggregating and analyzing route data for heat map visualization
//  Creates geographic heatmaps showing frequency of routes in different areas
//

import Foundation
import CoreLocation
import MapKit
import SwiftUI

// MARK: - Heat Map Models

/// Represents a geographic cell in the heat map grid
struct HeatMapCell: Identifiable, Codable {
    let id: String  // Grid coordinate (e.g., "lat123.45_lon-67.89")
    let coordinate: CLLocationCoordinate2D
    var intensity: Int  // Number of route points in this cell
    var activities: Set<Int>  // Unique activity IDs that passed through this cell

    enum CodingKeys: String, CodingKey {
        case id, latitude, longitude, intensity, activities
    }

    init(coordinate: CLLocationCoordinate2D, intensity: Int = 0, activityId: Int? = nil) {
        self.coordinate = coordinate
        self.intensity = intensity
        self.activities = activityId != nil ? [activityId!] : []

        // Create unique ID from rounded coordinates
        self.id = "lat\(String(format: "%.3f", coordinate.latitude))_lon\(String(format: "%.3f", coordinate.longitude))"
    }

    // Custom Codable implementation for CLLocationCoordinate2D
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        intensity = try container.decode(Int.self, forKey: .intensity)
        let activityArray = try container.decode([Int].self, forKey: .activities)
        activities = Set(activityArray)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
        try container.encode(intensity, forKey: .intensity)
        try container.encode(Array(activities), forKey: .activities)
    }
}

/// Heat map data for a specific region or time period
struct HeatMapData {
    let cells: [HeatMapCell]
    let bounds: MKCoordinateRegion
    let totalActivities: Int
    let dateRange: DateInterval?
    let generatedAt: Date

    var maxIntensity: Int {
        cells.map(\.intensity).max() ?? 0
    }

    var minIntensity: Int {
        cells.map(\.intensity).min() ?? 0
    }
}

/// Configuration for heat map generation
struct HeatMapConfig {
    /// Grid cell size in degrees (smaller = more detailed)
    let gridSize: Double

    /// Minimum number of points to include a cell
    let minimumIntensity: Int

    /// Date range filter (nil = all time)
    let dateRange: DateInterval?

    /// Activity type filter (nil = all types)
    let activityTypes: [String]?

    static let `default` = HeatMapConfig(
        gridSize: 0.001,  // ~111 meters at equator
        minimumIntensity: 1,
        dateRange: nil,
        activityTypes: nil
    )

    static let detailed = HeatMapConfig(
        gridSize: 0.0005,  // ~55 meters at equator
        minimumIntensity: 1,
        dateRange: nil,
        activityTypes: nil
    )

    static let coarse = HeatMapConfig(
        gridSize: 0.005,  // ~555 meters at equator
        minimumIntensity: 2,
        dateRange: nil,
        activityTypes: nil
    )
}

// MARK: - Heat Map Service

class HeatMapService {
    // MARK: - Properties

    private let polylineService = PolylineEncodingService()
    private var cachedHeatMapData: HeatMapData?
    private var lastGenerationDate: Date?

    // Cache duration (regenerate after 1 hour)
    private let cacheDuration: TimeInterval = 3600

    // MARK: - Public Methods

    /// Generate heat map data from activities
    func generateHeatMap(
        from activities: [Activity],
        config: HeatMapConfig = .default
    ) async -> HeatMapData {
        #if DEBUG
        print("🔥 HeatMapService: Generating heat map from \(activities.count) activities")
        print("   Grid size: \(config.gridSize) degrees")
        print("   Minimum intensity: \(config.minimumIntensity)")
        #endif

        // Check cache
        if let cached = cachedHeatMapData,
           let lastGen = lastGenerationDate,
           Date().timeIntervalSince(lastGen) < cacheDuration {
            #if DEBUG
            print("   ✅ Using cached heat map data")
            #endif
            return cached
        }

        // Filter activities
        let filteredActivities = filterActivities(activities, config: config)

        #if DEBUG
        print("   Filtered to \(filteredActivities.count) activities matching criteria")
        #endif

        // Build grid dictionary for fast lookups
        var gridCells: [String: HeatMapCell] = [:]

        // Process each activity
        for activity in filteredActivities {
            guard let polyline = activity.summary_polyline ?? activity.map_summary_polyline,
                  !polyline.isEmpty else {
                continue
            }

            // Decode polyline
            let coordinates = polylineService.decode(polyline: polyline)

            // Add each coordinate to grid
            for coordinate in coordinates {
                let gridKey = getGridKey(for: coordinate, gridSize: config.gridSize)

                if var cell = gridCells[gridKey] {
                    // Update existing cell
                    cell.intensity += 1
                    cell.activities.insert(activity.id)
                    gridCells[gridKey] = cell
                } else {
                    // Create new cell
                    let roundedCoord = roundToGrid(coordinate: coordinate, gridSize: config.gridSize)
                    let cell = HeatMapCell(
                        coordinate: roundedCoord,
                        intensity: 1,
                        activityId: activity.id
                    )
                    gridCells[gridKey] = cell
                }
            }
        }

        // Filter cells by minimum intensity
        let filteredCells = gridCells.values.filter { $0.intensity >= config.minimumIntensity }

        // Calculate bounds
        let bounds = calculateBounds(from: Array(filteredCells))

        // Create heat map data
        let heatMapData = HeatMapData(
            cells: Array(filteredCells).sorted { $0.intensity > $1.intensity },
            bounds: bounds,
            totalActivities: filteredActivities.count,
            dateRange: config.dateRange,
            generatedAt: Date()
        )

        // Cache result
        cachedHeatMapData = heatMapData
        lastGenerationDate = Date()

        #if DEBUG
        print("   ✅ Generated \(heatMapData.cells.count) heat map cells")
        print("   Max intensity: \(heatMapData.maxIntensity)")
        print("   Total activities: \(heatMapData.totalActivities)")
        #endif

        return heatMapData
    }

    /// Generate heat map for a specific time period
    func generateMonthlyHeatMap(
        from activities: [Activity],
        month: Int,
        year: Int
    ) async -> HeatMapData {
        let calendar = Calendar.current
        let components = DateComponents(year: year, month: month, day: 1)

        guard let startDate = calendar.date(from: components),
              let endDate = calendar.date(byAdding: .month, value: 1, to: startDate) else {
            // Return empty heat map
            return HeatMapData(
                cells: [],
                bounds: MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ),
                totalActivities: 0,
                dateRange: nil,
                generatedAt: Date()
            )
        }

        let dateRange = DateInterval(start: startDate, end: endDate)
        let config = HeatMapConfig(
            gridSize: HeatMapConfig.default.gridSize,
            minimumIntensity: HeatMapConfig.default.minimumIntensity,
            dateRange: dateRange,
            activityTypes: nil
        )

        return await generateHeatMap(from: activities, config: config)
    }

    /// Compare two time periods
    func compareHeatMaps(
        from activities: [Activity],
        period1: DateInterval,
        period2: DateInterval
    ) async -> (period1: HeatMapData, period2: HeatMapData) {
        let config1 = HeatMapConfig(
            gridSize: HeatMapConfig.default.gridSize,
            minimumIntensity: HeatMapConfig.default.minimumIntensity,
            dateRange: period1,
            activityTypes: nil
        )

        let config2 = HeatMapConfig(
            gridSize: HeatMapConfig.default.gridSize,
            minimumIntensity: HeatMapConfig.default.minimumIntensity,
            dateRange: period2,
            activityTypes: nil
        )

        async let heatMap1 = generateHeatMap(from: activities, config: config1)
        async let heatMap2 = generateHeatMap(from: activities, config: config2)

        return await (heatMap1, heatMap2)
    }

    /// Clear cached data
    func clearCache() {
        cachedHeatMapData = nil
        lastGenerationDate = nil

        #if DEBUG
        print("🔥 HeatMapService: Cache cleared")
        #endif
    }

    // MARK: - Private Methods

    private func filterActivities(_ activities: [Activity], config: HeatMapConfig) -> [Activity] {
        var filtered = activities

        // Filter by date range
        if let dateRange = config.dateRange {
            filtered = filtered.filter { activity in
                guard let activityDate = activity.activity_date ?? activity.start_date else {
                    return false
                }
                let date = Date(timeIntervalSince1970: activityDate)
                return dateRange.contains(date)
            }
        }

        // Filter by activity type
        if let types = config.activityTypes {
            filtered = filtered.filter { activity in
                guard let type = activity.type else { return false }
                return types.contains(type.lowercased())
            }
        }

        return filtered
    }

    private func getGridKey(for coordinate: CLLocationCoordinate2D, gridSize: Double) -> String {
        let roundedLat = (coordinate.latitude / gridSize).rounded() * gridSize
        let roundedLon = (coordinate.longitude / gridSize).rounded() * gridSize
        return "lat\(String(format: "%.5f", roundedLat))_lon\(String(format: "%.5f", roundedLon))"
    }

    private func roundToGrid(coordinate: CLLocationCoordinate2D, gridSize: Double) -> CLLocationCoordinate2D {
        let roundedLat = (coordinate.latitude / gridSize).rounded() * gridSize
        let roundedLon = (coordinate.longitude / gridSize).rounded() * gridSize
        return CLLocationCoordinate2D(latitude: roundedLat, longitude: roundedLon)
    }

    private func calculateBounds(from cells: [HeatMapCell]) -> MKCoordinateRegion {
        guard !cells.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }

        let coordinates = cells.map(\.coordinate)

        let minLat = coordinates.map(\.latitude).min() ?? 0
        let maxLat = coordinates.map(\.latitude).max() ?? 0
        let minLon = coordinates.map(\.longitude).min() ?? 0
        let maxLon = coordinates.map(\.longitude).max() ?? 0

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.3,  // 30% padding
            longitudeDelta: (maxLon - minLon) * 1.3
        )

        return MKCoordinateRegion(center: center, span: span)
    }
}

// MARK: - Heat Map Color Utilities

extension HeatMapService {
    /// Get color for intensity value (0.0 - 1.0)
    static func color(for normalizedIntensity: Double) -> Color {
        // Blue (low) → Green → Yellow → Orange → Red (high)
        switch normalizedIntensity {
        case 0.0..<0.2:
            return Color(red: 0.2, green: 0.4, blue: 1.0)  // Blue
        case 0.2..<0.4:
            return Color(red: 0.2, green: 0.8, blue: 0.6)  // Cyan/Green
        case 0.4..<0.6:
            return Color(red: 0.4, green: 1.0, blue: 0.2)  // Green
        case 0.6..<0.8:
            return Color(red: 1.0, green: 0.8, blue: 0.0)  // Yellow
        case 0.8..<0.9:
            return Color(red: 1.0, green: 0.5, blue: 0.0)  // Orange
        default:
            return Color(red: 1.0, green: 0.0, blue: 0.0)  // Red
        }
    }

    /// Get opacity for intensity (more intense = more opaque)
    static func opacity(for normalizedIntensity: Double) -> Double {
        return 0.3 + (normalizedIntensity * 0.7)  // Range: 0.3 to 1.0
    }
}
