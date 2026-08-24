import XCTest
@testable import Runaway_iOS

@MainActor
final class Task7ReliabilityFollowupTests: XCTestCase {
    func testNumericQueueIdentifierUsesRepositoryLookupPath() async throws {
        let repository = ActivitySyncRepositorySpy(activity: Activity(id: 417, name: "Queued run"))
        let coordinator = ActivityCreateSyncCoordinator(
            localRepository: repository,
            acknowledgementStore: ActivitySyncAcknowledgementStore(directoryURL: temporaryDirectory()),
            remoteUpsert: { $0 }
        )

        try await coordinator.sync(operationID: UUID(), numericEntityID: "417")

        XCTAssertEqual(repository.lookedUpIDs, [417])
        XCTAssertEqual(repository.appliedServerIDs, [417])
    }

    func testRestartReplaysDurableAcknowledgementWithoutSecondRemoteCreate() async throws {
        let directory = temporaryDirectory()
        let operationID = UUID()
        let firstRepository = ActivitySyncRepositorySpy(
            activity: Activity(id: 912, name: "Crash-safe run"),
            applyFailuresRemaining: 1
        )
        var remoteCreateCount = 0
        let firstCoordinator = ActivityCreateSyncCoordinator(
            localRepository: firstRepository,
            acknowledgementStore: ActivitySyncAcknowledgementStore(directoryURL: directory),
            remoteUpsert: { activity in
                remoteCreateCount += 1
                return activity
            }
        )

        do {
            try await firstCoordinator.sync(operationID: operationID, numericEntityID: "912")
            XCTFail("Expected the simulated local save to fail")
        } catch {}

        let restartedRepository = ActivitySyncRepositorySpy(activity: Activity(id: 912))
        let restartedCoordinator = ActivityCreateSyncCoordinator(
            localRepository: restartedRepository,
            acknowledgementStore: ActivitySyncAcknowledgementStore(directoryURL: directory),
            remoteUpsert: { activity in
                remoteCreateCount += 1
                return activity
            }
        )
        try await restartedCoordinator.sync(operationID: operationID, numericEntityID: "912")

        XCTAssertEqual(remoteCreateCount, 1)
        XCTAssertEqual(restartedRepository.lookedUpIDs, [])
        XCTAssertEqual(restartedRepository.appliedServerIDs, [912])
    }

    func testReadinessTransitionTriggersOneCoalescedDrain() async {
        let coordinator = WidgetPendingActionDrainCoordinator()
        var drainCount = 0

        if WidgetPendingActionDrainCoordinator.shouldDrain(previousReady: false, newReady: true) {
            coordinator.requestDrain { drainCount += 1 }
        }
        if WidgetPendingActionDrainCoordinator.shouldDrain(previousReady: true, newReady: true) {
            coordinator.requestDrain { drainCount += 1 }
        }
        await coordinator.waitUntilIdle()

        XCTAssertEqual(drainCount, 1)
    }

    func testCommitmentLoadFailureRetainsPendingWithoutChoosingMutation() {
        let result = CommitmentLoadResult.failure(TestError.simulated)
        XCTAssertEqual(WidgetCommitmentPendingDecision.decide(from: result), .retainPending)
    }

    func testAccessibilityLayoutUsesVerticalControlsAndAllowsMultilineStats() {
        XCTAssertFalse(RunRecordingLayoutPolicy.usesVerticalControls(for: .large))
        XCTAssertEqual(RunRecordingLayoutPolicy.statLineLimit(for: .large), 1)
        XCTAssertTrue(RunRecordingLayoutPolicy.usesVerticalControls(for: .accessibility3))
        XCTAssertEqual(RunRecordingLayoutPolicy.statLineLimit(for: .accessibility3), 2)
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("Task7ReliabilityFollowupTests")
            .appendingPathComponent(UUID().uuidString)
    }
}

@MainActor
private final class ActivitySyncRepositorySpy: ActivitySyncLocalRepository {
    private let activity: Activity
    private var applyFailuresRemaining: Int
    private(set) var lookedUpIDs: [Int] = []
    private(set) var appliedServerIDs: [Int] = []

    init(activity: Activity, applyFailuresRemaining: Int = 0) {
        self.activity = activity
        self.applyFailuresRemaining = applyFailuresRemaining
    }

    func activity(forNumericID id: Int) async throws -> Activity {
        lookedUpIDs.append(id)
        return activity
    }

    func applyServerAcknowledgement(_ activity: Activity) throws {
        if applyFailuresRemaining > 0 {
            applyFailuresRemaining -= 1
            throw TestError.simulated
        }
        appliedServerIDs.append(activity.id)
    }
}

private enum TestError: Error {
    case simulated
}
