import XCTest
@testable import Runaway_iOS

final class WorkoutReflectionRemoteServiceTests: XCTestCase {
    func test_saveSendsDataOnlyPayloadToReflectionFunction() async throws {
        let upload = WorkoutReflectionUpload(
            localId: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!,
            activityId: 42,
            effort: 8,
            bodyStatus: "sore",
            mood: "proud",
            conditionTags: ["humid", "hills"],
            note: "Stayed patient.",
            localDebrief: "Hard work with good control.",
            enrichedDebrief: "Private on-device debrief.",
            reflectedAt: Date(timeIntervalSince1970: 1_777_000_000),
            localVersion: 2
        )
        let expected = WorkoutReflectionServerRecord(
            localId: upload.localId,
            activityId: upload.activityId,
            serverDebrief: "Private on-device debrief.",
            serverVersion: 2,
            lastSyncedAt: Date(timeIntervalSince1970: 1_777_000_100)
        )
        let transport = StubReflectionTransport(result: expected)
        let service = WorkoutReflectionRemoteService(transport: transport)

        let saved = try await service.save(upload)
        let lastUpload = await transport.lastUpload
        let callCount = await transport.callCount

        XCTAssertEqual(saved, expected)
        XCTAssertEqual(lastUpload, upload)
        XCTAssertEqual(callCount, 1)
    }

    func test_savePropagatesTransportFailureForDurableRetry() async {
        let transport = StubReflectionTransport(error: StubTransportError.offline)
        let service = WorkoutReflectionRemoteService(transport: transport)
        let upload = WorkoutReflectionUpload(
            localId: UUID(),
            activityId: 7,
            effort: 5,
            bodyStatus: "good",
            mood: "steady",
            conditionTags: [],
            note: nil,
            localDebrief: "A steady run.",
            enrichedDebrief: nil,
            reflectedAt: Date(),
            localVersion: 1
        )

        do {
            _ = try await service.save(upload)
            XCTFail("Expected the transport failure to propagate")
        } catch {
            XCTAssertTrue(error is StubTransportError)
        }
    }
}

private actor StubReflectionTransport: WorkoutReflectionTransport {
    private let result: WorkoutReflectionServerRecord?
    private let error: Error?
    private(set) var lastUpload: WorkoutReflectionUpload?
    private(set) var callCount = 0

    init(result: WorkoutReflectionServerRecord? = nil, error: Error? = nil) {
        self.result = result
        self.error = error
    }

    func save(_ upload: WorkoutReflectionUpload) async throws -> WorkoutReflectionServerRecord {
        callCount += 1
        lastUpload = upload
        if let error { throw error }
        return try XCTUnwrap(result)
    }
}

private enum StubTransportError: Error {
    case offline
}
