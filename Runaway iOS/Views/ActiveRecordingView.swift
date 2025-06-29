//
//  ActiveRecordingView.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 6/29/25.
//

import SwiftUI
import MapKit
import CoreLocation

struct ActiveRecordingView: View {
    @ObservedObject var recordingService: ActivityRecordingService
    let activityType: String
    let customName: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingStopConfirmation = false
    @State private var showingPostRecording = false
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    
    var body: some View {
        ZStack {
            // Map with route tracking
            ActiveRecordingMapView(
                region: $region,
                currentLocation: recordingService.gpsService.currentLocation,
                routePoints: recordingService.gpsService.routePoints
            )
            .ignoresSafeArea()
            
            // UI Overlay
            VStack {
                // Top metrics bar
                HStack {
                    // Time
                    VStack(spacing: 2) {
                        Text(formatTime(elapsedTime))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("TIME")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    // Distance
                    VStack(spacing: 2) {
                        Text(String(format: "%.2f", recordingService.gpsService.totalDistanceMiles))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("MILES")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    // Current pace
                    VStack(spacing: 2) {
                        Text(formatPace(recordingService.gpsService.currentPace))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("PACE")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .padding(.top, 8)
                
                Spacer()
                
                // Bottom controls
                VStack(spacing: 20) {
                    // Additional metrics
                    HStack(spacing: 30) {
                        MetricDisplay(
                            value: formatPace(recordingService.gpsService.averagePace),
                            label: "AVG PACE",
                            color: .blue
                        )
                        
                        MetricDisplay(
                            value: String(format: "%.1f", recordingService.gpsService.currentSpeed * 2.237), // mph
                            label: "SPEED",
                            color: .green
                        )
                        
                        MetricDisplay(
                            value: "\(recordingService.gpsService.routePoints.count)",
                            label: "POINTS",
                            color: .purple
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    
                    // Auto-pause indicator
                    if recordingService.isAutopaused {
                        HStack {
                            Image(systemName: "pause.circle.fill")
                                .foregroundColor(.orange)
                            Text("Auto-paused - Start moving to resume")
                                .foregroundColor(.white)
                                .font(.subheadline)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                    
                    // Control buttons
                    HStack(spacing: 20) {
                        // Pause/Resume button
                        Button(action: togglePauseResume) {
                            Image(systemName: pauseResumeIcon)
                                .font(.title)
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(pauseResumeColor, in: Circle())
                                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(recordingService.isAutopaused)
                        
                        // Stop button
                        Button(action: {
                            showingStopConfirmation = true
                        }) {
                            Image(systemName: "stop.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(.red, in: Circle())
                                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            startTimer()
            centerMapOnCurrentLocation()
        }
        .onDisappear {
            stopTimer()
        }
        .confirmationDialog("Stop Recording", isPresented: $showingStopConfirmation) {
            Button("Stop and Save", role: .destructive) {
                stopRecording()
            }
            Button("Discard", role: .destructive) {
                discardRecording()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Do you want to save this activity or discard it?")
        }
        .fullScreenCover(isPresented: $showingPostRecording) {
            PostRecordingView(recordingService: recordingService)
        }
    }
    
    // MARK: - Computed Properties
    
    private var pauseResumeIcon: String {
        switch recordingService.state {
        case .recording:
            return "pause.fill"
        case .paused:
            return "play.fill"
        default:
            return "pause.fill"
        }
    }
    
    private var pauseResumeColor: Color {
        switch recordingService.state {
        case .recording:
            return .orange
        case .paused:
            return .green
        default:
            return .orange
        }
    }
    
    // MARK: - Methods
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateElapsedTime()
            updateMapRegion()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateElapsedTime() {
        elapsedTime = recordingService.gpsService.elapsedTime
    }
    
    private func updateMapRegion() {
        // Follow user's current location
        if let location = recordingService.gpsService.currentLocation {
            let newRegion = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            
            // Only update if the change is significant to avoid constant updates
            let currentCenter = region.center
            let latDiff = abs(currentCenter.latitude - newRegion.center.latitude)
            let lonDiff = abs(currentCenter.longitude - newRegion.center.longitude)
            
            if latDiff > 0.0001 || lonDiff > 0.0001 {
                region = newRegion
            }
        }
    }
    
    private func centerMapOnCurrentLocation() {
        if let location = recordingService.gpsService.currentLocation {
            region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
    }
    
    private func togglePauseResume() {
        switch recordingService.state {
        case .recording:
            recordingService.pauseRecording()
        case .paused:
            recordingService.resumeRecording()
        default:
            break
        }
    }
    
    private func stopRecording() {
        recordingService.stopRecording()
        showingPostRecording = true
    }
    
    private func discardRecording() {
        recordingService.discardRecording()
        dismiss()
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private func formatPace(_ pace: Double) -> String {
        guard pace > 0 && pace < 999 else { return "--:--" }
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Metric Display Component
struct MetricDisplay: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Active Recording Map View
struct ActiveRecordingMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let currentLocation: CLLocation?
    let routePoints: [GPSRoutePoint]
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .follow
        mapView.mapType = .standard
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.showsCompass = false
        mapView.showsScale = false
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update region
        if abs(mapView.region.center.latitude - region.center.latitude) > 0.001 ||
           abs(mapView.region.center.longitude - region.center.longitude) > 0.001 {
            mapView.setRegion(region, animated: true)
        }
        
        // Update route polyline
        updateRouteOverlay(mapView: mapView)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func updateRouteOverlay(mapView: MKMapView) {
        // Remove existing route overlays
        let existingOverlays = mapView.overlays.filter { $0 is MKPolyline }
        mapView.removeOverlays(existingOverlays)
        
        // Add new route if we have enough points
        if routePoints.count > 1 {
            let coordinates = routePoints.map { $0.coordinate }
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            mapView.addOverlay(polyline)
        }
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        let parent: ActiveRecordingMapView
        
        init(_ parent: ActiveRecordingMapView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.systemBlue
                renderer.lineWidth = 6
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            DispatchQueue.main.async {
                self.parent.region = mapView.region
            }
        }
    }
}

#Preview {
    ActiveRecordingView(
        recordingService: ActivityRecordingService(),
        activityType: "Run",
        customName: "Morning Run"
    )
}