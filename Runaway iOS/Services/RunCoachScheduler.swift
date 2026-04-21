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

    // MARK: - Private State

    private let announcer: RunCoachAnnouncer
    private let settingsProvider: () -> CoachSettings

    private var isActive = false
    private var lastAnnouncedUnit: Int = 0
    private var elapsedAtLastUnit: TimeInterval = 0

    private var settings: CoachSettings { settingsProvider() }

    // MARK: - Initialization

    /// Designated init. Production uses the defaults, which point at the
    /// real `AudioCueService` singleton and the persisted coach settings.
    /// Tests pass in a spy announcer and a fixed-settings closure so they
    /// don't touch the audio stack or the user's real preferences.
    init(
        announcer: RunCoachAnnouncer = AudioCueService.shared,
        settingsProvider: @escaping () -> CoachSettings = { CoachSettingsStore.shared.settings }
    ) {
        self.announcer = announcer
        self.settingsProvider = settingsProvider
    }

    // MARK: - Lifecycle

    /// Call when a run starts. Primes the synthesizer so the first cue
    /// doesn't stutter. No-op if audio coaching is disabled.
    func start() {
        guard settings.isEnabled else { return }
        isActive = true
        lastAnnouncedUnit = 0
        elapsedAtLastUnit = 0
        announcer.prime()
    }

    /// Call when a run ends or is cancelled. Stops any in-flight cue
    /// and deactivates the audio session.
    func stop() {
        isActive = false
        lastAnnouncedUnit = 0
        elapsedAtLastUnit = 0
        announcer.stop()
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
        guard settings.announceSplits, settings.splitDetail != .off else { return }

        let unitMeters = settings.distanceUnit.metersPerUnit
        let currentUnit = Int(distance / unitMeters)

        // Announce any whole units the runner has crossed since the last
        // update. The while-loop handles the edge case of a sparse GPS
        // update that skipped across a unit boundary.
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

        AnalyticsService.shared.trackSplitAnnounced(
            splitNumber: unit,
            pace: splitDuration,
            distance: Double(unit) * settings.distanceUnit.metersPerUnit
        )
    }

    private func formatPace(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
