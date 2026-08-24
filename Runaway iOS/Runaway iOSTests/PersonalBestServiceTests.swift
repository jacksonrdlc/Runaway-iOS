import XCTest
@testable import Runaway_iOS

final class PersonalBestServiceTests: XCTestCase {
    func testUpsertPayloadOmitsFabricatedPersonalBestID() throws {
        let candidate = PersonalBestCandidate(
            distanceLabel: "5k",
            distanceMeters: 5_000,
            timeSeconds: 1_200,
            activityId: 17,
            achievedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let payload = PersonalBestUpsertPayload(candidate: candidate, athleteId: 9)

        let data = try JSONEncoder().encode(payload)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertNil(json["id"])
        XCTAssertEqual(json["athlete_id"] as? Int, 9)
        XCTAssertEqual(json["activity_id"] as? Int, 17)
    }
}
