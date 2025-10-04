//
//  ActivityRecordingService.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 6/29/25.
//

import Foundation
import CoreLocation
import MapKit
import Combine
import WidgetKit

// MARK: - Recording State
enum RecordingState {
    case ready        // Ready to start recording
    case recording    // Currently recording
    case paused       // Recording paused
    case completed    // Recording finished
}

// MARK: - Recording Session Model
struct RecordingSession {
    let id = UUID()
    let startTime: Date
    var endTime: Date?
    var totalDistance: Double = 0.0 // meters
    var routePoints: [GPSRoutePoint] = []
    var pausedDuration: TimeInterval = 0.0
    var name: String = ""
    var activityType: String = "Run"
    
    var elapsedTime: TimeInterval {
        let endTime = self.endTime ?? Date()
        return endTime.timeIntervalSince(startTime) - pausedDuration
    }
    
    var averageSpeed: Double {
        guard elapsedTime > 0 else { return 0 }
        return totalDistance / elapsedTime
    }
    
    var averagePace: Double {
        guard averageSpeed > 0 else { return 0 }
        let milesPerHour = averageSpeed * 2.237
        return 60.0 / milesPerHour
    }
    
    var totalDistanceMiles: Double {
        return totalDistance * 0.000621371
    }
}

// MARK: - Activity Recording Service
@MainActor
class ActivityRecordingService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var state: RecordingState = .ready
    @Published var currentSession: RecordingSession?
    @Published var gpsService = GPSTrackingService()
    @Published var isAutopaused = false
    
    // MARK: - Private Properties
    private var pauseStartTime: Date?
    private var cancellables = Set<AnyCancellable>()
    private let autoPauseThreshold: Double = 0.5 // m/s (~1.1 mph)
    private let autoPauseDelay: TimeInterval = 10.0 // seconds
    private var lowSpeedStartTime: Date?
    
    // MARK: - Computed Properties
    var canStartRecording: Bool {
        return state == .ready && gpsService.authorizationStatus.isAuthorized
    }
    
    var canPauseRecording: Bool {
        return state == .recording
    }
    
    var canResumeRecording: Bool {
        return state == .paused
    }
    
    var canStopRecording: Bool {
        return state == .recording || state == .paused
    }
    
    // MARK: - Initialization
    init() {
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    func requestLocationPermission() {
        gpsService.requestLocationPermission()
    }
    
    func startRecording(activityType: String = "Run", name: String = "") {
        guard canStartRecording else {
            print("❌ Cannot start recording - invalid state or permissions")
            return
        }
        
        print("🏃 Starting activity recording")
        
        // Create new session
        currentSession = RecordingSession(
            startTime: Date(),
            name: name.isEmpty ? generateDefaultName() : name,
            activityType: activityType
        )
        
        // Start GPS tracking
        gpsService.startTracking()
        
        // Update state
        state = .recording
        isAutopaused = false
        lowSpeedStartTime = nil
        
        print("✅ Recording started successfully")
    }
    
    func pauseRecording() {
        guard canPauseRecording else {
            print("❌ Cannot pause recording - invalid state")
            return
        }
        
        print("⏸️ Pausing activity recording")
        
        gpsService.pauseTracking()
        state = .paused
        pauseStartTime = Date()
        isAutopaused = false
    }
    
    func resumeRecording() {
        guard canResumeRecording else {
            print("❌ Cannot resume recording - invalid state")
            return
        }
        
        print("▶️ Resuming activity recording")
        
        // Add paused time to total
        if let pauseStart = pauseStartTime {
            let pausedTime = Date().timeIntervalSince(pauseStart)
            currentSession?.pausedDuration += pausedTime
            pauseStartTime = nil
        }
        
        gpsService.resumeTracking()
        state = .recording
        isAutopaused = false
    }
    
    func stopRecording() {
        guard canStopRecording else {
            print("❌ Cannot stop recording - invalid state")
            return
        }
        
        print("⏹️ Stopping activity recording")
        
        // Stop GPS tracking
        gpsService.stopTracking()
        
        // Update session with final data
        if var session = currentSession {
            session.endTime = Date()
            session.totalDistance = gpsService.totalDistance
            session.routePoints = gpsService.routePoints
            
            // Add any remaining paused time
            if let pauseStart = pauseStartTime {
                let pausedTime = Date().timeIntervalSince(pauseStart)
                session.pausedDuration += pausedTime
                pauseStartTime = nil
            }
            
            currentSession = session
        }
        
        state = .completed
        isAutopaused = false
        
        print("✅ Recording completed successfully")
        print("📊 Final stats:")
        print("   - Distance: \(String(format: "%.2f", currentSession?.totalDistanceMiles ?? 0)) miles")
        print("   - Time: \(String(format: "%.0f", currentSession?.elapsedTime ?? 0)) seconds")
        print("   - Average pace: \(String(format: "%.1f", currentSession?.averagePace ?? 0)) min/mile")
    }
    
    func discardRecording() {
        print("🗑️ Discarding activity recording")
        
        gpsService.stopTracking()
        gpsService.clearRoute()
        currentSession = nil
        state = .ready
        isAutopaused = false
        pauseStartTime = nil
        lowSpeedStartTime = nil
        
        print("✅ Recording discarded")
    }
    
    func saveActivity() async throws -> Activity? {
        guard let session = currentSession,
              state == .completed,
              !session.routePoints.isEmpty else {
            throw RecordingError.invalidSession
        }

        print("💾 Saving recorded activity to database")

        // Get user ID
        guard let userId = UserSession.shared.userId else {
            throw RecordingError.noUser
        }

        // Perform heavy polyline encoding on background thread
        let activityData = await Task.detached(priority: .userInitiated) { [session] in
            // Generate polyline from route points
            let polylineService = PolylineEncodingService()
            let coordinates = session.routePoints.map { $0.coordinate }
            let encodedPolyline = polylineService.encode(coordinates: coordinates)

            // Create activity for database
            return [
                "athlete_id": AnyEncodable(userId),
                "name": AnyEncodable(session.name),
                "type": AnyEncodable(session.activityType),
                "distance": AnyEncodable(session.totalDistance),
                "elapsed_time": AnyEncodable(session.elapsedTime),
                "start_date": AnyEncodable(session.startTime),
                "summary_polyline": AnyEncodable(encodedPolyline)
            ]
        }.value

        // Save to Supabase
        let savedActivity = try await ActivityService.createActivity(data: activityData)

        print("✅ Activity saved successfully with ID: \(savedActivity.id)")

        // Refresh widgets after activity recording save
        WidgetRefreshService.refreshForActivityUpdate()

        // Clear session after successful save
        await MainActor.run {
            discardRecording()
        }

        return savedActivity
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Monitor GPS data changes
        gpsService.$totalDistance
            .sink { [weak self] distance in
                self?.updateSessionData()
            }
            .store(in: &cancellables)
        
        gpsService.$currentSpeed
            .sink { [weak self] speed in
                self?.checkForAutopause(speed: speed)
            }
            .store(in: &cancellables)
    }
    
    private func updateSessionData() {
        guard var session = currentSession else { return }
        
        session.totalDistance = gpsService.totalDistance
        session.routePoints = gpsService.routePoints
        
        currentSession = session
    }
    
    private func checkForAutopause(speed: Double) {
        guard state == .recording, !isAutopaused else { return }
        
        // Check if speed is below threshold
        if speed < autoPauseThreshold {
            if lowSpeedStartTime == nil {
                lowSpeedStartTime = Date()
            } else if let startTime = lowSpeedStartTime,
                      Date().timeIntervalSince(startTime) >= autoPauseDelay {
                // Auto-pause triggered
                print("⏸️ Auto-pause triggered - low speed detected")
                gpsService.pauseTracking()
                isAutopaused = true
                pauseStartTime = Date()
                lowSpeedStartTime = nil
            }
        } else {
            // Speed above threshold
            if isAutopaused {
                print("▶️ Auto-resume triggered - movement detected")
                if let pauseStart = pauseStartTime {
                    let pausedTime = Date().timeIntervalSince(pauseStart)
                    currentSession?.pausedDuration += pausedTime
                    pauseStartTime = nil
                }
                gpsService.resumeTracking()
                isAutopaused = false
            }
            lowSpeedStartTime = nil
        }
    }
    
    private func generateDefaultName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d 'at' h:mm a"
        return "Run on \(formatter.string(from: Date()))"
    }
}

// MARK: - Recording Error
enum RecordingError: LocalizedError {
    case invalidSession
    case noUser
    case saveFailure(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidSession:
            return "Invalid recording session"
        case .noUser:
            return "No authenticated user"
        case .saveFailure(let message):
            return "Failed to save activity: \(message)"
        }
    }
}

// MARK: - CLAuthorizationStatus Extension
extension CLAuthorizationStatus {
    var isAuthorized: Bool {
        return self == .authorizedWhenInUse || self == .authorizedAlways
    }
}