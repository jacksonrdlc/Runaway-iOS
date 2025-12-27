//
//  VoiceCoachingCoordinator.swift
//  Runaway iOS
//
//  Created by Claude on 12/23/25.
//

import Foundation
import Combine

// MARK: - Voice Coaching Coordinator

/// Coordinates voice input, intent parsing, and responses during runs
@MainActor
final class VoiceCoachingCoordinator: ObservableObject {

    // MARK: - Published State

    @Published private(set) var isListening: Bool = false
    @Published private(set) var lastIntent: VoiceIntent?
    @Published private(set) var voiceEnabled: Bool = false

    // MARK: - Components

    private let voiceInput: VoiceInputService
    private let ttsService: TTSService
    private let context: ConversationContext

    // MARK: - Callbacks

    /// Called when a voice command requires action (pause, stop, etc.)
    var onCommand: ((VoiceIntent) -> Void)?

    /// Called when stats are requested (to get current run state)
    var onStatsRequest: ((VoiceIntent) -> String?)?

    // MARK: - Settings

    private var settings: CoachSettings { CoachSettingsStore.shared.settings }

    // MARK: - Initialization

    init(
        voiceInput: VoiceInputService = .shared,
        ttsService: TTSService = .shared
    ) {
        self.voiceInput = voiceInput
        self.ttsService = ttsService
        self.context = ConversationContext()

        setupCallbacks()
    }

    // MARK: - Setup

    private func setupCallbacks() {
        voiceInput.onTranscription = { [weak self] transcript in
            Task { @MainActor in
                await self?.handleTranscription(transcript)
            }
        }

        voiceInput.onTimeout = { [weak self] in
            Task { @MainActor in
                self?.handleTimeout()
            }
        }
    }

    // MARK: - Voice Control

    /// Enable voice input (requires authorization)
    func enable() async -> Bool {
        let authorized = await voiceInput.requestAuthorization()
        voiceEnabled = authorized
        return authorized
    }

    /// Start listening for voice input
    func startListening() async {
        if !voiceEnabled {
            let authorized = await enable()
            guard authorized else { return }
        }

        do {
            try await voiceInput.startListening()
            isListening = true
        } catch {
            print("VoiceCoachingCoordinator: Failed to start listening - \(error)")
        }
    }

    /// Stop listening
    func stopListening() {
        voiceInput.stopListening()
        isListening = false
    }

    /// Toggle listening state
    func toggleListening() async {
        if isListening {
            stopListening()
        } else {
            await startListening()
        }
    }

    // MARK: - Prompt Handling

    /// Called when a prompt expects a voice response
    func expectResponse(to prompt: QueuedPrompt) {
        context.addPrompt(prompt)

        // Auto-start listening after prompt finishes speaking
        if prompt.expectsResponse && settings.enableVoiceInput {
            Task {
                // Wait for TTS to finish
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second buffer
                await startListening()
            }
        }
    }

    // MARK: - Transcription Handling

    private func handleTranscription(_ transcript: String) async {
        isListening = false

        print("VoiceCoachingCoordinator: Heard '\(transcript)'")

        // Parse intent with context
        let intent = VoiceIntentParser.parse(transcript, context: context)
        lastIntent = intent

        // Add to context
        context.addResponse(transcript, intent: intent)

        // Handle the intent
        await processIntent(intent)
    }

    private func handleTimeout() {
        isListening = false

        if context.isExpectingResponse {
            // User didn't respond, that's okay
            ttsService.speak("No problem, let's keep going.")
            context.pendingResponse = false
        }
    }

    // MARK: - Intent Processing

    private func processIntent(_ intent: VoiceIntent) async {
        switch intent {
        case .feelingGreat, .feelingGood, .feelingOkay, .feelingTired, .feelingBad:
            // Feeling responses get an acknowledgment
            ttsService.speak(intent.acknowledgment)

        case .requestStats:
            // Get full stats from callback
            if let stats = onStatsRequest?(.requestStats) {
                ttsService.speak(stats)
            } else {
                ttsService.speak("Stats not available right now.")
            }

        case .requestPace:
            if let paceInfo = onStatsRequest?(.requestPace) {
                ttsService.speak(paceInfo)
            }

        case .requestDistance:
            if let distanceInfo = onStatsRequest?(.requestDistance) {
                ttsService.speak(distanceInfo)
            }

        case .requestTime:
            if let timeInfo = onStatsRequest?(.requestTime) {
                ttsService.speak(timeInfo)
            }

        case .requestHeartRate:
            if let hrInfo = onStatsRequest?(.requestHeartRate) {
                ttsService.speak(hrInfo)
            } else {
                ttsService.speak("Heart rate data not available.")
            }

        case .pause:
            ttsService.speak(intent.acknowledgment)
            onCommand?(.pause)

        case .resume:
            ttsService.speak(intent.acknowledgment)
            onCommand?(.resume)

        case .stop:
            ttsService.speak(intent.acknowledgment)
            onCommand?(.stop)

        case .mute:
            ttsService.speak(intent.acknowledgment)
            onCommand?(.mute)

        case .unmute:
            ttsService.speak(intent.acknowledgment)
            onCommand?(.unmute)

        case .yes:
            ttsService.speak(intent.acknowledgment)

        case .no:
            ttsService.speak(intent.acknowledgment)

        case .unknown(let text):
            // For unknown input, give a gentle response
            if context.isExpectingResponse {
                ttsService.speak("Got it. Keep it up!")
            } else {
                ttsService.speak("I didn't quite catch that. You can ask for stats, pace, or distance.")
            }
            print("VoiceCoachingCoordinator: Unknown intent from '\(text)'")
        }
    }

    // MARK: - Context Access

    /// Get conversation context for external use
    var conversationContext: ConversationContext {
        context
    }

    /// Reset for new run
    func reset() {
        stopListening()
        context.reset()
        lastIntent = nil
    }
}

// MARK: - Shake Gesture Detection

import UIKit

/// Detects shake gesture for voice activation
final class ShakeGestureDetector: ObservableObject {

    @Published var shakeDetected: Bool = false

    private var lastShakeTime: Date?
    private let shakeCooldown: TimeInterval = 2.0 // Minimum time between shakes

    /// Called when shake is detected
    var onShake: (() -> Void)?

    init() {
        setupNotifications()
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShake),
            name: UIDevice.deviceDidShakeNotification,
            object: nil
        )
    }

    @objc private func handleShake() {
        let now = Date()

        // Check cooldown
        if let lastShake = lastShakeTime,
           now.timeIntervalSince(lastShake) < shakeCooldown {
            return
        }

        lastShakeTime = now
        shakeDetected = true
        onShake?()

        // Reset flag after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.shakeDetected = false
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - UIDevice Shake Notification

extension UIDevice {
    static let deviceDidShakeNotification = Notification.Name("DeviceDidShakeNotification")
}

// MARK: - UIWindow Extension for Shake Detection

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: UIDevice.deviceDidShakeNotification, object: nil)
        }
    }
}
