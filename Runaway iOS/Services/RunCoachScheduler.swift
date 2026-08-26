//
//  RunCoachScheduler.swift
//  Runaway iOS
//
//  Schedules audio cues from a live run's distance + elapsed time.
//  Phase 1 scope: split announcements only. Pace drift, zones, check-ins
//  come in later phases.
//

import Foundation

// MARK: - Announcer Protocol

/// Anything that can voice a cue during a run. Exists so the scheduler
/// can be unit-tested without touching `AVAudioSession` or `AVSpeechSynthesizer`.
/// Production callers get the real `AudioCueService` via the `.shared` default;
/// tests inject a spy.
@MainActor
protocol RunCoachAnnouncer: AnyObject {
    func prime()
    func speakCue(_ text: String)
    func stop()
}

extension AudioCueService: RunCoachAnnouncer {}

// MARK: - Run Coach Scheduler

/// Drives audio cues from a live run. Decoupled from the run tracker —
/// feed it `update(distance:elapsedTime:)` from HealthKit, CoreLocation,
/// or any other source and it decides when to speak.
///
/// This is a thin state machine over a `RunCoachAnnouncer`. It does not
/// own the audio session; the announcer does.
@MainActor
final class RunCoachScheduler {

    static let shared = RunCoachScheduler()

    // MARK: - Constants

    private enum Coaching {
        static let minPaceSampleDistanceMeters: Double = 2.0
        static let paceWindowDurationSeconds: TimeInterval = 120
        static let slumpRecentWindowSeconds: TimeInterval = 30
        static let slumpThresholdRatio: Double = 1.20
        static let identityCueCooldownSeconds: TimeInterval = 90
        static let postSplitCueDelaySeconds: TimeInterval = 3
    }

    // MARK: - Private State

    private let announcer: RunCoachAnnouncer
    private let settingsProvider: () -> CoachSettings

    private var isActive = false
    private var lastAnnouncedUnit: Int = 0
    private var elapsedAtLastUnit: TimeInterval = 0

    // Identity cue state
    private var identityCues: [String] = []
    private var nextCueIndex: Int = 0
    private var lastCueFiredAt: Date? = nil

    // Slump detection
    private var paceWindow: [(timestamp: Date, paceSecondsPerMeter: Double)] = []
    private var lastUpdateDistance: Double = 0
    private var lastUpdateTime: TimeInterval = 0

    private var settings: CoachSettings { settingsProvider() }

    // MARK: - Initialization

    /// Designated init. Production uses the defaults, which point at the
    /// real `AudioCueService` singleton and the persisted coach settings.
    /// Tests pass in a spy announcer and a fixed-settings closure so they
    /// don't touch the audio stack or the user's real preferences.
    init(
        announcer: RunCoachAnnouncer? = nil,
        settingsProvider: (() -> CoachSettings)? = nil
    ) {
        self.announcer = announcer ?? AudioCueService.shared
        self.settingsProvider = settingsProvider ?? { CoachSettingsStore.shared.settings }
    }

    // MARK: - Lifecycle

    /// Call when a run starts. Primes the synthesizer so the first cue
    /// doesn't stutter. No-op if audio coaching is disabled.
    func start() {
        guard settings.isEnabled else { return }
        isActive = true
        lastAnnouncedUnit = 0
        elapsedAtLastUnit = 0
        nextCueIndex = 0
        lastCueFiredAt = nil
        paceWindow = []
        lastUpdateDistance = 0
        lastUpdateTime = 0
        announcer.prime()
    }

    /// Call when a run ends or is cancelled. Stops any in-flight cue
    /// and deactivates the audio session.
    func stop() {
        isActive = false
        lastAnnouncedUnit = 0
        elapsedAtLastUnit = 0
        identityCues = []
        nextCueIndex = 0
        lastCueFiredAt = nil
        paceWindow = []
        lastUpdateDistance = 0
        lastUpdateTime = 0
        announcer.stop()
    }

    // MARK: - Identity Cues

    /// Load a pre-generated cue batch before the run starts. Call after `start()`.
    func loadIdentityCues(_ cues: [String]) {
        identityCues = cues
        nextCueIndex = 0
        lastCueFiredAt = nil
    }

    // MARK: - Distance Updates

