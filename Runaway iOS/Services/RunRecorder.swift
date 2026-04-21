//
//  RunRecorder.swift
//  Runaway iOS
//
//  Drives a live run: owns a dedicated high-accuracy CLLocationManager,
//  publishes live distance / time / pace for UI, and feeds filtered
//  locations into HealthKitWorkoutService (which in turn drives the
//  audio coach scheduler).
//

import Foundation
import CoreLocation
import HealthKit

// MARK: - Run Recorder

/// Records a live run. Separate from the general-purpose `LocationManager`
/// because fitness recording needs high accuracy (~5m), `.fitness` activity
/// type, and an independent lifecycle tied to the run — not the app's
/// geocoding flow.
///
/// Background note: this recorder does not enable background location
/// updates. Add `locationManager.allowsBackgroundLocationUpdates = true`
/// plus `.authorizedAlways` authorization and the "location" background
/// mode in Signing & Capabilities when you want screen-locked runs to
/// keep recording.
@MainActor
final class RunRecorder: NSObject, ObservableObject, CLLocationManagerDelegate {

    // MARK: - Published State

    @Published var isRecording: Bool = false
    @Published var distanceMeters: Double = 0
    @Published var elapsedSeconds: TimeInterval = 0
    /// Rolling 30-second pace, in seconds per meter. 0 means "not yet available".
    @Published var currentPaceSecondsPerMeter: Double = 0
    @Published var errorMessage: String?

    // MARK: - Private State

    private let locationManager = CLLocationManager()
    private var timer: Timer?
    private var startDate: Date?
    private var lastLocation: CLLocation?
    /// Sliding window of (totalDistance, timestamp) pairs used to compute
    /// a rolling pace. Samples older than 30s are dropped.
    private var paceWindow: [(distance: Double, time: Date)] = []

    // Filter thresholds for ignoring bad GPS samples
    private let maxHorizontalAccuracyMeters: CLLocationAccuracy = 30
    private let maxSampleAgeSeconds: TimeInterval = 5
    private let paceWindowSeconds: TimeInterval = 30

    // MARK: - Initialization

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.activityType = .fitness
        locationManager.distanceFilter = 5
    }

    // MARK: - Lifecycle

    /// Start a run. Requests location permission if needed, starts the
    /// HealthKit workout, and begins streaming location updates.
    func start() async {
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }

        guard
            locationManager.authorizationStatus == .authorizedWhenInUse ||
            locationManager.authorizationStatus == .authorizedAlways
        else {
            errorMessage = "Location permission is required to record a run."
            return
        }

        do {
            try await HealthKitWorkoutService.shared.startWorkout(activityType: .running)
        } catch {
            errorMessage = "Couldn't start workout: \(error.localizedDescription)"
            return
        }

        distanceMeters = 0
        elapsedSeconds = 0
        currentPaceSecondsPerMeter = 0
        startDate = Date()
        lastLocation = nil
        paceWindow = []
        errorMessage = nil

        locationManager.startUpdatingLocation()
        startTimer()
        isRecording = true

        AnalyticsService.shared.trackActivityStarted(type: "running", name: "Live run")
    }

    /// Stop the run and persist it to HealthKit.
    func stop() async {
        guard isRecording else { return }

        let finalDistance = distanceMeters
        let finalDuration = elapsedSeconds

        stopStreaming()

        do {
            _ = try await HealthKitWorkoutService.shared.endWorkout(
                totalDistance: finalDistance,
                totalDuration: finalDuration,
                routeLocations: []
            )
            AnalyticsService.shared.trackActivitySaved(
                type: "running",
                distance: finalDistance,
                duration: finalDuration
            )
        } catch {
            errorMessage = "Couldn't save workout: \(error.localizedDescription)"
        }
    }

    /// Abort the run without saving.
    func cancel() {
        guard isRecording else { return }
        stopStreaming()
        HealthKitWorkoutService.shared.cancelWorkout()
    }

    private func stopStreaming() {
        isRecording = false
        locationManager.stopUpdatingLocation()
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Elapsed-Time Timer

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let start = self.startDate else { return }
                self.elapsedSeconds = Date().timeIntervalSince(start)
            }
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        let captured = locations
        Task { @MainActor in
            self.handleLocations(captured)
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        Task { @MainActor in
            self.errorMessage = "Location error: \(error.localizedDescription)"
        }
    }

    private func handleLocations(_ locations: [CLLocation]) {
        guard isRecording else { return }

        for location in locations {
            // Reject samples that are too inaccurate or too old — these
            // are the GPS glitches that bloat distance with jitter.
            guard location.horizontalAccuracy > 0,
                  location.horizontalAccuracy <= maxHorizontalAccuracyMeters,
                  abs(location.timestamp.timeIntervalSinceNow) < maxSampleAgeSeconds
            else {
                continue
            }

            if let previous = lastLocation {
                let delta = location.distance(from: previous)
                distanceMeters += delta
            }
            lastLocation = location

            // Keep the sliding window for pace
            paceWindow.append((distance: distanceMeters, time: location.timestamp))
            paceWindow.removeAll { location.timestamp.timeIntervalSince($0.time) > paceWindowSeconds }
            updateRollingPace()

            // Feed the HealthKit recorder. That service also forwards to
            // RunCoachScheduler for the audio coach.
            HealthKitWorkoutService.shared.addLocationSample(location)
        }
    }

    private func updateRollingPace() {
        guard let oldest = paceWindow.first,
              let newest = paceWindow.last,
              newest.distance > oldest.distance
        else {
            return
        }
        let seconds = newest.time.timeIntervalSince(oldest.time)
        let meters = newest.distance - oldest.distance
        guard seconds > 0, meters > 0 else { return }
        currentPaceSecondsPerMeter = seconds / meters
    }
}
