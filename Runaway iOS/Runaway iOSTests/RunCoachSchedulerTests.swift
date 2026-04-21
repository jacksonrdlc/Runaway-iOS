//
//  RunCoachSchedulerTests.swift
//  Runaway iOSTests
//
//  Exercises the split-announcement state machine in isolation. The
//  scheduler is wired with a spy announcer and a fixed-settings closure
//  so these tests never touch AVAudioSession, AVSpeechSynthesizer, or
//  the persisted CoachSettingsStore.
//

import XCTest
@testable import Runaway_iOS

// MARK: - Spy Announcer

/// Captures every call the scheduler makes so tests can assert on timing
/// and message content. Matches the production announcer's semantics:
/// no return values, side-effect-only methods.
@MainActor
final class SpyAnnouncer: RunCoachAnnouncer {
    private(set) var primeCount = 0
    private(set) var stopCount = 0
    private(set) var spokenCues: [String] = []

    func prime() {
        primeCount += 1
    }

    func speakCue(_ text: String) {
        spokenCues.append(text)
    }

    func stop() {
        stopCount += 1
    }
}

// MARK: - Tests

@MainActor
final class RunCoachSchedulerTests: XCTestCase {

    // MARK: - Helpers

    /// Builds a scheduler wired to a spy announcer and a closure-based
    /// settings provider. The returned tuple lets each test mutate
    /// settings mid-test to exercise state transitions.
    private func makeScheduler(
        isEnabled: Bool = true,
        announceSplits: Bool = true,
        splitDetail: SplitDetail = .basic,
        distanceUnit: DistanceUnit = .miles
    ) -> (RunCoachScheduler, SpyAnnouncer, Box<CoachSettings>) {
        var settings = CoachSettings()
        settings.isEnabled = isEnabled
        settings.announceSplits = announceSplits
        settings.splitDetail = splitDetail
        settings.distanceUnit = distanceUnit

        let box = Box(value: settings)
        let spy = SpyAnnouncer()
        let scheduler = RunCoachScheduler(
            announcer: spy,
            settingsProvider: { box.value }
        )
        return (scheduler, spy, box)
    }

    // MARK: - Lifecycle

    func test_start_whenEnabled_primesAnnouncer() {
        let (scheduler, spy, _) = makeScheduler()
        scheduler.start()
        XCTAssertEqual(spy.primeCount, 1)
    }

    func test_start_whenDisabled_doesNotPrime() {
        let (scheduler, spy, _) = makeScheduler(isEnabled: false)
        scheduler.start()
        XCTAssertEqual(spy.primeCount, 0)
    }

    func test_stop_alwaysStopsAnnouncer() {
        let (scheduler, spy, _) = makeScheduler()
        scheduler.start()
        scheduler.stop()
        XCTAssertEqual(spy.stopCount, 1)
    }

    func test_updateBeforeStart_isNoOp() {
        let (scheduler, spy, _) = makeScheduler()
        scheduler.update(distance: 5_000, elapsedTime: 900)
        XCTAssertTrue(spy.spokenCues.isEmpty)
    }

    // MARK: - Mile Splits (Basic)

    func test_update_crossingFirstMile_announcesOnce() {
        let (scheduler, spy, _) = makeScheduler()
        scheduler.start()

        scheduler.update(distance: 1_610, elapsedTime: 510) // 8:30 first mile
        XCTAssertEqual(spy.spokenCues, ["Mile 1. 8:30."])
    }

    func test_update_shortOfBoundary_doesNotAnnounce() {
        let (scheduler, spy, _) = makeScheduler()
        scheduler.start()

        scheduler.update(distance: 1_609, elapsedTime: 500) // just under 1 mile
        XCTAssertTrue(spy.spokenCues.isEmpty)
    }

    func test_update_sparseJumpAcrossMultipleBoundaries_announcesEach() {
        // Simulates a GPS update gap (foreground → background → resume)
        // where the runner crossed two mile boundaries in a single update.
        let (scheduler, spy, _) = makeScheduler()
        scheduler.start()

        scheduler.update(distance: 3_300, elapsedTime: 1_020)
        XCTAssertEqual(spy.spokenCues.count, 2)
        XCTAssertEqual(spy.spokenCues[0], "Mile 1. 17:00.")
        XCTAssertEqual(spy.spokenCues[1], "Mile 2. 0:00.")
    }

