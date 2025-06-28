//
//  LocationManager.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 6/28/25.
//

import Foundation
import CoreLocation
import SwiftUI

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var locationString: String = ""
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    // Throttling properties to prevent excessive geocoding
    private var lastGeocodedLocation: CLLocation?
    private var lastGeocodeTime: Date = Date.distantPast
    private let minimumGeocodeDistance: CLLocationDistance = 1609.34 // 1 mile
    private let minimumGeocodeInterval: TimeInterval = 300 // 5 minutes
    private var isCurrentlyGeocoding = false
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 100 // Only update when moved 100m
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestLocationPermission() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
        case .denied, .restricted:
            print("Location access denied or restricted")
        @unknown default:
            break
        }
    }
    
    func startLocationUpdates() {
        guard locationManager.authorizationStatus == .authorizedWhenInUse || 
              locationManager.authorizationStatus == .authorizedAlways else {
            return
        }
        locationManager.startUpdatingLocation()
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
    }
    
    func requestSingleLocation() {
        guard locationManager.authorizationStatus == .authorizedWhenInUse || 
              locationManager.authorizationStatus == .authorizedAlways else {
            requestLocationPermission()
            return
        }
        locationManager.requestLocation()
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        DispatchQueue.main.async {
            self.location = location
        }
        
        // Check if we should geocode this location
        guard shouldGeocodeLocation(location) else { return }
        
        performReverseGeocode(for: location)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status
        }
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
        case .denied, .restricted:
            stopLocationUpdates()
        case .notDetermined:
            // Wait for user decision
            break
        @unknown default:
            break
        }
    }
    
    // MARK: - Geocoding
    
    private func shouldGeocodeLocation(_ location: CLLocation) -> Bool {
        // Don't geocode if already in progress
        guard !isCurrentlyGeocoding else { return false }
        
        // Check time interval
        let timeSinceLastGeocode = Date().timeIntervalSince(lastGeocodeTime)
        guard timeSinceLastGeocode >= minimumGeocodeInterval else { return false }
        
        // Check distance if we have a previous location
        if let lastLocation = lastGeocodedLocation {
            let distance = location.distance(from: lastLocation)
            guard distance >= minimumGeocodeDistance else { return false }
        }
        
        return true
    }
    
    private func performReverseGeocode(for location: CLLocation) {
        isCurrentlyGeocoding = true
        
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                self?.isCurrentlyGeocoding = false
                
                if let error = error {
                    print("Geocoding error: \(error.localizedDescription)")
                    return
                }
                
                if let placemark = placemarks?.first {
                    let city = placemark.locality ?? "Unknown"
                    let state = placemark.administrativeArea ?? ""
                    let locationString = "\(city), \(state)"
                    
                    self?.locationString = locationString
                    
                    // Save to shared UserDefaults for widget access
                    if let userDefaults = UserDefaults(suiteName: "group.com.jackrudelic.runawayios") {
                        userDefaults.set(locationString, forKey: "currentLocation")
                    }
                    
                    // Update throttling state
                    self?.lastGeocodedLocation = location
                    self?.lastGeocodeTime = Date()
                }
            }
        }
    }
    
    // MARK: - Utility Methods
    
    var isLocationAuthorized: Bool {
        return authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }
    
    var isLocationDenied: Bool {
        return authorizationStatus == .denied || authorizationStatus == .restricted
    }
}