//
//  PolylineEncodingService.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 6/29/25.
//

import Foundation
import CoreLocation
import MapKit

// MARK: - Polyline Encoding Service
class PolylineEncodingService {
    
    // MARK: - Public Methods
    
    /// Encode an array of coordinates into a polyline string
    func encode(coordinates: [CLLocationCoordinate2D]) -> String {
        guard !coordinates.isEmpty else { return "" }
        
        var encodedString = ""
        var previousLat = 0
        var previousLng = 0
        
        for coordinate in coordinates {
            let lat = Int(round(coordinate.latitude * 1e5))
            let lng = Int(round(coordinate.longitude * 1e5))
            
            let deltaLat = lat - previousLat
            let deltaLng = lng - previousLng
            
            encodedString += encodeValue(deltaLat)
            encodedString += encodeValue(deltaLng)
            
            previousLat = lat
            previousLng = lng
        }
        
        return encodedString
    }
    
    /// Decode a polyline string into an array of coordinates
    func decode(polyline: String) -> [CLLocationCoordinate2D] {
        guard !polyline.isEmpty else { return [] }
        
        var coordinates: [CLLocationCoordinate2D] = []
        var index = polyline.startIndex
        var lat = 0
        var lng = 0
        
        while index < polyline.endIndex {
            // Decode latitude
            let (deltaLat, newIndex) = decodeValue(from: polyline, startIndex: index)
            lat += deltaLat
            index = newIndex
            
            guard index < polyline.endIndex else { break }
            
            // Decode longitude
            let (deltaLng, finalIndex) = decodeValue(from: polyline, startIndex: index)
            lng += deltaLng
            index = finalIndex
            
            let coordinate = CLLocationCoordinate2D(
                latitude: Double(lat) / 1e5,
                longitude: Double(lng) / 1e5
            )
            coordinates.append(coordinate)
        }
        
        return coordinates
    }
    
    /// Create a simplified version of the route for better performance
    func simplify(coordinates: [CLLocationCoordinate2D], tolerance: Double = 0.0001) -> [CLLocationCoordinate2D] {
        guard coordinates.count > 2 else { return coordinates }
        
        // Use Douglas-Peucker algorithm for simplification
        return douglasPeucker(coordinates: coordinates, tolerance: tolerance)
    }
    
    /// Encode route points with metadata (timestamps, speed, etc.)
    func encodeRoutePoints(_ routePoints: [GPSRoutePoint]) -> String {
        let coordinates = routePoints.map { $0.coordinate }
        return encode(coordinates: coordinates)
    }
    
    /// Calculate the distance of a polyline route
    func calculateDistance(coordinates: [CLLocationCoordinate2D]) -> Double {
        guard coordinates.count > 1 else { return 0.0 }
        
        var totalDistance: Double = 0.0
        
        for i in 0..<(coordinates.count - 1) {
            let location1 = CLLocation(latitude: coordinates[i].latitude, longitude: coordinates[i].longitude)
            let location2 = CLLocation(latitude: coordinates[i + 1].latitude, longitude: coordinates[i + 1].longitude)
            totalDistance += location1.distance(from: location2)
        }
        
        return totalDistance
    }
    
    /// Get the bounds of a polyline for map region calculation
    func getBounds(coordinates: [CLLocationCoordinate2D]) -> (center: CLLocationCoordinate2D, span: MKCoordinateSpan)? {
        guard !coordinates.isEmpty else { return nil }
        
        let latitudes = coordinates.map { $0.latitude }
        let longitudes = coordinates.map { $0.longitude }
        
        guard let minLat = latitudes.min(),
              let maxLat = latitudes.max(),
              let minLng = longitudes.min(),
              let maxLng = longitudes.max() else {
            return nil
        }
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.3, // Add 30% padding
            longitudeDelta: (maxLng - minLng) * 1.3
        )
        
