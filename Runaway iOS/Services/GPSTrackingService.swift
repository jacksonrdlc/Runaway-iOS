//
//  GPSTrackingService.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 6/29/25.
//

import Foundation
import CoreLocation
import MapKit
import Combine

// MARK: - GPS Route Point Model
public struct GPSRoutePoint: Codable, Identifiable {
    public let id = UUID()
    public let coordinate: CLLocationCoordinate2D
    public let timestamp: Date
    public let altitude: Double
    public let speed: Double // meters per second
    public let horizontalAccuracy: Double
    
    enum CodingKeys: String, CodingKey {
        case coordinate, timestamp, altitude, speed, horizontalAccuracy
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(["latitude": coordinate.latitude, "longitude": coordinate.longitude], forKey: .coordinate)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(altitude, forKey: .altitude)
        try container.encode(speed, forKey: .speed)
        try container.encode(horizontalAccuracy, forKey: .horizontalAccuracy)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let coordData = try container.decode([String: Double].self, forKey: .coordinate)
        coordinate = CLLocationCoordinate2D(
            latitude: coordData["latitude"] ?? 0,
            longitude: coordData["longitude"] ?? 0
        )
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        altitude = try container.decode(Double.self, forKey: .altitude)
        speed = try container.decode(Double.self, forKey: .speed)
        horizontalAccuracy = try container.decode(Double.self, forKey: .horizontalAccuracy)
    }
    
    public init(location: CLLocation) {
        self.coordinate = location.coordinate
        self.timestamp = location.timestamp
        self.altitude = location.altitude
        self.speed = max(0, location.speed) // Negative speed means invalid
        self.horizontalAccuracy = location.horizontalAccuracy
    }
}