    func test_splitDuration_usesDeltaBetweenBoundaries_notTotalElapsed() {
        let (scheduler, spy, _) = makeScheduler()
        scheduler.start()

        scheduler.update(distance: 1_610, elapsedTime: 510) // mile 1 @ 8:30
        scheduler.update(distance: 3_220, elapsedTime: 1_050) // mile 2 @ +9:00

        XCTAssertEqual(spy.spokenCues, [
            "Mile 1. 8:30.",
            "Mile 2. 9:00.",
        ])
    }

    // MARK: - Detail Levels

    func test_detailedDetail_usesExpandedPhrasing() {
        let (scheduler, spy, _) = makeScheduler(splitDetail: .detailed)
        scheduler.start()

        scheduler.update(distance: 1_610, elapsedTime: 480)
        XCTAssertEqual(spy.spokenCues, ["Mile 1 complete. 8:00 pace."])
    }

    func test_offDetail_suppressesAnnouncements() {
        let (scheduler, spy, _) = makeScheduler(splitDetail: .off)
        scheduler.start()

        scheduler.update(distance: 3_300, elapsedTime: 1_020)
        XCTAssertTrue(spy.spokenCues.isEmpty)
    }

    func test_announceSplitsDisabled_suppressesAnnouncements() {
        let (scheduler, spy, _) = makeScheduler(announceSplits: false)
        scheduler.start()

        scheduler.update(distance: 3_300, elapsedTime: 1_020)
        XCTAssertTrue(spy.spokenCues.isEmpty)
    }

    // MARK: - Distance Units

    func test_kilometerUnit_announcesAtKmBoundaries() {
        let (scheduler, spy, _) = makeScheduler(distanceUnit: .kilometers)
        scheduler.start()

        scheduler.update(distance: 1_000, elapsedTime: 300) // 5:00 first km
        XCTAssertEqual(spy.spokenCues, ["Kilometer 1. 5:00."])
    }

    func test_kilometerUnit_doesNotAnnounceAtMileBoundary() {
        let (scheduler, spy, _) = makeScheduler(distanceUnit: .kilometers)
        scheduler.start()

        // ~1 mile = 1609m = 1 km boundary already crossed, but that's correct
        // for kilometers. Assert only the km-1 cue fires, not a mile one.
        scheduler.update(distance: 1_609, elapsedTime: 483)
        XCTAssertEqual(spy.spokenCues.count, 1)
        XCTAssertTrue(spy.spokenCues[0].hasPrefix("Kilometer 1."))
    }

    // MARK: - Re-entry

    func test_startAfterStop_resetsUnitCounter() {
        let (scheduler, spy, _) = makeScheduler()

        scheduler.start()
        scheduler.update(distance: 1_610, elapsedTime: 510)
        XCTAssertEqual(spy.spokenCues.count, 1)

        scheduler.stop()
        scheduler.start()

        // A new run begins — the first mile should announce again, not be
        // suppressed by stale state from the prior run.
        scheduler.update(distance: 1_610, elapsedTime: 510)
        XCTAssertEqual(spy.spokenCues.count, 2)
        XCTAssertEqual(spy.spokenCues.last, "Mile 1. 8:30.")
    }

    // MARK: - Settings Mutation Mid-Run

    func test_disablingCoachMidRun_haltsFurtherAnnouncements() {
        let (scheduler, spy, settingsBox) = makeScheduler()
        scheduler.start()

        scheduler.update(distance: 1_610, elapsedTime: 510)
        XCTAssertEqual(spy.spokenCues.count, 1)

        settingsBox.value.isEnabled = false
        scheduler.update(distance: 3_220, elapsedTime: 1_020)
        XCTAssertEqual(spy.spokenCues.count, 1, "No new cues after settings disabled")
    }
}

// MARK: - Mutable Box

/// Swift closures capture by value, so to let a test mutate the settings
/// the scheduler reads each tick, we hand it a reference-typed box instead.
@MainActor
private final class Box<Value> {
    var value: Value
    init(value: Value) { self.value = value }
}
