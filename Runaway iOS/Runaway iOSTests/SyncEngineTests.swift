import XCTest
@testable import Runaway_iOS

@MainActor
final class SyncEngineTests: XCTestCase {
    func testPartialFailureRetainsOnlyFailedOperationAndRetriesIt() async {
        let defaults = makeDefaults()
        var shouldFailSecond = true
        let engine = SyncEngine(
            userDefaults: defaults,
            startsNetworkMonitor: false,
            initialOnlineState: true,
            operationProcessor: { operation in
                if operation.entityId == "second" && shouldFailSecond {
                    throw SyncTestError.rejected
                }
            }
        )
        engine.queueUpload(entityType: .activity, entityId: "first")
        engine.queueUpload(entityType: .activity, entityId: "second")

        await engine.syncPendingChanges()

        XCTAssertEqual(engine.pendingChangesCount, 1)
        XCTAssertNil(engine.lastSyncDate)

        shouldFailSecond = false
        await engine.syncPendingChanges()

        XCTAssertEqual(engine.pendingChangesCount, 0)
        XCTAssertNotNil(engine.lastSyncDate)
    }

    func testRepeatedFailureIsNeverDroppedFromPersistentQueue() async {
        let defaults = makeDefaults()
        let engine = SyncEngine(
            userDefaults: defaults,
            startsNetworkMonitor: false,
            initialOnlineState: true,
            operationProcessor: { _ in throw SyncTestError.rejected }
        )
        engine.queueDeletion(entityType: .activity, entityId: "91")

        for _ in 0..<5 {
            await engine.syncPendingChanges()
        }

        XCTAssertEqual(engine.pendingChangesCount, 1)
        let data = defaults.data(forKey: "SyncEngine.pendingOperations")
        let operations = try? JSONDecoder().decode([SyncOperation].self, from: data ?? Data())
        XCTAssertEqual(operations?.count, 1)
        XCTAssertEqual(operations?.first?.retryCount, 5)
    }

    func testCreateFailurePreservesDependentUpdateThenRetriesInOrder() async {
        let defaults = makeDefaults()
        let localRecordID = UUID()
        var failCreate = true
        var processed: [SyncOperationType] = []
        let engine = SyncEngine(
            userDefaults: defaults,
            startsNetworkMonitor: false,
            initialOnlineState: true,
            operationProcessor: { operation in
                processed.append(operation.operationType)
                if operation.operationType == .create && failCreate {
                    throw SyncTestError.rejected
                }
            }
        )
        engine.queueUpload(
            entityType: .activity,
            entityId: "provisional-41",
            localRecordID: localRecordID,
            operationType: .create
        )
        engine.queueUpload(
            entityType: .activity,
            entityId: "provisional-41",
            localRecordID: localRecordID,
            operationType: .update
        )

        XCTAssertEqual(engine.pendingChangesCount, 2)
        await engine.syncPendingChanges()
        XCTAssertEqual(processed, [.create])
        XCTAssertEqual(engine.pendingChangesCount, 2)

        failCreate = false
        processed.removeAll()
        await engine.syncPendingChanges()
        XCTAssertEqual(processed, [.create, .update])
        XCTAssertEqual(engine.pendingChangesCount, 0)
    }

    private func makeDefaults() -> UserDefaults {
        let name = "SyncEngineTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}

private enum SyncTestError: Error {
    case rejected
}
