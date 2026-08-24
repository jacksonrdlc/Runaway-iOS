import XCTest
@testable import Runaway_iOS

@MainActor
final class UserSessionTests: XCTestCase {
    func testAthleteSetupFailureLeavesSessionUnreadyAndSurfacesError() {
        let session = UserSession(startAutomatically: false)
        session.isAuthenticated = true

        session.completeAthleteSetup(with: .failure(TestFailure.setup))

        XCTAssertFalse(session.isReady)
        XCTAssertNil(session.userId)
        XCTAssertNotNil(session.setupError)
        XCTAssertFalse(session.isCheckingOnboarding)
    }

    func testAthleteSetupSuccessMakesAuthenticatedSessionReady() {
        let session = UserSession(startAutomatically: false)
        session.isAuthenticated = true

        session.completeAthleteSetup(with: .success(73))

        XCTAssertTrue(session.isReady)
        XCTAssertEqual(session.userId, 73)
        XCTAssertNil(session.setupError)
    }
}

private enum TestFailure: Error {
    case setup
}
