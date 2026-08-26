import Foundation
import Supabase

struct ActivityObservationRemoteService {
    private struct Upload: Encodable {
        let activityId: Int
        let observation: String

        enum CodingKeys: String, CodingKey {
            case activityId = "activity_id"
            case observation
        }
    }

    private struct Envelope: Decodable {
        let success: Bool
    }

    func save(activityId: Int, observation: String) async throws {
        let envelope: Envelope = try await supabase.functions.invoke(
            "activity-observations",
            options: FunctionInvokeOptions(
                body: Upload(activityId: activityId, observation: observation)
            )
        )
        guard envelope.success else { throw SaveError.rejected }
    }

    private enum SaveError: Error {
        case rejected
    }
}
