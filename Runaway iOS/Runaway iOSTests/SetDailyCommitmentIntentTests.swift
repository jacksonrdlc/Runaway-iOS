import XCTest
@testable import Runaway_iOS

final class SetDailyCommitmentIntentTests: XCTestCase {
    func testMissingSessionQueuesAuthenticatedAppHandoffWithoutClaimingSuccess() async {
        let defaults = makeDefaults()
        let pendingDirectory = makePendingDirectory()
        let client = DailyCommitmentIntentClient(
            defaults: defaults,
            session: .shared,
            accessToken: { nil },
            pendingDirectoryURL: pendingDirectory
        )

        let outcome = await client.setCommitment(activityType: "Run")

        XCTAssertEqual(outcome, .requiresAuthenticatedApp)
        let store = try! PendingWidgetCommitmentStore(defaults: defaults, directoryURL: pendingDirectory)
        XCTAssertEqual(try! store.pendingActions().map(\.activityType), ["Run"])
        XCTAssertNil(defaults.string(forKey: "todays_commitment_type"))
    }

    func testRejectedServerResponseDoesNotPublishOptimisticCommitment() async {
        let defaults = configuredDefaults()
        let pendingDirectory = makePendingDirectory()
        let session = makeCommitmentSession(statusCode: 401)
        let client = DailyCommitmentIntentClient(
            defaults: defaults,
            session: session,
            accessToken: { "expired-jwt" },
            pendingDirectoryURL: pendingDirectory
        )

        let outcome = await client.setCommitment(activityType: "Walk")

        guard case .failed(let statusCode) = outcome else {
            return XCTFail("Expected a truthful failure result")
        }
        XCTAssertEqual(statusCode, 401)
        XCTAssertNil(defaults.string(forKey: "todays_commitment_type"))
        let store = try! PendingWidgetCommitmentStore(defaults: defaults, directoryURL: pendingDirectory)
        XCTAssertEqual(try! store.pendingActions().map(\.activityType), ["Walk"])
    }

    func testSuccessfulAuthenticatedMutationPublishesCommitment() async {
        let defaults = configuredDefaults()
        let pendingDirectory = makePendingDirectory()
        let session = makeCommitmentSession(statusCode: 201) { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer valid-jwt")
            XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "publishable-key")
        }
        let client = DailyCommitmentIntentClient(
            defaults: defaults,
            session: session,
            accessToken: { "valid-jwt" },
            pendingDirectoryURL: pendingDirectory
        )

        let outcome = await client.setCommitment(activityType: "Yoga")

        XCTAssertEqual(outcome, .saved)
        XCTAssertEqual(defaults.string(forKey: "todays_commitment_type"), "Yoga")
        let store = try! PendingWidgetCommitmentStore(defaults: defaults, directoryURL: pendingDirectory)
        XCTAssertTrue(try! store.pendingActions().isEmpty)
    }

    func testProducerDuringDrainCannotBeClearedByOlderAction() {
        let defaults = makeDefaults()
        let pendingDirectory = makePendingDirectory()
        let drainStore = try! PendingWidgetCommitmentStore(defaults: defaults, directoryURL: pendingDirectory)
        let producerStore = try! PendingWidgetCommitmentStore(defaults: defaults, directoryURL: pendingDirectory)
        let drainingAction = try! drainStore.enqueue(activityType: "Run", id: UUID())
        let newerAction = try! producerStore.enqueue(activityType: "Yoga", id: UUID())

        XCTAssertTrue(try! drainStore.deleteExact(drainingAction))
        XCTAssertEqual(try! drainStore.pendingActions(), [newerAction])
    }

    private func makeDefaults() -> UserDefaults {
        let name = "SetDailyCommitmentIntentTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func makePendingDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("SetDailyCommitmentIntentTests")
            .appendingPathComponent(UUID().uuidString)
    }

    private func configuredDefaults() -> UserDefaults {
        let defaults = makeDefaults()
        defaults.set("https://example.supabase.co", forKey: "widget_supabase_url")
        defaults.set("publishable-key", forKey: "widget_supabase_key")
        defaults.set(29, forKey: "widget_athlete_id")
        return defaults
    }

    private func makeCommitmentSession(
        statusCode: Int,
        inspect: @escaping (URLRequest) -> Void = { _ in }
    ) -> URLSession {
        CommitmentURLProtocol.handler = { request in
            inspect(request)
            return HTTPURLResponse(
                url: request.url!, statusCode: statusCode, httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CommitmentURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class CommitmentURLProtocol: URLProtocol {
    static var handler: ((URLRequest) -> HTTPURLResponse)?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = Self.handler!(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
