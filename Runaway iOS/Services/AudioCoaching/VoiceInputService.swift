//
//  VoiceInputService.swift
//  Runaway iOS
//
//  Created by Claude on 12/23/25.
//

import Foundation
import Speech
import AVFoundation
import Combine

// MARK: - Voice Input Service

/// Handles speech recognition for voice responses during runs
@MainActor
final class VoiceInputService: NSObject, ObservableObject {

    // MARK: - Published State

    @Published private(set) var isListening: Bool = false
    @Published private(set) var isAuthorized: Bool = false
    @Published private(set) var lastTranscript: String?
    @Published private(set) var error: VoiceInputError?

    // MARK: - Properties

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    private var settings: CoachSettings { CoachSettingsStore.shared.settings }
    private var listeningTimer: Timer?
    private var silenceTimer: Timer?

    /// Callback when speech is recognized
    var onTranscription: ((String) -> Void)?

    /// Callback when listening times out
    var onTimeout: (() -> Void)?

    // MARK: - Configuration

    /// Maximum listening duration
    private let maxListeningDuration: TimeInterval = 5.0

    /// Silence threshold before auto-stopping
    private let silenceThreshold: TimeInterval = 1.5

    // MARK: - Singleton

    static let shared = VoiceInputService()

    // MARK: - Initialization

    private override init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        super.init()

        speechRecognizer?.delegate = self
        checkAuthorization()
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                Task { @MainActor in
                    self?.isAuthorized = status == .authorized
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
    }

    private func checkAuthorization() {
        let status = SFSpeechRecognizer.authorizationStatus()
        isAuthorized = status == .authorized
    }

    // MARK: - Listening Control

    /// Start listening for voice input
    func startListening() async throws {
        guard !isListening else { return }

        if !isAuthorized {
            let authorized = await requestAuthorization()
            guard authorized else {
                throw VoiceInputError.notAuthorized
            }
        }

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw VoiceInputError.recognizerUnavailable
        }

        // Configure audio session for recording
        try await configureAudioSession()

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else {
            throw VoiceInputError.requestCreationFailed
        }

        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true // Faster, works offline

        // Start recognition task
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                self?.handleRecognitionResult(result: result, error: error)
            }
        }

        // Set up audio tap
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()

        isListening = true
        lastTranscript = nil
        error = nil

        // Start timeout timer
        startListeningTimer()

        print("VoiceInputService: Started listening")
    }

    /// Stop listening and finalize
    func stopListening() {
        guard isListening else { return }

        listeningTimer?.invalidate()
        listeningTimer = nil

        silenceTimer?.invalidate()
        silenceTimer = nil

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        isListening = false

        // Restore audio session for playback
        Task {
            try? await restoreAudioSession()
        }

        print("VoiceInputService: Stopped listening")
    }

    // MARK: - Audio Session

    private func configureAudioSession() async throws {
        let audioSession = AVAudioSession.sharedInstance()

        // Use playAndRecord with options that minimize disruption to other audio
        // .duckOthers: lowers music volume instead of stopping it
        // .defaultToSpeaker: use speaker for recording prompts
        // .allowBluetoothA2DP: allow Bluetooth headphones
        // .mixWithOthers: don't fully interrupt other audio
        try audioSession.setCategory(
            .playAndRecord,
            mode: .spokenAudio,
            options: [.duckOthers, .defaultToSpeaker, .allowBluetoothA2DP, .mixWithOthers]
        )
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func restoreAudioSession() async throws {
        let audioSession = AVAudioSession.sharedInstance()

        // Deactivate first to notify other apps they can resume
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)

        // Set back to ambient so other audio apps resume automatically
        try audioSession.setCategory(
            .ambient,
            mode: .spokenAudio,
            options: [.duckOthers, .mixWithOthers]
        )
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Recognition Handling

    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        if let error = error {
            self.error = .recognitionFailed(error.localizedDescription)
            stopListening()
            return
        }

        guard let result = result else { return }

        let transcript = result.bestTranscription.formattedString
        lastTranscript = transcript

        // Reset silence timer on new speech
        resetSilenceTimer()

        // Check if this is the final result
        if result.isFinal {
            stopListening()
            onTranscription?(transcript)
        }
    }

    // MARK: - Timers

    private func startListeningTimer() {
        listeningTimer?.invalidate()
        listeningTimer = Timer.scheduledTimer(
            withTimeInterval: maxListeningDuration,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleTimeout()
            }
        }
    }

    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(
            withTimeInterval: silenceThreshold,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleSilenceTimeout()
            }
        }
    }

    private func handleTimeout() {
        print("VoiceInputService: Listening timeout")
        let transcript = lastTranscript
        stopListening()

        if let transcript = transcript, !transcript.isEmpty {
            onTranscription?(transcript)
        } else {
            onTimeout?()
        }
    }

    private func handleSilenceTimeout() {
        // User stopped speaking, finalize
        if let transcript = lastTranscript, !transcript.isEmpty {
            print("VoiceInputService: Silence detected, finalizing")
            stopListening()
            onTranscription?(transcript)
        }
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension VoiceInputService: SFSpeechRecognizerDelegate {

    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in
            if !available {
                self.error = .recognizerUnavailable
            }
        }
    }
}

// MARK: - Voice Input Error

enum VoiceInputError: Error, LocalizedError {
    case notAuthorized
    case recognizerUnavailable
    case requestCreationFailed
    case recognitionFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition not authorized"
        case .recognizerUnavailable:
            return "Speech recognizer unavailable"
        case .requestCreationFailed:
            return "Failed to create recognition request"
        case .recognitionFailed(let message):
            return "Recognition failed: \(message)"
        }
    }
}
