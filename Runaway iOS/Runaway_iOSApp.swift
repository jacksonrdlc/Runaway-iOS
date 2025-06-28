//
//  Runaway_iOSApp.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 2/18/25.
//

import SwiftUI
import Foundation
import FirebaseCore
import CoreLocation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var location: CLLocation?
    
    // Throttling properties to prevent excessive geocoding
    private var lastGeocodedLocation: CLLocation?
    private var lastGeocodeTime: Date = Date.distantPast
    private let minimumGeocodeDistance: CLLocationDistance = 1609.34 // 1 mile
    private let minimumGeocodeInterval: TimeInterval = 300 // 5 minutes
    private var isCurrentlyGeocoding = false
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters // Less aggressive accuracy
        locationManager.distanceFilter = 100 // Only update when moved 100m
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.location = location
        
        // Check if we should geocode this location
        guard shouldGeocodeLocation(location) else { return }
        
        performReverseGeocode(for: location)
    }
    
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
                    
                    // Save to shared UserDefaults
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
}

@main
struct Runaway_iOSApp: App {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var realtimeService = RealtimeService.shared
    @StateObject private var userManager = UserManager.shared
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(realtimeService)
                .environmentObject(userManager)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    realtimeService.startRealtimeSubscription()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    // Keep subscription running in background
                }
        }
    }
} 
