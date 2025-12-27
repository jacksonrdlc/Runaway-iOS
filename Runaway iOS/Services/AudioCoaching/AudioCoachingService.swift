//
//  AudioCoachingService.swift
//  Runaway iOS
//
//  Created by Claude on 12/23/25.
//

import Foundation
import Combine

// MARK: - Audio Coaching Service

/// Main coordinator for audio coaching during runs
/// Observes ActivityRecordingService and feeds state to TriggerEngine
@MainActor
final class AudioCoachingService: ObservableObject {

    // MARK: - Published State

    @Published private(set) var isActive: Bool = false
    @Published private(set) var lastPromptMessage: String?
    @Published private(set) var lastPromptTime: Date?
    @Published var isEnabled: Bool = true
    @Published private(set) var isListening: Bool = false

    // MARK: - Components

    private var triggerEngine: TriggerEngine!
    private var splitTracker: SplitTracker!
    private var voiceCoordinator: VoiceCoachingCoordinator!
    private var shakeDetector: ShakeGestureDetector!
    private var settings: CoachSettings { CoachSettingsStore.shared.settings }

    // MARK: - Subscriptions

    private var cancellables = Set<AnyCancellable>()
    private var recordingService: ActivityRecordingService?

    // MARK: - Initialization

    init() {
        // Defer initialization to avoid @MainActor isolation issues
        self.triggerEngine = TriggerEngine()
        self.splitTracker = SplitTracker(unit: settings.distanceUnit)
        self.voiceCoordinator = VoiceCoachingCoordinator()
        self.shakeDetector = ShakeGestureDetector()

        setupCallbacks()
        setupVoiceHandlers()
    }

    // MARK: - Setup

    private func setupCallbacks() {
        // Track when prompts are spoken
        triggerEngine.onPromptSpoken = { [weak self] prompt in
            guard let self = self else { return }
            self.lastPromptMessage = prompt.message
            self.lastPromptTime = Date()

            // Auto-listen after check-in prompts if enabled
            if prompt.expectsResponse &&
               self.settings.enableVoiceInput &&
               self.settings.autoListenAfterCheckIn {
                self.voiceCoordinator.expectResponse(to: prompt)
            }
        }

        // Track split completions
        splitTracker.onSplitCompleted = { [weak self] split in
            #if DEBUG
            print("AudioCoaching: Split \(split.splitNumber) completed - \(split.formattedPace) pace")
            #endif
        }
    }

    private func setupVoiceHandlers() {
        // Handle voice commands
        voiceCoordinator.onCommand = { [weak self] intent in
            self?.handleVoiceCommand(intent)
        }

        // Provide stats when requested by voice
        voiceCoordinator.onStatsRequest = { [weak self] intent in
            self?.generateStatsResponse(for: intent)
        }

        // Shake to activate voice input (disabled by default)
        shakeDetector.onShake = { [weak self] in
            guard let self = self,
                  self.isActive,
                  self.settings.enableVoiceInput,
                  self.settings.enableShakeToSpeak else { return }
            Task { @MainActor in
                await self.voiceCoordinator.startListening()
            }
        }

        // Sync listening state
        voiceCoordinator.$isListening
            .receive(on: DispatchQueue.main)
            .sink { [weak self] listening in
                self?.isListening = listening
            }
            .store(in: &cancellables)
    }

    // MARK: - Voice Command Handling

    private func handleVoiceCommand(_ intent: VoiceIntent) {
        guard let service = recordingService else { return }

        switch intent {
        case .pause:
            service.pauseRecording()

        case .resume:
            service.resumeRecording()

        case .stop:
            service.stopRecording()

        case .mute:
            isEnabled = false

        case .unmute:
            isEnabled = true

        default:
            break
        }
    }

    private func generateStatsResponse(for intent: VoiceIntent) -> String? {
        guard let service = recordingService,
              let session = service.currentSession else { return nil }

        let distance = service.gpsService.totalDistance
        let distanceMiles = distance / 1609.34
        let elapsedTime = session.elapsedTime

        switch intent {
        case .requestPace:
            let pace = elapsedTime > 0 && distance > 0
                ? elapsedTime / (distance / 1609.34)
                : 0
            let paceString = formatPace(pace)
            return "Current average pace is \(paceString) per mile."

        case .requestDistance:
            return String(format: "You've covered %.2f miles.", distanceMiles)

        case .requestTime:
            let timeString = formatTime(elapsedTime)
            return "Elapsed time is \(timeString)."

        case .requestHeartRate:
            // Would need heart rate integration
            return nil

        case .requestStats:
            let pace = elapsedTime > 0 && distance > 0
                ? elapsedTime / (distance / 1609.34)
                : 0
            let paceString = formatPace(pace)
            let timeString = formatTime(elapsedTime)
            return String(format: "%.2f miles in %@. Average pace %@ per mile.", distanceMiles, timeString, paceString)

        default:
            return nil
        }
    }

    private func formatPace(_ pace: TimeInterval) -> String {
        guard pace > 0 else { return "zero" }
        let minutes = Int(pace) / 60
        let seconds = Int(pace) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60

        if hours > 0 {
            return "\(hours) hours \(minutes) minutes"
        } else if minutes > 0 {
            return "\(minutes) minutes \(seconds) seconds"
        } else {
            return "\(seconds) seconds"
        }
    }

    // MARK: - Binding to Recording Service

    /// Bind to an ActivityRecordingService to observe run state
    func bind(to recordingService: ActivityRecordingService) {
        self.recordingService = recordingService

        // Cancel any existing subscriptions
        cancellables.removeAll()

        // Subscribe to recording state changes
        recordingService.$state
            .sink { [weak self] state in
                self?.handleRecordingStateChange(state)
            }
            .store(in: &cancellables)

        // Subscribe to GPS service updates
        recordingService.gpsService.$totalDistance
            .combineLatest(recordingService.gpsService.$currentSpeed)
            .sink { [weak self] distance, speed in
                self?.handleDistanceUpdate(distance: distance, speed: speed)
            }
            .store(in: &cancellables)
    }

