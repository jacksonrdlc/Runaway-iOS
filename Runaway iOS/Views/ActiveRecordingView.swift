//
//  ActiveRecordingView.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 6/29/25.
//

import SwiftUI
import MapboxMaps
import CoreLocation

struct ActiveRecordingView: View {
    @ObservedObject var recordingService: ActivityRecordingService
    let activityType: String
    let customName: String

    @Environment(\.dismiss) private var dismiss
    @State private var showingStopConfirmation = false
    @State private var showingPostRecording = false

    @StateObject private var timerManager = TimerUpdateManager()
    @StateObject private var mapThrottler = MapRegionThrottler()
    @StateObject private var audioCoaching = AudioCoachingService()
    
    var body: some View {
        ZStack {
            // MapBox map with route tracking and 3D buildings
            ActiveRecordingMapBoxView(
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
                        Text(formatTime(timerManager.elapsedTime))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("TIME")
                            .font(.caption2)
                            .foregroundColor(AppTheme.Colors.textSecondary)
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
                            .foregroundColor(AppTheme.Colors.textSecondary)
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
                            .foregroundColor(AppTheme.Colors.textSecondary)
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

                    // Listening indicator - prominent when voice input is active
                    if audioCoaching.isListening {
                        HStack(spacing: 12) {
                            // Animated waveform
                            ListeningWaveform()

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Listening...")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                Text("Say how you're feeling or ask for stats")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }

                            Spacer()

                            // Cancel button
                            Button(action: {
                                audioCoaching.stopVoiceInput()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(AppTheme.Colors.iconSecondary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.green.opacity(0.9))
                                .shadow(color: .green.opacity(0.5), radius: 10, x: 0, y: 4)
                        )
                        .transition(.scale.combined(with: .opacity))
                        .animation(.spring(response: 0.3), value: audioCoaching.isListening)
                    }
                    // Audio coaching prompt indicator (when speaking)
                    else if let lastPrompt = audioCoaching.lastPromptMessage,
                       let promptTime = audioCoaching.lastPromptTime,
                       Date().timeIntervalSince(promptTime) < 5.0 {
                        HStack {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundColor(.blue)
                            Text(lastPrompt)
                                .foregroundColor(.white)
                                .font(.subheadline)
                                .lineLimit(2)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.easeInOut, value: lastPrompt)
                    }
                    
                    // Control buttons
                    HStack(spacing: 16) {
                        // Audio coaching toggle
                        Button(action: {
                            audioCoaching.isEnabled.toggle()
                        }) {
                            Image(systemName: audioCoaching.isEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                .font(.title3)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(audioCoaching.isEnabled ? .blue : .gray, in: Circle())
                                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                        }

                        // Voice input button
                        Button(action: {
                            Task {
                                await audioCoaching.toggleVoiceInput()
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(audioCoaching.isListening ? .green : .purple)
                                    .frame(width: 44, height: 44)
                                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)

                                Image(systemName: audioCoaching.isListening ? "waveform" : "mic.fill")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .symbolEffect(.variableColor.iterative, isActive: audioCoaching.isListening)
                            }
                        }

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
            timerManager.start()
            // Bind audio coaching to recording service
            audioCoaching.bind(to: recordingService)
        }
        .onDisappear {
            timerManager.stop()
            // Unbind audio coaching
            audioCoaching.unbind()
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
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Active Recording MapBox View
struct ActiveRecordingMapBoxView: View {
    let currentLocation: CLLocation?
    let routePoints: [GPSRoutePoint]

    @State private var mapView: MapboxMaps.MapView?
    private let routeRenderer = MapBoxRouteRenderer()

    var body: some View {
        MapBoxBaseView(
            config: .recording,
            currentLocation: currentLocation,
            onMapLoaded: {
                // Map is ready, can add route if needed
                updateRoute()
            }
        )
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MapViewCreated"))) { notification in
            if let mapView = notification.object as? MapboxMaps.MapView {
                self.mapView = mapView
                updateRoute()
            }
        }
        .onChange(of: routePoints.count) { _ in
            updateRoute()
        }
    }

    private func updateRoute() {
        guard let mapView = mapView, routePoints.count > 1 else { return }

        // Convert GPSRoutePoints to coordinates
        let coordinates = routePoints.map { $0.coordinate }

        // Encode as polyline for route renderer
        let polylineService = PolylineEncodingService()
        let encodedPolyline = polylineService.encode(coordinates: coordinates)

        // Add route to map
        routeRenderer.addRoute(
            to: mapView,
            polyline: encodedPolyline,
            style: .recording,
            showMarkers: false
        )
    }
}

// MARK: - Listening Waveform Animation
struct ListeningWaveform: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(.white)
                    .frame(width: 4, height: animating ? CGFloat.random(in: 12...24) : 8)
                    .animation(
                        .easeInOut(duration: 0.3)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.1),
                        value: animating
                    )
            }
        }
        .frame(width: 28, height: 24)
        .onAppear {
            animating = true
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