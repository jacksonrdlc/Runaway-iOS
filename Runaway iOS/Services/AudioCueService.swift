//
//  AudioCueService.swift
//  Runaway iOS
//
//  Phase 1 of audio coaching: one-way cues only.
//  Design doc: audio-checkin-design.md
//

import Foundation
import AVFoundation

// MARK: - Audio Cue Service

/// Owns the app's audio session and speaks short TTS cues during runs.
///
/// Phase 1 scope: cues only. No speech recognition, no microphone, no
/// `.playAndRecord` session category. This service is the only thing in
/// the app that should touch `AVAudioSession` — nothing else should call
/// `setCategory` or `setActive` directly.
///
/// Audio session choreography:
/// - Category: `.playback`, mode: `.spokenAudio`
/// - Options: `.mixWithOthers` always; `.duckOthers` when `duckOtherAudio` is true
/// - Activated on first utterance, deactivated after the last finishes
/// - Deactivation uses `.notifyOthersOnDeactivation` so Music/Spotify/Podcasts
///   unduck cleanly. Omitting that flag is the classic "music stays stuck at
///   reduced volume" bug, and is almost certainly why the previous attempt
///   left other apps in a bad state.
///
/// Note: For cues to play while the phone is locked during a run, the app
/// target needs the "Audio, AirPlay, and Picture in Picture" background mode
/// enabled in Signing & Capabilities. Without it, cues still work while the
/// run view is foregrounded.
@MainActor
final class AudioCueService: NSObject {

    static let shared = AudioCueService()

    // MARK: - Private State

    private let synthesizer = AVSpeechSynthesizer()
    private let session = AVAudioSession.sharedInstance()

    /// Number of utterances currently queued or speaking. When this drops
    /// to zero after a finish/cancel, we deactivate the audio session.
    private var pendingUtterances: Int = 0

    /// Whether we've primed the synthesizer for this run.
    /// Reset by `stop()` so a fresh prime happens on the next run.
    private var isPrimed: Bool = false

    private var settings: CoachSettings {
        CoachSettingsStore.shared.settings
    }

    // MARK: - Initialization

    private override init() {
        super.init()
        synthesizer.delegate = self
        registerForInterruptions()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public API

    /// Warms the synthesizer with a silent utterance to avoid the cold-start
    /// stutter on the first real cue. Call at run start. Safe to call multiple
    /// times; it's a no-op once primed for this run.
    func prime() {
        guard settings.isEnabled, !isPrimed else { return }

        let priming = AVSpeechUtterance(string: " ")
        priming.volume = 0.0
        priming.rate = AVSpeechUtteranceDefaultSpeechRate
        speak(priming)
        isPrimed = true
    }

    /// Speaks a single cue. No-op if audio coaching is disabled in settings.
    ///
    /// Utterances queue internally in the synthesizer, so rapid calls won't
    /// overlap — they'll speak sequentially. The audio session stays active
    /// across queued utterances and deactivates once the queue drains.
    func speakCue(_ text: String) {
        guard settings.isEnabled else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.rate = settings.speechRate
        utterance.volume = settings.volume
        if let identifier = settings.voiceIdentifier {
            utterance.voice = AVSpeechSynthesisVoice(identifier: identifier)
        }

        speak(utterance)

        AnalyticsService.shared.track(
            .audioPromptSpoken,
            category: .audioCoaching,
            properties: ["text_length": trimmed.count]
        )
    }

    /// Stops any in-flight speech immediately and deactivates the session.
    /// Call when a run ends, when the user disables audio coaching mid-run,
    /// or when the app goes to the background and should release the session.
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        pendingUtterances = 0
        isPrimed = false
        deactivateSession()
    }

    // MARK: - Speaking Pipeline

    private func speak(_ utterance: AVSpeechUtterance) {
        activateSessionIfNeeded()
        pendingUtterances += 1
        synthesizer.speak(utterance)
    }

    // MARK: - Audio Session Management

    private func activateSessionIfNeeded() {
        // If there are already utterances in flight, the session is active.
        // Only configure and activate on the first one.
        guard pendingUtterances == 0 else { return }

        do {
            var options: AVAudioSession.CategoryOptions = [.mixWithOthers]
            if settings.duckOtherAudio {
                options.insert(.duckOthers)
            }

            try session.setCategory(.playback, mode: .spokenAudio, options: options)
            try session.setActive(true)
        } catch {
            #if DEBUG
            print("AudioCueService: Failed to activate session: \(error)")
            #endif
            AnalyticsService.shared.trackError(
                error,
                context: "AudioCueService.activateSession"
            )
        }
    }

    private func deactivateSession() {
        do {
            // `.notifyOthersOnDeactivation` is non-negotiable here — it's the
            // signal Apple Music / Spotify / Podcasts use to unduck and resume.
            try session.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            #if DEBUG
            print("AudioCueService: Failed to deactivate session: \(error)")
            #endif
        }
    }

    // MARK: - Interruption Handling

    private func registerForInterruptions() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }

    @objc
    private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        Task { @MainActor in
            switch type {
            case .began:
                // A phone call or Siri grabbed audio focus. Abandon anything
                // in flight. iOS has already suspended our session, so no
                // explicit deactivate is needed.
                self.synthesizer.stopSpeaking(at: .immediate)
                self.pendingUtterances = 0
            case .ended:
                // We don't auto-resume in Phase 1 — the next scheduled cue
                // will reactivate the session cleanly on its own.
                break
            @unknown default:
                break
            }
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension AudioCueService: AVSpeechSynthesizerDelegate {

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            self.handleUtteranceEnded()
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            self.handleUtteranceEnded()
        }
    }

    private func handleUtteranceEnded() {
        pendingUtterances = max(0, pendingUtterances - 1)
        if pendingUtterances == 0 {
            deactivateSession()
        }
    }
}
