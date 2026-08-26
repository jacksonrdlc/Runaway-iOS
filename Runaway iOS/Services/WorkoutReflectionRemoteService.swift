import Foundation
import Supabase

struct WorkoutReflectionUpload: Encodable, Equatable {
    let localId: UUID
    let activityId: Int
    let effort: Int
    let bodyStatus: String
    let mood: String
    let conditionTags: [String]
    let note: String?
    let localDebrief: String
    let enrichedDebrief: String?
    let reflectedAt: Date
    let localVersion: Int

    enum CodingKeys: String, CodingKey {
        case localId = "local_id"
        case activityId = "activity_id"
        case effort
        case bodyStatus = "body_status"
        case mood
        case conditionTags = "condition_tags"
        case note
        case localDebrief = "local_debrief"
        case enrichedDebrief = "server_debrief"
        case reflectedAt = "reflected_at"
        case localVersion = "local_version"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(localId, forKey: .localId)
        try container.encode(activityId, forKey: .activityId)
        try container.encode(effort, forKey: .effort)
        try container.encode(bodyStatus, forKey: .bodyStatus)
        try container.encode(mood, forKey: .mood)
        try container.encode(conditionTags, forKey: .conditionTags)
        try container.encodeIfPresent(note, forKey: .note)
        try container.encode(localDebrief, forKey: .localDebrief)
        try container.encodeIfPresent(enrichedDebrief, forKey: .enrichedDebrief)
        try container.encode(Self.dateFormatter.string(from: reflectedAt), forKey: .reflectedAt)
        try container.encode(localVersion, forKey: .localVersion)
    }

    private static let dateFormatter = ISO8601DateFormatter()
}

struct WorkoutReflectionServerRecord: Equatable {
    let localId: UUID
    let activityId: Int
    let serverDebrief: String?
    let serverVersion: Int
    let lastSyncedAt: Date
}

protocol WorkoutReflectionTransport {
    func save(_ upload: WorkoutReflectionUpload) async throws -> WorkoutReflectionServerRecord
}

struct WorkoutReflectionRemoteService {
    private let transport: any WorkoutReflectionTransport

    init(transport: any WorkoutReflectionTransport = SupabaseWorkoutReflectionTransport()) {
        self.transport = transport
    }

    func save(_ upload: WorkoutReflectionUpload) async throws -> WorkoutReflectionServerRecord {
        try await transport.save(upload)
    }
}

private struct SupabaseWorkoutReflectionTransport: WorkoutReflectionTransport {
    private struct Envelope: Decodable {
        let reflection: Row
    }

    private struct Row: Decodable {
        let localId: UUID
        let activityId: Int
        let serverDebrief: String?
        let serverVersion: Int
        let lastSyncedAt: String

        enum CodingKeys: String, CodingKey {
            case localId = "local_id"
            case activityId = "activity_id"
            case serverDebrief = "server_debrief"
            case serverVersion = "server_version"
            case lastSyncedAt = "last_synced_at"
        }
    }

    func save(_ upload: WorkoutReflectionUpload) async throws -> WorkoutReflectionServerRecord {
        let envelope: Envelope = try await supabase.functions.invoke(
            "activity-reflection",
            options: .init(body: upload)
        )
        guard let syncedAt = ISO8601DateFormatter().date(from: envelope.reflection.lastSyncedAt) else {
            throw WorkoutReflectionRemoteError.invalidServerDate
        }

        return WorkoutReflectionServerRecord(
            localId: envelope.reflection.localId,
            activityId: envelope.reflection.activityId,
            serverDebrief: envelope.reflection.serverDebrief,
            serverVersion: envelope.reflection.serverVersion,
            lastSyncedAt: syncedAt
        )
    }
}

private enum WorkoutReflectionRemoteError: Error {
    case invalidServerDate
}