    /// Unbind from recording service
    func unbind() {
        cancellables.removeAll()
        recordingService = nil
    }

    // MARK: - State Change Handlers

    private func handleRecordingStateChange(_ state: RecordingState) {
        switch state {
        case .ready:
            // Reset for new run
            reset()

        case .recording:
            if !isActive {
                start()
            } else {
                // Resuming from pause
                triggerEngine.resume()
            }

        case .paused:
            triggerEngine.pause()

        case .completed:
            stop()
        }
    }

    private func handleDistanceUpdate(distance: Double, speed: Double) {
        guard isActive, isEnabled, settings.isEnabled else { return }
        guard let service = recordingService,
              let session = service.currentSession else { return }

        // Calculate current pace (seconds per mile)
        let currentPace: TimeInterval
        if speed > 0.1 {
            // Convert m/s to seconds per mile
            currentPace = 1609.34 / speed
        } else {
            currentPace = 0
        }

        // Update split tracker
        splitTracker.update(totalDistance: distance, currentPace: currentPace)

        // Build state snapshot
        let state = buildStateSnapshot(
            session: session,
            distance: distance,
            speed: speed,
            currentPace: currentPace
        )

        // Feed to trigger engine
        triggerEngine.updateState(state)
    }

    // MARK: - State Snapshot Building

    private func buildStateSnapshot(
        session: RecordingSession,
        distance: Double,
        speed: Double,
        currentPace: TimeInterval
    ) -> RunStateSnapshot {
        // Calculate average pace
        let averagePace: TimeInterval
        if session.elapsedTime > 0 && distance > 0 {
            // Average pace in seconds per mile
            averagePace = session.elapsedTime / (distance / 1609.34)
        } else {
            averagePace = currentPace
        }

        return RunStateSnapshot(
            elapsedTime: session.elapsedTime,
            isPaused: recordingService?.state == .paused,
            totalDistance: distance,
            currentPace: currentPace,
            averagePace: averagePace,
            targetPace: settings.targetPace,
            completedSplits: splitTracker.splits.count,
            lastSplitPace: splitTracker.lastSplit?.pace,
            currentSpeed: speed,
            currentHeartRate: nil, // Phase 2: HeartRateService
            currentZone: nil,
            previousZone: nil,
            timeInCurrentZone: nil,
            distanceUnit: settings.distanceUnit
        )
    }

    // MARK: - Control Methods

    /// Start audio coaching
    func start() {
        guard !isActive else { return }

        isActive = true
        triggerEngine.start()

        print("AudioCoachingService: Started")
    }

    /// Stop audio coaching
    func stop() {
        guard isActive else { return }

        isActive = false
        triggerEngine.stop()

        print("AudioCoachingService: Stopped")
    }

    /// Reset for new run
    func reset() {
        stop()
        splitTracker.reset()
        voiceCoordinator.reset()
        lastPromptMessage = nil
        lastPromptTime = nil
    }

    // MARK: - Voice Input

    /// Manually start voice input (e.g., from button press)
    func startVoiceInput() async {
        guard isActive, settings.enableVoiceInput else { return }
        await voiceCoordinator.startListening()
    }

    /// Stop voice input
    func stopVoiceInput() {
        voiceCoordinator.stopListening()
    }

    /// Toggle voice input
    func toggleVoiceInput() async {
        if isListening {
            stopVoiceInput()
        } else {
            await startVoiceInput()
        }
    }

    // MARK: - Manual Controls

    /// Manually trigger a specific announcement
    func announce(_ message: String) {
        triggerEngine.speakImmediately(message)
    }

    /// Request current stats announcement
    func announceCurrentStats() {
        guard let service = recordingService,
              let session = service.currentSession else { return }

        let distance = service.gpsService.totalDistance
        let distanceMiles = distance / 1609.34
        let pace = session.elapsedTime > 0 && distance > 0
            ? session.elapsedTime / (distance / 1609.34)
            : 0

        let paceMinutes = Int(pace) / 60
        let paceSeconds = Int(pace) % 60
        let paceString = "\(paceMinutes):\(String(format: "%02d", paceSeconds))"

        let message = String(format: "%.2f miles. %@ average pace.", distanceMiles, paceString)
        triggerEngine.speakImmediately(message)
    }

    // MARK: - Settings

    /// Update trigger enabled states from settings
    func applySettings() {
        let settings = self.settings

        // Phase 1: Split announcements
        triggerEngine.setTriggerEnabled(
            settings.announceSplits && settings.splitDetail != .off,
            triggerId: "split"
        )

        // Phase 2: Pace drift alerts
        triggerEngine.setTriggerEnabled(
            settings.paceAlerts,
            triggerId: "paceDrift"
        )

        // Phase 2: Heart rate zone alerts
        triggerEngine.setTriggerEnabled(
            settings.zoneAlerts,
            triggerId: "zoneTransition"
        )

        triggerEngine.setTriggerEnabled(
            settings.zoneAlerts,
            triggerId: "zoneDuration"
        )

        // Phase 2: Check-in prompts
        triggerEngine.setTriggerEnabled(
            settings.enableCheckIns,
            triggerId: "checkIn"
        )
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension AudioCoachingService {

    /// Test announcement for debugging
    func testAnnouncement() {
        announce("Testing audio coaching. Mile 1 complete. 8:42 pace.")
    }

    /// Simulate a split for testing
    func simulateSplit() {
        triggerEngine.testSplitAnnouncement()
    }
}
#endif
