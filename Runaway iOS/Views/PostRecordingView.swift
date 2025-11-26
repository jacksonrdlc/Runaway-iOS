//
//  PostRecordingView.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 6/29/25.
//

import SwiftUI
import MapKit

struct PostRecordingView: View {
    @ObservedObject var recordingService: ActivityRecordingService
    @Environment(\.dismiss) private var dismiss
    
    @State private var activityName = ""
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showingSaveError = false
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Route map preview
                    if !recordingService.gpsService.routePoints.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Route")
                                .font(.headline)
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            
                            RoutePreviewMap(
                                routePoints: recordingService.gpsService.routePoints,
                                region: $region
                            )
                            .frame(height: 200)
                            .cornerRadius(12)
                            .onAppear {
                                setupMapRegion()
                            }
                        }
                    }
                    
                    // Activity summary
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Activity Summary")
                            .font(.headline)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                            SummaryMetricCard(
                                title: "Distance",
                                value: String(format: "%.2f", recordingService.gpsService.totalDistanceMiles),
                                unit: "miles",
                                icon: "road.lanes",
                                color: .blue
                            )
                            
                            SummaryMetricCard(
                                title: "Time",
                                value: formatTime(recordingService.currentSession?.elapsedTime ?? 0),
                                unit: "",
                                icon: "clock",
                                color: .green
                            )
                            
                            SummaryMetricCard(
                                title: "Avg Pace",
                                value: formatPace(recordingService.gpsService.averagePace),
                                unit: "/mile",
                                icon: "speedometer",
                                color: .orange
                            )
                            
                            SummaryMetricCard(
                                title: "Avg Speed",
                                value: String(format: "%.1f", recordingService.gpsService.averageSpeed * 2.237),
                                unit: "mph",
                                icon: "gauge.high",
                                color: .purple
                            )
                        }
                    }
                    
                    // Activity details
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Activity Details")
                            .font(.headline)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        VStack(spacing: 12) {
                            // Activity name input
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Activity Name")
                                    .font(.subheadline)
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                
                                TextField("Enter activity name", text: $activityName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .onAppear {
                                        if activityName.isEmpty {
                                            activityName = recordingService.currentSession?.name ?? ""
                                        }
                                    }
                            }
                            
                            // Activity type and date
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Type")
                                        .font(.caption)
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                    Text(recordingService.currentSession?.activityType ?? "Run")
                                        .font(.subheadline)
                                        .foregroundColor(AppTheme.Colors.textPrimary)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Date")
                                        .font(.caption)
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                    Text(formatDate(recordingService.currentSession?.startTime ?? Date()))
                                        .font(.subheadline)
                                        .foregroundColor(AppTheme.Colors.textPrimary)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .padding()
                        .background(AppTheme.Colors.cardBackground)
                        .cornerRadius(12)
                    }
                    
                    // Additional stats
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Route Statistics")
                            .font(.headline)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        HStack {
                            StatItem(
                                title: "Route Points",
                                value: "\(recordingService.gpsService.routePoints.count)",
                                icon: "location.circle"
                            )
                            
                            Spacer()
                            
                            StatItem(
                                title: "Start Time",
                                value: formatStartTime(recordingService.currentSession?.startTime ?? Date()),
                                icon: "clock.arrow.circlepath"
                            )
                            
                            Spacer()
                            
                            StatItem(
                                title: "End Time",
                                value: formatStartTime(recordingService.currentSession?.endTime ?? Date()),
                                icon: "flag.checkered"
                            )
                        }
                        .padding()
                        .background(AppTheme.Colors.cardBackground)
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Activity Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Discard") {
                        recordingService.discardRecording()
                        dismiss()
                    }
                    .foregroundColor(.red)
                    .disabled(isSaving)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: saveActivity) {
                        if isSaving {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Saving...")
                            }
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isSaving || activityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .alert("Save Error", isPresented: $showingSaveError) {
            Button("OK") { }
        } message: {
            Text(saveError ?? "Unknown error occurred while saving activity")
        }
    }
    
    // MARK: - Methods
    
    private func setupMapRegion() {
        let coordinates = recordingService.gpsService.routePoints.map { $0.coordinate }
        
        guard !coordinates.isEmpty else { return }
        
        let polylineService = PolylineEncodingService()
        if let bounds = polylineService.getBounds(coordinates: coordinates) {
            region = MKCoordinateRegion(center: bounds.center, span: bounds.span)
        }
    }
    
    private func saveActivity() {
        guard !activityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        isSaving = true
        
        // Update session name
        recordingService.currentSession?.name = activityName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        Task {
            do {
                let savedActivity = try await recordingService.saveActivity()
                
                await MainActor.run {
                    isSaving = false
                    
                    if savedActivity != nil {
                        // Successfully saved, dismiss view
                        dismiss()
                    } else {
                        saveError = "Failed to save activity"
                        showingSaveError = true
                    }
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    saveError = error.localizedDescription
                    showingSaveError = true
                }
            }
        }
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
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formatStartTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Summary Metric Card
struct SummaryMetricCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.caption)
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    }
                }
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .padding()
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - Stat Item
struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(AppTheme.Colors.accent)
                .font(.title3)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Route Preview Map
struct RoutePreviewMap: UIViewRepresentable {
    let routePoints: [GPSRoutePoint]
    @Binding var region: MKCoordinateRegion
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.isUserInteractionEnabled = false
        mapView.mapType = .standard
        mapView.showsCompass = false
        mapView.showsScale = false
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Set region
        mapView.setRegion(region, animated: false)
        
        // Clear existing overlays
        mapView.removeOverlays(mapView.overlays)
        
        // Add route polyline
        if routePoints.count > 1 {
            let coordinates = routePoints.map { $0.coordinate }
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            mapView.addOverlay(polyline)
            
            // Add start and end annotations
            let startAnnotation = MKPointAnnotation()
            startAnnotation.coordinate = coordinates.first!
            startAnnotation.title = "Start"
            
            let endAnnotation = MKPointAnnotation()
            endAnnotation.coordinate = coordinates.last!
            endAnnotation.title = "Finish"
            
            mapView.addAnnotations([startAnnotation, endAnnotation])
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.systemBlue
                renderer.lineWidth = 4
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            
            let identifier = "RoutePoint"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = false
            } else {
                annotationView?.annotation = annotation
            }
            
            if let pinView = annotationView as? MKPinAnnotationView {
                pinView.pinTintColor = annotation.title == "Start" ? .green : .red
            }
            
            return annotationView
        }
    }
}

#Preview {
    PostRecordingView(recordingService: ActivityRecordingService())
}