        return (center: center, span: span)
    }
    
    // MARK: - Private Methods
    
    private func encodeValue(_ value: Int) -> String {
        var val = value < 0 ? ~(value << 1) : (value << 1)
        var encoded = ""
        
        while val >= 0x20 {
            encoded += String(Character(UnicodeScalar((0x20 | (val & 0x1f)) + 63)!))
            val >>= 5
        }
        
        encoded += String(Character(UnicodeScalar(val + 63)!))
        return encoded
    }
    
    private func decodeValue(from string: String, startIndex: String.Index) -> (value: Int, nextIndex: String.Index) {
        var index = startIndex
        var shift = 0
        var result = 0
        
        while index < string.endIndex {
            let char = string[index]
            let byte = Int(char.asciiValue!) - 63
            
            result |= (byte & 0x1f) << shift
            shift += 5
            
            index = string.index(after: index)
            
            if byte < 0x20 {
                break
            }
        }
        
        let value = (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
        return (value: value, nextIndex: index)
    }
    
    // MARK: - Douglas-Peucker Simplification
    
    private func douglasPeucker(coordinates: [CLLocationCoordinate2D], tolerance: Double) -> [CLLocationCoordinate2D] {
        guard coordinates.count > 2 else { return coordinates }
        
        let firstPoint = coordinates.first!
        let lastPoint = coordinates.last!
        
        var maxDistance: Double = 0
        var maxIndex = 0
        
        // Find the point with maximum distance from the line
        for i in 1..<(coordinates.count - 1) {
            let distance = perpendicularDistance(
                point: coordinates[i],
                lineStart: firstPoint,
                lineEnd: lastPoint
            )
            
            if distance > maxDistance {
                maxDistance = distance
                maxIndex = i
            }
        }
        
        // If maximum distance is greater than tolerance, recursively simplify
        if maxDistance > tolerance {
            let leftResults = douglasPeucker(
                coordinates: Array(coordinates[0...maxIndex]),
                tolerance: tolerance
            )
            let rightResults = douglasPeucker(
                coordinates: Array(coordinates[maxIndex..<coordinates.count]),
                tolerance: tolerance
            )
            
            // Combine results (remove duplicate point at maxIndex)
            return leftResults + Array(rightResults.dropFirst())
        } else {
            // All points between first and last can be discarded
            return [firstPoint, lastPoint]
        }
    }
    
    private func perpendicularDistance(
        point: CLLocationCoordinate2D,
        lineStart: CLLocationCoordinate2D,
        lineEnd: CLLocationCoordinate2D
    ) -> Double {
        let A = point.latitude - lineStart.latitude
        let B = point.longitude - lineStart.longitude
        let C = lineEnd.latitude - lineStart.latitude
        let D = lineEnd.longitude - lineStart.longitude
        
        let dot = A * C + B * D
        let lenSquared = C * C + D * D
        
        if lenSquared == 0 {
            // Line start and end are the same point
            return sqrt(A * A + B * B)
        }
        
        let param = dot / lenSquared
        
        let xx: Double
        let yy: Double
        
        if param < 0 {
            xx = lineStart.latitude
            yy = lineStart.longitude
        } else if param > 1 {
            xx = lineEnd.latitude
            yy = lineEnd.longitude
        } else {
            xx = lineStart.latitude + param * C
            yy = lineStart.longitude + param * D
        }
        
        let dx = point.latitude - xx
        let dy = point.longitude - yy
        
        return sqrt(dx * dx + dy * dy)
    }
}

// MARK: - Polyline Utilities
extension PolylineEncodingService {
    
    /// Create a preview polyline for display in lists (simplified version)
    func createPreviewPolyline(from coordinates: [CLLocationCoordinate2D], maxPoints: Int = 50) -> String {
        guard !coordinates.isEmpty else { return "" }
        
        let simplified: [CLLocationCoordinate2D]
        
        if coordinates.count > maxPoints {
            // Take evenly spaced points
            let step = coordinates.count / maxPoints
            simplified = stride(from: 0, to: coordinates.count, by: step).map { coordinates[$0] }
        } else {
            simplified = coordinates
        }
        
        return encode(coordinates: simplified)
    }
    
    /// Validate that a polyline string is properly formatted
    func isValidPolyline(_ polyline: String) -> Bool {
        guard !polyline.isEmpty else { return false }
        
        // Try to decode and see if we get valid coordinates
        let coordinates = decode(polyline: polyline)
        return !coordinates.isEmpty && coordinates.allSatisfy { coordinate in
            coordinate.latitude >= -90 && coordinate.latitude <= 90 &&
            coordinate.longitude >= -180 && coordinate.longitude <= 180
        }
    }
    
    /// Get statistics about a polyline
    func getPolylineStats(coordinates: [CLLocationCoordinate2D]) -> (distance: Double, bounds: MKMapRect, pointCount: Int) {
        let distance = calculateDistance(coordinates: coordinates)
        let pointCount = coordinates.count
        
        var bounds = MKMapRect.null
        for coordinate in coordinates {
            let point = MKMapPoint(coordinate)
            let rect = MKMapRect(x: point.x, y: point.y, width: 0, height: 0)
            bounds = bounds.union(rect)
        }
        
        return (distance: distance, bounds: bounds, pointCount: pointCount)
    }
}