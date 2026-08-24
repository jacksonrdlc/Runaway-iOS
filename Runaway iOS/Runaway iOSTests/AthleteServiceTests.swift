import XCTest
@testable import Runaway_iOS

final class AthleteServiceTests: XCTestCase {
    func testEnsureAthleteDecoderAcceptsScalarRPCResponse() throws {
        let athleteId = try AthleteService.decodeEnsureAthleteId(from: Data("42".utf8))

        XCTAssertEqual(athleteId, 42)
    }
}
