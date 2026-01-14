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
import ActivityKit
import HealthKit

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
    private var liveActivityUpdateTimer: Timer?

    // MARK: - HealthKit Integration
    private let healthKitWorkoutService = HealthKitWorkoutService.shared
    private var savedHealthKitWorkout: HKWorkout?
    
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

        // Track analytics
        AnalyticsService.shared.trackActivityStarted(type: activityType, name: name)

        // Create new session
        currentSession = RecordingSession(
            startTime: Date(),
            name: name.isEmpty ? generateDefaultName(for: activityType) : name,
            activityType: activityType
        )

        // Start GPS tracking
        gpsService.startTracking()

        // Update state
        state = .recording
        isAutopaused = false
        lowSpeedStartTime = nil

        // Start Live Activity
        LiveActivityService.shared.startActivity(
            activityType: activityType,
            startTime: Date()
        )
        startLiveActivityUpdates()

        // Start HealthKit workout session if authorized
        if HealthKitManager.shared.isAuthorized {
            Task {
                do {
                    let hkActivityType = HealthKitManager.shared.workoutActivityType(for: activityType)
                    try await healthKitWorkoutService.startWorkout(activityType: hkActivityType)
                    print("✅ HealthKit workout session started")
                } catch {
                    print("⚠️ Failed to start HealthKit workout: \(error.localizedDescription)")
                }
            }
        }

        print("✅ Recording started successfully")
    }
    
    func pauseRecording() {
        guard canPauseRecording else {
            print("❌ Cannot pause recording - invalid state")
            return
        }

        print("⏸️ Pausing activity recording")

        // Track analytics
        AnalyticsService.shared.track(.activityPaused, category: .activity, properties: [
            "elapsed_time": currentSession?.elapsedTime ?? 0,
            "distance": gpsService.totalDistance
        ])

        gpsService.pauseTracking()
        state = .paused
        pauseStartTime = Date()
        isAutopaused = false

        // Update Live Activity to show paused state
        updateLiveActivityState(isPaused: true)

        // Pause HealthKit workout
        healthKitWorkoutService.pauseWorkout()
    }
    
    func resumeRecording() {
        guard canResumeRecording else {
            print("❌ Cannot resume recording - invalid state")
            return
        }

        print("▶️ Resuming activity recording")

        // Track analytics
        AnalyticsService.shared.track(.activityResumed, category: .activity, properties: [
            "paused_duration": pauseStartTime.map { Date().timeIntervalSince($0) } ?? 0
        ])

        // Add paused time to total
        if let pauseStart = pauseStartTime {
            let pausedTime = Date().timeIntervalSince(pauseStart)
            currentSession?.pausedDuration += pausedTime
            pauseStartTime = nil
        }

        gpsService.resumeTracking()
        state = .recording
        isAutopaused = false

        // Update Live Activity to show active state
        updateLiveActivityState(isPaused: false)

        // Resume HealthKit workout
        healthKitWorkoutService.resumeWorkout()
    }
    
    func stopRecording() {
        guard canStopRecording else {
            print("❌ Cannot stop recording - invalid state")
            return
        }

        print("⏹️ Stopping activity recording")

        // Track analytics
        AnalyticsService.shared.track(.activityStopped, category: .activity, properties: [
            "elapsed_time": currentSession?.elapsedTime ?? 0,
            "distance": gpsService.totalDistance,
            "activity_type": currentSession?.activityType ?? "unknown"
        ])

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

        // Stop Live Activity updates and show summary
        stopLiveActivityUpdates()
        if let session = currentSession {
            LiveActivityService.shared.endActivityWithSummary(
                elapsedTime: session.elapsedTime,
                distance: session.totalDistance,
                averagePace: session.averagePace * 60 // Convert to seconds per mile
            )
        } else {
            LiveActivityService.shared.endActivity()
        }

        // End HealthKit workout session and save
        if healthKitWorkoutService.isRecording, let session = currentSession {
            Task {
                do {
                    // Convert route points to CLLocation
                    let locations = session.routePoints.map { point in
                        CLLocation(
                            coordinate: point.coordinate,
                            altitude: point.altitude,
                            horizontalAccuracy: point.horizontalAccuracy,
                            verticalAccuracy: point.horizontalAccuracy,
                            timestamp: point.timestamp
                        )
                    }

                    savedHealthKitWorkout = try await healthKitWorkoutService.endWorkout(
                        totalDistance: session.totalDistance,
                        totalDuration: session.elapsedTime,
                        routeLocations: locations
                    )
                    print("✅ HealthKit workout saved")
                } catch {
                    print("⚠️ Failed to save HealthKit workout: \(error.localizedDescription)")
                }
            }
        }

        print("✅ Recording completed successfully")
        print("📊 Final stats:")
        print("   - Distance: \(String(format: "%.2f", currentSession?.totalDistanceMiles ?? 0)) miles")
        print("   - Time: \(String(format: "%.0f", currentSession?.elapsedTime ?? 0)) seconds")
        print("   - Average pace: \(String(format: "%.1f", currentSession?.averagePace ?? 0)) min/mile")
    }
    
    func discardRecording() {
        print("🗑️ Discarding activity recording")

        // Track analytics
        AnalyticsService.shared.track(.activityDiscarded, category: .activity, properties: [
            "elapsed_time": currentSession?.elapsedTime ?? 0,
            "distance": gpsService.totalDistance,
            "activity_type": currentSession?.activityType ?? "unknown"
        ])

        gpsService.stopTracking()
        gpsService.clearRoute()
        currentSession = nil
        state = .ready
        isAutopaused = false
        pauseStartTime = nil
        lowSpeedStartTime = nil
        savedHealthKitWorkout = nil

        // End Live Activity
        stopLiveActivityUpdates()
        LiveActivityService.shared.endActivity()

        // Cancel HealthKit workout without saving
        healthKitWorkoutService.cancelWorkout()

        print("✅ Recording discarded")
    }
    
    func saveActivity() async throws -> Activity? {
        guard let session = currentSession,
              state == .completed else {
            throw RecordingError.invalidSession
        }

        print("💾 Saving recorded activity to database")

        // Get user ID
        guard let userId = UserSession.shared.userId else {
            throw RecordingError.noUser
        }

        // Capture GPS data from service before background task
        let routePoints = gpsService.routePoints
        let maxSpeed = gpsService.maxSpeed
        let averageSpeed = gpsService.averageSpeed
        let elevationGain = gpsService.elevationGain
        let elevationLoss = gpsService.elevationLoss
        let elevationHigh = gpsService.elevationHigh
        let elevationLow = gpsService.elevationLow

        // Perform heavy polyline encoding on background thread
        let activityData = await Task.detached(priority: .userInitiated) { [session, routePoints, maxSpeed, averageSpeed, elevationGain, elevationLoss, elevationHigh, elevationLow] in
            // Generate polylines from route points
            let polylineService = PolylineEncodingService()
            let coordinates = routePoints.map { $0.coordinate }
            let encodedPolyline = polylineService.encode(coordinates: coordinates)

            // Get activity type ID from database IDs
            let activityTypeId: Int
            switch session.activityType.lowercased() {
            case "run": activityTypeId = 103
            case "ride", "bike": activityTypeId = 104
            case "walk": activityTypeId = 105
            case "hike": activityTypeId = 106
            case "swim": activityTypeId = 109
            case "workout": activityTypeId = 110
            case "weight training", "weighttraining": activityTypeId = 111
            case "yoga": activityTypeId = 112
            default: activityTypeId = 103 // Default to Run
            }

            // Format dates as ISO 8601 for PostgreSQL timestamp
            let iso8601Formatter = ISO8601DateFormatter()
            iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let activityDateString = iso8601Formatter.string(from: session.startTime)
            let startTimeString = iso8601Formatter.string(from: session.startTime)

            // Calculate moving time (elapsed minus paused)
            let movingTime = Int(session.elapsedTime - session.pausedDuration)

            // Get start/end coordinates from route points
            let startLat = routePoints.first?.coordinate.latitude
            let startLon = routePoints.first?.coordinate.longitude
            let endLat = routePoints.last?.coordinate.latitude
            let endLon = routePoints.last?.coordinate.longitude

            // Estimate calories based on activity type and duration
            // Simple estimation: ~100 cal/mile for running, ~50 for walking
            let distanceMiles = session.totalDistance * 0.000621371
            let calories: Int?
            switch session.activityType.lowercased() {
            case "run":
                calories = Int(distanceMiles * 100)
            case "walk":
                calories = Int(distanceMiles * 50)
            case "ride", "bike":
                calories = Int(distanceMiles * 40)
            default:
                // Estimate based on duration: ~5 cal/min for moderate activity
                calories = Int(session.elapsedTime / 60 * 5)
            }

            // Estimate steps for runs/walks (~1,400 steps per mile running, ~2,000 walking)
            let totalSteps: Int?
            switch session.activityType.lowercased() {
            case "run":
                totalSteps = Int(distanceMiles * 1400)
            case "walk", "hike":
                totalSteps = Int(distanceMiles * 2000)
            default:
                totalSteps = nil
            }

            // Build activity data dictionary
            // Schema reference: activities table in strava_erd.md
            // Note: id is omitted - database will auto-generate via sequence
            var data: [String: AnyEncodable] = [
                // Required fields
                "athlete_id": AnyEncodable(userId),
                "name": AnyEncodable(session.name),
                "activity_type_id": AnyEncodable(activityTypeId),
                "activity_date": AnyEncodable(activityDateString),
                "elapsed_time": AnyEncodable(Int(session.elapsedTime)),
                "distance": AnyEncodable(session.totalDistance),

                // Source/type flags
                "source": AnyEncodable("manual"),
                "manual": AnyEncodable(true),

                // Timing
                "start_time": AnyEncodable(startTimeString),
                "moving_time": AnyEncodable(movingTime),

                // Polylines (use same encoded polyline for both - summary can be simplified later)
                "map_summary_polyline": AnyEncodable(encodedPolyline),
                "map_polyline": AnyEncodable(encodedPolyline),

                // Speed (in m/s)
                "average_speed": AnyEncodable(averageSpeed),
                "max_speed": AnyEncodable(maxSpeed),

                // Device info
                "device_name": AnyEncodable("Runaway iOS")
            ]

            // Add GPS coordinates if available
            if let lat = startLat, let lon = startLon {
                data["start_latitude"] = AnyEncodable(lat)
                data["start_longitude"] = AnyEncodable(lon)
            }
            if let lat = endLat, let lon = endLon {
                data["end_latitude"] = AnyEncodable(lat)
                data["end_longitude"] = AnyEncodable(lon)
            }

            // Add elevation data if we have valid readings
            if elevationHigh > -Double.greatestFiniteMagnitude {
                data["elevation_high"] = AnyEncodable(elevationHigh)
            }
            if elevationLow < Double.greatestFiniteMagnitude {
                data["elevation_low"] = AnyEncodable(elevationLow)
            }
            if elevationGain > 0 {
                data["elevation_gain"] = AnyEncodable(elevationGain)
            }
            if elevationLoss > 0 {
                data["elevation_loss"] = AnyEncodable(elevationLoss)
            }

            // Add estimated calories
            if let cal = calories, cal > 0 {
                data["calories"] = AnyEncodable(cal)
            }

            // Add estimated steps for applicable activities
            if let steps = totalSteps, steps > 0 {
                data["total_steps"] = AnyEncodable(steps)
            }

            return data
        }.value

        // Save to Supabase
        let savedActivity = try await ActivityService.createActivity(data: activityData)

        print("✅ Activity saved successfully with ID: \(savedActivity.id)")

        // Track analytics
        AnalyticsService.shared.trackActivitySaved(
            type: session.activityType,
            distance: session.totalDistance,
            duration: session.elapsedTime
        )

        // Refresh widgets after activity recording save
        WidgetRefreshService.refreshForActivityUpdate()

        // Add to activity store to trigger commitment check
        await MainActor.run {
            ActivityStore.shared.addActivity(savedActivity)
        }

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

        // Forward GPS locations to HealthKit for real-time route building
        gpsService.$currentLocation
            .compactMap { $0 }
            .sink { [weak self] location in
                guard let self = self,
                      self.state == .recording,
                      self.healthKitWorkoutService.isRecording else { return }
                self.healthKitWorkoutService.addLocationSample(location)
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
    
    private func generateDefaultName(for activityType: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d 'at' h:mm a"
        return "\(activityType) on \(formatter.string(from: Date()))"
    }

    // MARK: - Live Activity Helpers

    private func startLiveActivityUpdates() {
        // Update Live Activity every second
        liveActivityUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateLiveActivity()
            }
        }
    }

    private func stopLiveActivityUpdates() {
        liveActivityUpdateTimer?.invalidate()
        liveActivityUpdateTimer = nil
    }

    private func updateLiveActivity() {
        guard let session = currentSession else { return }

        // Calculate current pace in seconds per mile
        let currentPaceSecondsPerMile: Double
        if gpsService.currentSpeed > 0.5 { // Above threshold
            let milesPerSecond = gpsService.currentSpeed / 1609.34
            currentPaceSecondsPerMile = milesPerSecond > 0 ? 1.0 / milesPerSecond : 0
        } else {
            currentPaceSecondsPerMile = 0
        }

        // Calculate average pace in seconds per mile
        let averagePaceSecondsPerMile = session.averagePace * 60 // Convert min/mile to sec/mile

        LiveActivityService.shared.updateActivity(
            elapsedTime: session.elapsedTime,
            distance: gpsService.totalDistance,
            currentPace: currentPaceSecondsPerMile,
            averagePace: averagePaceSecondsPerMile,
            isPaused: state == .paused || isAutopaused
        )
    }

    private func updateLiveActivityState(isPaused: Bool) {
        guard let session = currentSession else { return }

        let averagePaceSecondsPerMile = session.averagePace * 60

        LiveActivityService.shared.updateActivity(
            elapsedTime: session.elapsedTime,
            distance: gpsService.totalDistance,
            currentPace: 0, // Current pace is 0 when paused
            averagePace: averagePaceSecondsPerMile,
            isPaused: isPaused
        )
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