import XCTest
@testable import Runaway_iOS

@MainActor
final class Task7ReliabilityFollowupTests: XCTestCase {
    func testNumericQueueIdentifierUsesRepositoryLookupPath() async throws {
        let repository = ActivitySyncRepositorySpy(activity: Activity(id: 417, name: "Queued run"))
        let operationID = UUID()
        var receivedOperationID: UUID?
        let coordinator = ActivityCreateSyncCoordinator(
            localRepository: repository,
            acknowledgementStore: ActivitySyncAcknowledgementStore(directoryURL: temporaryDirectory()),
            remoteUpsert: { activity, operationID in
                receivedOperationID = operationID
                return activity
            }
        )

        try await coordinator.sync(operationID: operationID, numericEntityID: "417")

        XCTAssertEqual(repository.lookedUpIDs, [417])
        XCTAssertEqual(repository.appliedServerIDs, [417])
        XCTAssertEqual(receivedOperationID, operationID)
    }

    func testRestartReplaysDurableAcknowledgementWithoutSecondRemoteCreate() async throws {
        let directory = temporaryDirectory()
        let operationID = UUID()
        let firstRepository = ActivitySyncRepositorySpy(
            activity: Activity(id: 912, name: "Crash-safe run"),
            applyFailuresRemaining: 1
        )
        var remoteCreateCount = 0
        var receivedOperationIDs: [UUID] = []
        let firstCoordinator = ActivityCreateSyncCoordinator(
            localRepository: firstRepository,
            acknowledgementStore: ActivitySyncAcknowledgementStore(directoryURL: directory),
            remoteUpsert: { activity, receivedOperationID in
                remoteCreateCount += 1
                receivedOperationIDs.append(receivedOperationID)
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
            remoteUpsert: { activity, receivedOperationID in
                remoteCreateCount += 1
                receivedOperationIDs.append(receivedOperationID)
                return activity
            }
        )
        try await restartedCoordinator.sync(operationID: operationID, numericEntityID: "912")

        XCTAssertEqual(remoteCreateCount, 1)
        XCTAssertEqual(receivedOperationIDs, [operationID])
        XCTAssertEqual(restartedRepository.lookedUpIDs, [])
        XCTAssertEqual(restartedRepository.appliedServerIDs, [912])
    }

    func testCreateAcknowledgementReconcilesExactLocalRecord() async throws {
        let localRecordID = UUID()
        let repository = ActivitySyncRepositorySpy(activity: Activity(id: 44, name: "Provisional"))
        let coordinator = ActivityCreateSyncCoordinator(
            localRepository: repository,
            acknowledgementStore: ActivitySyncAcknowledgementStore(directoryURL: temporaryDirectory()),
            remoteUpsert: { _, _ in Activity(id: 8044, name: "Canonical") }
        )

        try await coordinator.sync(
            operationID: UUID(),
            numericEntityID: "44",
            localRecordID: localRecordID
        )

        XCTAssertEqual(repository.requestedLocalRecordIDs, [localRecordID])
        XCTAssertEqual(repository.reconciledLocalRecordIDs, [localRecordID])
        XCTAssertEqual(repository.appliedServerIDs, [8044])
        XCTAssertTrue(repository.lookedUpIDs.isEmpty)
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

    func testCompileFocusedIdempotentSignaturesCarryOperationID() {
        let expectedID = UUID()
        let operation = SyncOperation(
            id: expectedID,
            entityType: .activity,
            entityId: "55",
            operationType: .create
        )
        let serviceCall: (Activity, UUID) async throws -> Activity = { activity, operationID in
            try await ActivityService.createActivity(
                activity: activity,
                clientOperationID: operationID
            )
        }
        let visibleError: Error = SyncEngineError.invalidEntityIdentifier

        XCTAssertEqual(operation.id, expectedID)
        _ = serviceCall
        _ = visibleError
    }

    func testOfflineUpdateOperationStaysUpdateAndUsesUpdateSignature() {
        let operation = SyncOperation(
            entityType: .activity,
            entityId: "73",
            operationType: .update
        )
        let updateCall: (Activity) async throws -> Activity = { activity in
            try await ActivityService.updateActivity(activity: activity)
        }

        XCTAssertEqual(operation.operationType, .update)
        _ = updateCall
    }

    func testNilSyncEngineFailsClosedBeforeRemoteCreateCanStart() {
        XCTAssertThrowsError(try HybridActivityRepository.requireDurableSyncEngine(nil)) { error in
            guard case HybridActivityRepositoryError.syncEngineUnavailable = error else {
                return XCTFail("Expected explicit durable sync configuration failure")
            }
        }
    }

    func testAccessibilityLayoutUsesVerticalControlsAndAllowsMultilineStats() {
        XCTAssertFalse(RunRecordingLayoutPolicy.usesVerticalControls(for: .large))
        XCTAssertEqual(RunRecordingLayoutPolicy.statLineLimit(for: .large), 1)
        XCTAssertTrue(RunRecordingLayoutPolicy.usesVerticalControls(for: .accessibility3))
        XCTAssertEqual(RunRecordingLayoutPolicy.statLineLimit(for: .accessibility3), 2)
    }

    func testSimulatorHTTPSProxyRequiresExplicitConfiguration() {
        XCTAssertNil(simulatorHTTPSProxyDictionary(environment: [:]))

        let proxy = simulatorHTTPSProxyDictionary(environment: [
            "RUNAWAY_SIMULATOR_HTTPS_PROXY_HOST": "localhost",
            "RUNAWAY_SIMULATOR_HTTPS_PROXY_PORT": "18888",
        ])

        XCTAssertEqual(proxy?["HTTPSEnable"] as? Bool, true)
        XCTAssertEqual(proxy?["HTTPSProxy"] as? String, "localhost")
        XCTAssertEqual(proxy?["HTTPSPort"] as? Int, 18_888)
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
    private(set) var requestedLocalRecordIDs: [UUID] = []
    private(set) var reconciledLocalRecordIDs: [UUID] = []

    init(activity: Activity, applyFailuresRemaining: Int = 0) {
        self.activity = activity
        self.applyFailuresRemaining = applyFailuresRemaining
    }

    func activity(forNumericID id: Int) async throws -> Activity {
        lookedUpIDs.append(id)
        return activity
    }

    func activity(forLocalRecordID id: UUID) throws -> Activity {
        requestedLocalRecordIDs.append(id)
        return activity
    }

    func reconcileCreateAcknowledgement(
        _ activity: Activity,
        localRecordID: UUID?,
        provisionalNumericID: Int
    ) throws {
        if applyFailuresRemaining > 0 {
            applyFailuresRemaining -= 1
            throw TestError.simulated
        }
        if let localRecordID {
            reconciledLocalRecordIDs.append(localRecordID)
        }
        appliedServerIDs.append(activity.id)
    }
}

private enum TestError: Error {
    case simulated
}