// MARK: - GPS Tracking Service
@MainActor
class GPSTrackingService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isTracking = false
    @Published var currentLocation: CLLocation?
    @Published var routePoints: [GPSRoutePoint] = []
    @Published var totalDistance: Double = 0.0 // meters
    @Published var currentSpeed: Double = 0.0 // meters per second
    @Published var averageSpeed: Double = 0.0 // meters per second
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    // MARK: - Private Properties
    private let locationManager = CLLocationManager()
    private var lastLocation: CLLocation?
    private var startTime: Date?
    private let minimumDistance: Double = 5.0 // meters - minimum distance between points
    private let minimumAccuracy: Double = 20.0 // meters - minimum horizontal accuracy
    private let speedSmoothingWindow = 5 // Number of points for speed averaging
    private var speedHistory: [Double] = []
    
    // MARK: - Computed Properties
    var currentPace: Double {
        // Pace in minutes per mile
        guard currentSpeed > 0 else { return 0 }
        let milesPerHour = currentSpeed * 2.237 // Convert m/s to mph
        return 60.0 / milesPerHour // minutes per mile
    }
    
    var averagePace: Double {
        // Average pace in minutes per mile
        guard averageSpeed > 0 else { return 0 }
        let milesPerHour = averageSpeed * 2.237
        return 60.0 / milesPerHour
    }
    
    var totalDistanceMiles: Double {
        return totalDistance * 0.000621371 // Convert meters to miles
    }
    
    var elapsedTime: TimeInterval {
        guard let startTime = startTime else { return 0 }
        return Date().timeIntervalSince(startTime)
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupLocationManager()
    }
    
    // MARK: - Public Methods
    func requestLocationPermission() {
        print("🔐 Requesting location permission. Current status: \(authorizationStatus.rawValue)")

        switch authorizationStatus {
        case .notDetermined:
            // First, request "When In Use"
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            // Upgrade to "Always" for background tracking
            locationManager.requestAlwaysAuthorization()
        default:
            break
        }
    }

    /// Request background location permission (call after user starts a recording)
    func requestAlwaysPermissionIfNeeded() {
        if authorizationStatus == .authorizedWhenInUse {
            print("🔐 Requesting Always location permission for background tracking")
            locationManager.requestAlwaysAuthorization()
        }
    }
    
    func startLocationUpdates() {
        print("📍 Starting location updates. Current status: \(authorizationStatus.rawValue)")
        locationManager.startUpdatingLocation()
    }
    
    func startTracking() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            print("❌ Location permission not granted")
            return
        }

        guard !isTracking else {
            print("⚠️ Tracking already in progress")
            return
        }

        print("🏃 Starting GPS tracking")

        // Reset tracking data with efficient memory management
        routePoints.removeAll(keepingCapacity: true) // Keep capacity for performance
        speedHistory.removeAll(keepingCapacity: true)
        totalDistance = 0.0
        currentSpeed = 0.0
        averageSpeed = 0.0
        lastLocation = nil
        startTime = Date()

        // Start location updates
        isTracking = true
        locationManager.startUpdatingLocation()

        // Enable background location updates (works with both When In Use and Always)
        // Note: With "When In Use", the blue status bar indicator will show
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.showsBackgroundLocationIndicator = true

        // Request Always permission for better background support
        if authorizationStatus == .authorizedWhenInUse {
            print("📍 Requesting Always permission for seamless background tracking")
            locationManager.requestAlwaysAuthorization()
        }
    }
    
    func stopTracking() {
        guard isTracking else { return }

        print("⏹️ Stopping GPS tracking")

        isTracking = false
        locationManager.stopUpdatingLocation()

        // Disable background updates
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.pausesLocationUpdatesAutomatically = true
        locationManager.showsBackgroundLocationIndicator = false

        print("📊 Final tracking stats:")
        print("   - Total distance: \(String(format: "%.2f", totalDistanceMiles)) miles")
        print("   - Total points: \(routePoints.count)")
        print("   - Elapsed time: \(String(format: "%.0f", elapsedTime)) seconds")
    }
    
    func pauseTracking() {
        guard isTracking else { return }
        locationManager.stopUpdatingLocation()
        print("⏸️ GPS tracking paused")
    }
    
    func resumeTracking() {
        guard isTracking else { return }
        locationManager.startUpdatingLocation()
        print("▶️ GPS tracking resumed")
    }
    
    func clearRoute() {
        // Clear arrays with capacity to avoid repeated allocations
        routePoints.removeAll(keepingCapacity: false)
        speedHistory.removeAll(keepingCapacity: false)

        totalDistance = 0.0
        currentSpeed = 0.0
        averageSpeed = 0.0
        lastLocation = nil
        startTime = nil
        print("🗑️ Route data cleared")
    }
    
    // MARK: - Private Methods
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 3.0 // Update every 3 meters
        authorizationStatus = locationManager.authorizationStatus
    }
    
    private func processNewLocation(_ location: CLLocation) {
        // Filter out invalid locations
        guard location.horizontalAccuracy <= minimumAccuracy,
              location.horizontalAccuracy > 0 else {
            print("⚠️ Location filtered out due to poor accuracy: \(location.horizontalAccuracy)m")
            return
        }

        // Update current location on main thread immediately for UI
        Task { @MainActor in
            self.currentLocation = location
        }

        // Process heavy calculations on background thread
        Task.detached { [weak self] in
            guard let self = self else { return }

            // Calculate distance from last point
            let lastLoc = await MainActor.run { self.lastLocation }
            if let lastLoc = lastLoc {
                let distance = location.distance(from: lastLoc)

                // Only add point if it's far enough from the last one
                if distance >= self.minimumDistance {
                    await self.addRoutePoint(location)
                    await self.updateDistance(distance)
                    await self.updateSpeed(location)
                    await MainActor.run {
                        self.lastLocation = location
                    }
                }
            } else {
                // First location point
                await self.addRoutePoint(location)
                await MainActor.run {
                    self.lastLocation = location
                }
            }
        }
    }
    
    @MainActor
    private func addRoutePoint(_ location: CLLocation) {
        let point = GPSRoutePoint(location: location)
        routePoints.append(point)
        print("📍 Added route point: \(routePoints.count) - \(String(format: "%.6f", location.coordinate.latitude)), \(String(format: "%.6f", location.coordinate.longitude))")
    }

    @MainActor
    private func updateDistance(_ additionalDistance: Double) {
        totalDistance += additionalDistance
        print("📏 Distance updated: +\(String(format: "%.1f", additionalDistance))m, Total: \(String(format: "%.2f", totalDistanceMiles)) miles")
    }
    
    @MainActor
    private func updateSpeed(_ location: CLLocation) {
        let calculatedSpeed: Double

        // Update current speed (prefer GPS speed if available and reasonable)
        if location.speed >= 0 && location.speed < 20 { // Max ~45 mph seems reasonable for running
            calculatedSpeed = location.speed
        } else if let lastLoc = lastLocation {
            // Calculate speed from distance/time
            let distance = location.distance(from: lastLoc)
            let timeInterval = location.timestamp.timeIntervalSince(lastLoc.timestamp)
            if timeInterval > 0 {
                calculatedSpeed = distance / timeInterval
            } else {
                calculatedSpeed = currentSpeed // Keep previous speed if time interval is 0
            }
        } else {
            calculatedSpeed = 0.0
        }

        currentSpeed = calculatedSpeed

        // Add to speed history for averaging
        speedHistory.append(currentSpeed)
        if speedHistory.count > speedSmoothingWindow {
            speedHistory.removeFirst()
        }

        // Calculate average speed
        if !speedHistory.isEmpty {
            averageSpeed = speedHistory.reduce(0, +) / Double(speedHistory.count)
        }

        // Also calculate overall average speed
        if elapsedTime > 0 {
            let overallAverageSpeed = totalDistance / elapsedTime
            // Use the more conservative of the two averages
            averageSpeed = min(averageSpeed, overallAverageSpeed)
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension GPSTrackingService: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        // Only process for tracking if actively tracking
        if isTracking {
            for location in locations {
                processNewLocation(location)
            }
        } else {
            // Just update current location for display when not tracking
            Task { @MainActor in
                self.currentLocation = location
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        print("📍 Location authorization changed: \(status.rawValue)")
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            print("✅ Location permission granted")
        case .denied, .restricted:
            print("❌ Location permission denied")
        case .notDetermined:
            print("❓ Location permission not determined")
        @unknown default:
            print("❓ Unknown location authorization status")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location manager error: \(error.localizedDescription)")
        
        if let clError = error as? CLError {
            switch clError.code {
            case .locationUnknown:
                print("   - Location service unable to determine location")
            case .denied:
                print("   - Location services disabled or denied")
            case .network:
                print("   - Network error")
            default:
                print("   - Other location error: \(clError.localizedDescription)")
            }
        }
    }
}