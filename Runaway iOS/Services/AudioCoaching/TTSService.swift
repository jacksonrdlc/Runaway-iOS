//
//  TTSService.swift
//  Runaway iOS
//
//  Created by Claude on 12/23/25.
//

import Foundation
import AVFoundation

// MARK: - TTS Service

/// Text-to-speech service using Apple's AVSpeechSynthesizer
@MainActor
final class TTSService: NSObject, ObservableObject {

    // MARK: - Published State

    @Published private(set) var isSpeaking: Bool = false
    @Published private(set) var isPaused: Bool = false

    // MARK: - Private Properties

    private let synthesizer = AVSpeechSynthesizer()
    private var audioSession: AVAudioSession { AVAudioSession.sharedInstance() }
    private var completionHandler: (() -> Void)?
    private var settings: CoachSettings { CoachSettingsStore.shared.settings }

    // MARK: - Singleton

    static let shared = TTSService()

    // MARK: - Initialization

    override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
    }

    // MARK: - Audio Session Configuration

    private func configureAudioSession() {
        do {
            // Configure for playback with ducking (lowers other audio volume)
            let options: AVAudioSession.CategoryOptions = settings.duckOtherAudio
                ? [.duckOthers, .interruptSpokenAudioAndMixWithOthers]
                : [.mixWithOthers]

            try audioSession.setCategory(.playback, mode: .voicePrompt, options: options)
        } catch {
            print("TTSService: Failed to configure audio session: \(error)")
        }
    }

    // MARK: - Public Methods

    /// Speak a message
    func speak(_ message: String, completion: (() -> Void)? = nil) {
        guard !message.isEmpty else {
            completion?()
            return
        }

        // Stop any current speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        // Activate audio session
        do {
            try audioSession.setActive(true)
        } catch {
            print("TTSService: Failed to activate audio session: \(error)")
        }

        // Create utterance
        let utterance = AVSpeechUtterance(string: message)
        utterance.rate = settings.speechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.1

        // Set voice
        if let voiceId = settings.voiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: voiceId) {
            utterance.voice = voice
        } else {
            // Use default enhanced voice for current locale
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }

        completionHandler = completion
        isSpeaking = true

        synthesizer.speak(utterance)
    }

    /// Speak a queued prompt
    func speak(_ prompt: QueuedPrompt, completion: (() -> Void)? = nil) {
        speak(prompt.message, completion: completion)
    }

    /// Stop current speech
    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
        isPaused = false
    }

    /// Pause current speech
    func pause() {
        if synthesizer.isSpeaking {
            synthesizer.pauseSpeaking(at: .word)
            isPaused = true
        }
    }

    /// Resume paused speech
    func resume() {
        if isPaused {
            synthesizer.continueSpeaking()
            isPaused = false
        }
    }

    /// Interrupt current speech with new message (for critical prompts)
    func interrupt(with message: String, completion: (() -> Void)? = nil) {
        stop()
        speak(message, completion: completion)
    }

    // MARK: - Voice Management

    /// Get available voices for a language
    static func availableVoices(for language: String = "en") -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.hasPrefix(language)
        }
    }

    /// Get premium/enhanced voices
    static func enhancedVoices(for language: String = "en") -> [AVSpeechSynthesisVoice] {
        availableVoices(for: language).filter {
            $0.quality == .enhanced
        }
    }

    // MARK: - Deactivation

    private func deactivateAudioSession() {
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // Ignore deactivation errors
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension TTSService: AVSpeechSynthesizerDelegate {

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.isPaused = false
            self.completionHandler?()
            self.completionHandler = nil
            self.deactivateAudioSession()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.isPaused = false
            self.completionHandler = nil
            self.deactivateAudioSession()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isPaused = true
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isPaused = false
        }
    }
}

// MARK: - Preview Helper

#if DEBUG
extension TTSService {
    /// Test the TTS with a sample message
    func testSpeak() {
        speak("Mile 1 complete. 8 minutes 42 seconds pace.")
    }
}
#endif
