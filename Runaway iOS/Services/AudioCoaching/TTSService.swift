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
            // Use .playback category so audio plays in background (phone in pocket)
            // .duckOthers: temporarily lowers music volume instead of pausing it
            // .mixWithOthers: allows our audio to play alongside other audio
            // This combination allows coaching prompts while keeping music playing
            let options: AVAudioSession.CategoryOptions = settings.duckOtherAudio
                ? [.duckOthers, .mixWithOthers]
                : [.mixWithOthers]

            // .playback category is REQUIRED for background audio during runs
            // The ducking options prevent it from stopping other audio
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: options)
            print("TTSService: Audio session configured with playback + ducking")
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
        // Use settings volume (default 0.8) - don't force max volume
        utterance.volume = settings.volume
        utterance.preUtteranceDelay = 0.05
        utterance.postUtteranceDelay = 0.05

        // Set voice - prefer user's choice, then enhanced, then default
        if let voiceId = settings.voiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: voiceId) {
            utterance.voice = voice
        } else {
            // Use best available enhanced voice (Siri-quality)
            utterance.voice = Self.bestAvailableVoice()
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

    /// Get the best available voice - prefers enhanced "Siri-like" voices
    static func bestAvailableVoice(for language: String = "en-US") -> AVSpeechSynthesisVoice? {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()

        // Priority 1: Premium/enhanced voices for the exact language
        let enhancedVoices = allVoices.filter {
            $0.language == language && $0.quality == .enhanced
        }

        // Prefer specific high-quality voices (Samantha, Ava, etc.)
        let preferredNames = ["Samantha", "Ava", "Allison", "Susan", "Siri"]
        for name in preferredNames {
            if let voice = enhancedVoices.first(where: { $0.name.contains(name) }) {
                return voice
            }
        }

        // Any enhanced voice
        if let voice = enhancedVoices.first {
            return voice
        }

        // Priority 2: Enhanced voices for the language prefix (e.g., "en")
        let languagePrefix = String(language.prefix(2))
        let prefixEnhanced = allVoices.filter {
            $0.language.hasPrefix(languagePrefix) && $0.quality == .enhanced
        }
        if let voice = prefixEnhanced.first {
            return voice
        }

        // Priority 3: Any voice for the language
        return AVSpeechSynthesisVoice(language: language)
    }

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