    /// Feed the scheduler a distance update. Call whenever a new total
    /// distance is available from the run tracker.
    ///
    /// - Parameters:
    ///   - distance: Total distance covered so far, in meters.
    ///   - elapsedTime: Total elapsed time since the run started, in seconds.
    func update(distance: Double, elapsedTime: TimeInterval) {
        guard isActive, settings.isEnabled else { return }

        updatePaceWindow(distance: distance, elapsedTime: elapsedTime)

        guard settings.announceSplits, settings.splitDetail != .off else { return }

        let unitMeters = settings.distanceUnit.metersPerUnit
        let currentUnit = Int(distance / unitMeters)

        while currentUnit > lastAnnouncedUnit {
            let completedUnit = lastAnnouncedUnit + 1
            let splitDuration = elapsedTime - elapsedAtLastUnit
            announceSplit(unit: completedUnit, splitDuration: splitDuration)
            lastAnnouncedUnit = completedUnit
            elapsedAtLastUnit = elapsedTime
        }
    }

    // MARK: - Announcement

    private func announceSplit(unit: Int, splitDuration: TimeInterval) {
        let unitLabel = settings.distanceUnit == .miles ? "Mile" : "Kilometer"
        let paceString = formatPace(splitDuration)

        let message: String
        switch settings.splitDetail {
        case .off:
            return
        case .basic:
            message = "\(unitLabel) \(unit). \(paceString)."
        case .detailed:
            // Phase 1 treats detailed the same as basic. Phase 2 adds
            // heart-rate, delta from previous split, and target-pace framing.
            message = "\(unitLabel) \(unit) complete. \(paceString) pace."
        }

        announcer.speakCue(message)

        // Identity cue queued after each split; shared cooldown with slump-triggered cues
        // suppresses this if a slump cue already fired within the cooldown window.
        if settings.enableIdentityVoiceCues {
            DispatchQueue.main.asyncAfter(deadline: .now() + Coaching.postSplitCueDelaySeconds) { [weak self] in
                self?.fireNextIdentityCue()
            }
        }

        AnalyticsService.shared.trackSplitAnnounced(
            splitNumber: unit,
            pace: splitDuration,
            distance: Double(unit) * settings.distanceUnit.metersPerUnit
        )
    }

    private func updatePaceWindow(distance: Double, elapsedTime: TimeInterval) {
        let deltaDistance = distance - lastUpdateDistance
        let deltaTime = elapsedTime - lastUpdateTime
        lastUpdateDistance = distance
        lastUpdateTime = elapsedTime

        guard deltaDistance > Coaching.minPaceSampleDistanceMeters, deltaTime > 0 else { return }

        let pace = deltaTime / deltaDistance
        paceWindow.append((timestamp: Date(), paceSecondsPerMeter: pace))
        let cutoff = Date().addingTimeInterval(-Coaching.paceWindowDurationSeconds)
        paceWindow.removeAll { $0.timestamp < cutoff }

        if settings.enableIdentityVoiceCues {
            detectSlump()
        }
    }

    private func detectSlump() {
        let recentCutoff = Date().addingTimeInterval(-Coaching.slumpRecentWindowSeconds)
        let recent = paceWindow.filter { $0.timestamp >= recentCutoff }
        let prior  = paceWindow.filter { $0.timestamp <  recentCutoff }
        guard !recent.isEmpty, !prior.isEmpty else { return }

        let recentAvg = recent.map(\.paceSecondsPerMeter).reduce(0, +) / Double(recent.count)
        let priorAvg  = prior.map(\.paceSecondsPerMeter).reduce(0,  +) / Double(prior.count)

        if recentAvg > priorAvg * Coaching.slumpThresholdRatio {
            fireNextIdentityCue()
        }
    }

    private func fireNextIdentityCue() {
        guard isActive else { return }
        guard !identityCues.isEmpty else { return }
        guard nextCueIndex < identityCues.count else { return }
        if let last = lastCueFiredAt, Date().timeIntervalSince(last) < Coaching.identityCueCooldownSeconds { return }
        announcer.speakCue(identityCues[nextCueIndex])
        lastCueFiredAt = Date()
        nextCueIndex += 1
    }

    private func formatPace(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
