//
//  CadenceAssessmentService.swift
//  Runaway iOS
//
//  Created by Claude on 1/12/26.
//

import Foundation
import CoreMotion
import Combine

// MARK: - Cadence Assessment Service

@MainActor
final class CadenceAssessmentService: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var isRunning = false
    @Published private(set) var currentCadence: Double = 0
    @Published private(set) var progress: Double = 0
    @Published private(set) var stepCount: Int = 0
    @Published private(set) var testResult: MovementTestResult?
    @Published private(set) var errorMessage: String?

    // MARK: - Private Properties

    private let motionManager = CMMotionManager()
    private let pedometer = CMPedometer()
    private var startTime: Date?
    private var cadenceSamples: [Double] = []
    private var timer: Timer?

    private let testDuration: TimeInterval = 30 // 30 seconds

    // MARK: - Singleton

    static let shared = CadenceAssessmentService()

    private init() {}

    // MARK: - Check Availability

    var isAvailable: Bool {
        return CMPedometer.isStepCountingAvailable() || motionManager.isAccelerometerAvailable
    }

    var availabilityMessage: String {
        if CMPedometer.isStepCountingAvailable() {
            return "Step counting is available"
        } else if motionManager.isAccelerometerAvailable {
            return "Using accelerometer for estimation"
        } else {
            return "Motion sensors not available"
        }
    }

    // MARK: - Start Test

    func startTest() {
        guard !isRunning else { return }

        // Reset state
        isRunning = true
        currentCadence = 0
        progress = 0
        stepCount = 0
        testResult = nil
        errorMessage = nil
        cadenceSamples = []
        startTime = Date()

        // Start appropriate sensor
        if CMPedometer.isStepCountingAvailable() {
            startPedometerTest()
        } else if motionManager.isAccelerometerAvailable {
            startAccelerometerTest()
        } else {
            errorMessage = "No motion sensors available"
            isRunning = false
            return
        }

        // Start progress timer
        startProgressTimer()
    }

    // MARK: - Stop Test

    func stopTest() {
        isRunning = false

        // Stop sensors
        pedometer.stopUpdates()
        motionManager.stopAccelerometerUpdates()

        // Stop timer
        timer?.invalidate()
        timer = nil

        // Calculate results if we have data
        if !cadenceSamples.isEmpty {
            calculateResults()
        }
    }

    // MARK: - Cancel Test

    func cancelTest() {
        isRunning = false
        pedometer.stopUpdates()
        motionManager.stopAccelerometerUpdates()
        timer?.invalidate()
        timer = nil

        // Reset state
        currentCadence = 0
        progress = 0
        stepCount = 0
        cadenceSamples = []
    }

    // MARK: - Private Methods

    private func startPedometerTest() {
        guard let start = startTime else { return }

        pedometer.startUpdates(from: start) { [weak self] data, error in
            guard let self = self, let data = data else {
                if let error = error {
                    Task { @MainActor in
                        self?.errorMessage = error.localizedDescription
                    }
                }
                return
            }

            Task { @MainActor in
                self.processPedometerData(data)
            }
        }
    }

    private func processPedometerData(_ data: CMPedometerData) {
        guard let start = startTime else { return }

        let steps = data.numberOfSteps.intValue
        let elapsed = Date().timeIntervalSince(start)

        // Calculate cadence (steps per minute)
        if elapsed > 0 {
            let cadence = Double(steps) / elapsed * 60
            currentCadence = cadence
            stepCount = steps

            // Store sample every 2 seconds
            if elapsed.truncatingRemainder(dividingBy: 2) < 0.5 {
                cadenceSamples.append(cadence)
            }
        }
    }

    private func startAccelerometerTest() {
        motionManager.accelerometerUpdateInterval = 0.02 // 50 Hz

        var stepDetector = AccelerometerStepDetector()

        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self = self, let data = data else { return }

            Task { @MainActor in
                if stepDetector.processAccelerometerData(data) {
                    self.stepCount += 1
                    self.updateCadenceFromSteps()
                }
            }
        }
    }

    private func updateCadenceFromSteps() {
        guard let start = startTime else { return }

        let elapsed = Date().timeIntervalSince(start)
        if elapsed > 0 {
            let cadence = Double(stepCount) / elapsed * 60
            currentCadence = cadence

            // Store sample
            if cadenceSamples.count < Int(elapsed / 2) {
                cadenceSamples.append(cadence)
            }
        }
    }

    private func startProgressTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.startTime else { return }

            Task { @MainActor in
                let elapsed = Date().timeIntervalSince(start)
                self.progress = min(elapsed / self.testDuration, 1.0)

                // Auto-stop when complete
                if elapsed >= self.testDuration {
                    self.stopTest()
                }
            }
        }
    }

    private func calculateResults() {
        guard let start = startTime else { return }

        let elapsed = Date().timeIntervalSince(start)

        // Calculate average cadence
        let averageCadence: Double
        if !cadenceSamples.isEmpty {
            averageCadence = cadenceSamples.reduce(0, +) / Double(cadenceSamples.count)
        } else if elapsed > 0 {
            averageCadence = Double(stepCount) / elapsed * 60
        } else {
            averageCadence = 0
        }

        // Calculate variance
        let variance: Double
        if cadenceSamples.count > 1 {
            let mean = averageCadence
            let sumSquaredDiff = cadenceSamples.reduce(0) { $0 + pow($1 - mean, 2) }
            variance = sqrt(sumSquaredDiff / Double(cadenceSamples.count - 1))
        } else {
            variance = 0
        }

        testResult = MovementTestResult(
            averageCadence: averageCadence,
            variance: variance,
            testDuration: elapsed,
            sampleCount: cadenceSamples.count
        )
    }
}

// MARK: - Accelerometer Step Detector

private struct AccelerometerStepDetector {
    private var previousMagnitude: Double = 0
    private var stepThreshold: Double = 1.2
    private var isStepPending = false
    private var lastStepTime: Date?
    private let minimumStepInterval: TimeInterval = 0.25 // Max 240 steps/min

    mutating func processAccelerometerData(_ data: CMAccelerometerData) -> Bool {
        let magnitude = sqrt(
            pow(data.acceleration.x, 2) +
            pow(data.acceleration.y, 2) +
            pow(data.acceleration.z, 2)
        )

        // Detect step on downward crossing after peak
        var stepDetected = false

        if magnitude > stepThreshold && !isStepPending {
            isStepPending = true
        } else if magnitude < stepThreshold && isStepPending {
            // Check minimum interval
            let now = Date()
            if let lastStep = lastStepTime {
                if now.timeIntervalSince(lastStep) >= minimumStepInterval {
                    stepDetected = true
                    lastStepTime = now
                }
            } else {
                stepDetected = true
                lastStepTime = now
            }
            isStepPending = false
        }

        previousMagnitude = magnitude
        return stepDetected
    }
}
