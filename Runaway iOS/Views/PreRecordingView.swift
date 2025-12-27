//
//  PreRecordingView.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 6/29/25.
//

import SwiftUI
import MapboxMaps
import CoreLocation

struct PreRecordingView: View {
    @StateObject private var recordingService = ActivityRecordingService()
    @Environment(\.dismiss) private var dismiss

    @State private var showingPermissionAlert = false
    @State private var showingRecordingView = false
    @State private var activityType = "Run"
    @State private var customName = ""
    @State private var showingActivityTypeSelector = false
    @State private var locationName: String?
    
    private let activityTypes = ["Run", "Walk", "Bike", "Hike"]
    
    var body: some View {
        ZStack {
            // MapBox map taking up full screen
            MapBoxBaseView(
                config: .lightMode,
                currentLocation: recordingService.gpsService.currentLocation
            )
            .ignoresSafeArea()
            
            // Overlay UI
            VStack {
                // Top bar with close button and activity type
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    
                    Spacer()
                    
                    Button(activityType) {
                        showingActivityTypeSelector = true
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                Spacer()
                
                // Bottom controls
                VStack(spacing: 16) {
                    // Custom name input (optional)
                    HStack {
                        Image(systemName: "pencil")
                            .foregroundColor(.white)
                        
                        TextField("Activity name (optional)", text: $customName)
                            .foregroundColor(.white)
                            .tint(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    
                    // Location status
                    HStack {
                        Image(systemName: locationIcon)
                            .foregroundColor(locationColor)
                        Text(locationStatusText)
                            .foregroundColor(.white)
                            .font(.subheadline)
                            .id(locationName) // Force refresh when locationName changes
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    
                    // Start button
                    Button(action: startRecording) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Start \(activityType)")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: canStartRecording ? [.green, .green.opacity(0.8)] : [.gray, .gray.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .disabled(!canStartRecording)
                    .scaleEffect(canStartRecording ? 1.0 : 0.95)
                    .animation(.easeInOut(duration: 0.2), value: canStartRecording)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            setupLocationServices()
        }
        .alert("Location Permission Required", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                openAppSettings()
            }
            Button("Cancel", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("Please enable location access in Settings to record your activity route.")
        }
        .confirmationDialog("Select Activity Type", isPresented: $showingActivityTypeSelector) {
            ForEach(activityTypes, id: \.self) { type in
                Button(type) {
                    activityType = type
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .fullScreenCover(isPresented: $showingRecordingView) {
            ActiveRecordingView(
                recordingService: recordingService,
                activityType: activityType,
                customName: customName
            )
        }
    }
    
    // MARK: - Computed Properties
    
    private var canStartRecording: Bool {
        return recordingService.canStartRecording
    }
    
    private var locationIcon: String {
        switch recordingService.gpsService.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return recordingService.gpsService.currentLocation != nil ? "location.fill" : "location"
        case .denied, .restricted:
            return "location.slash"
        case .notDetermined:
            return "location.circle"
        @unknown default:
            return "location.circle"
        }
    }
    
    private var locationColor: Color {
        switch recordingService.gpsService.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return recordingService.gpsService.currentLocation != nil ? .green : .yellow
        case .denied, .restricted:
            return .red
        case .notDetermined:
            return .orange
        @unknown default:
            return .gray
        }
    }
    
    private var locationStatusText: String {
        switch recordingService.gpsService.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if recordingService.gpsService.currentLocation != nil {
                return locationName ?? "GPS Ready"
            } else {
                return "Finding location..."
            }
        case .denied, .restricted:
            return "Location access denied"
        case .notDetermined:
            return "Location permission needed"
        @unknown default:
            return "Location status unknown"
        }
    }
    
    // MARK: - Methods
    
    private func setupLocationServices() {
        // Request permission first
        recordingService.requestLocationPermission()
        
        // Monitor authorization status changes and start location updates when authorized
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            let isAuthorized = recordingService.gpsService.authorizationStatus.isAuthorized
            
            if isAuthorized {
                // Start location updates for map centering
                recordingService.gpsService.startLocationUpdates()
                timer.invalidate()
                
                // Start monitoring for location updates
                self.monitorLocationForMapCentering()
            } else if recordingService.gpsService.authorizationStatus == .denied || 
                      recordingService.gpsService.authorizationStatus == .restricted {
                timer.invalidate()
                showingPermissionAlert = true
            }
            
            // Timeout after 10 seconds waiting for permission
            if timer.fireDate.timeIntervalSinceNow < -10 {
                timer.invalidate()
                if !isAuthorized {
                    showingPermissionAlert = true
                }
            }
        }
    }
    
    private func monitorLocationForMapCentering() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if let location = recordingService.gpsService.currentLocation {
                print("📍 Got location for map centering: \(location.coordinate)")

                // Reverse geocode to get location name
                reverseGeocodeLocation(location)

                timer.invalidate()
            }

            // Timeout after 30 seconds
            if timer.fireDate.timeIntervalSinceNow < -30 {
                print("⏰ Location monitoring timeout")
                timer.invalidate()
            }
        }
    }
    
    private func reverseGeocodeLocation(_ location: CLLocation) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("🔍 Reverse geocoding error: \(error.localizedDescription)")
                    return
                }
                
                if let placemark = placemarks?.first {
                    // Build location name from available components
                    var components: [String] = []
                    
                    if let name = placemark.name {
                        components.append(name)
                    } else if let thoroughfare = placemark.thoroughfare {
                        components.append(thoroughfare)
                    }
                    
                    if let locality = placemark.locality {
                        components.append(locality)
                    } else if let subLocality = placemark.subLocality {
                        components.append(subLocality)
                    }
                    
                    if let administrativeArea = placemark.administrativeArea {
                        components.append(administrativeArea)
                    }
                    
                    let locationString = components.prefix(2).joined(separator: ", ")
                    let newLocationName = locationString.isEmpty ? "Current Location" : locationString
                    
                    print("🏷️ Setting location name to: \(newLocationName)")
                    self.locationName = newLocationName
                    print("🏷️ Location name state updated: \(self.locationName ?? "nil")")
                }
            }
        }
    }
    
    private func startRecording() {
        guard canStartRecording else {
            if !recordingService.gpsService.authorizationStatus.isAuthorized {
                showingPermissionAlert = true
            }
            return
        }
        
        print("🏃 Starting recording with type: \(activityType), name: \(customName)")
        
        recordingService.startRecording(
            activityType: activityType,
            name: customName
        )
        
        showingRecordingView = true
    }
    
    private func openAppSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

#Preview {
    PreRecordingView()
}