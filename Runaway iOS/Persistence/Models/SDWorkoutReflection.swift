import Foundation
import SwiftData

@Model
final class SDWorkoutReflection {
    @Attribute(.unique) var localId: UUID
    @Attribute(.unique) var ownerActivityKey: String
    var activityId: Int
    var userId: UUID
    var athleteId: Int
    var perceivedEffort: Int
    var bodyStateRaw: String
    var moodRaw: String
    var conditionTagsRaw: [String]
    var note: String?
    var localDebrief: String
    var serverDebrief: String?
    var serverDebriefGeneratedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var syncStatusRaw: String
    var lastModifiedLocally: Date
    var lastSyncedAt: Date?
    var serverVersion: Int
    var localVersion: Int
    var lastSyncError: String?

    init(reflection: WorkoutReflection) {
        localId = reflection.id
        ownerActivityKey = Self.ownerActivityKey(
            userId: reflection.userId,
            activityId: reflection.activityId
        )
        activityId = reflection.activityId
        userId = reflection.userId
        athleteId = reflection.athleteId
        perceivedEffort = reflection.perceivedEffort
        bodyStateRaw = reflection.bodyState.rawValue
        moodRaw = reflection.mood.rawValue
        conditionTagsRaw = reflection.conditionTags.map(\.rawValue)
        note = reflection.note
        localDebrief = reflection.localDebrief
        serverDebrief = reflection.serverDebrief
        serverDebriefGeneratedAt = nil
        createdAt = reflection.createdAt
        updatedAt = reflection.updatedAt
        syncStatusRaw = reflection.syncMetadata.syncStatus.rawValue
        lastModifiedLocally = reflection.syncMetadata.lastModifiedLocally
        lastSyncedAt = reflection.syncMetadata.lastSyncedAt
        serverVersion = reflection.syncMetadata.serverVersion
        localVersion = reflection.syncMetadata.localVersion
        lastSyncError = reflection.syncMetadata.lastSyncError
    }

    static func ownerActivityKey(userId: UUID, activityId: Int) -> String {
        "\(userId.uuidString.lowercased()):\(activityId)"
    }

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .pendingUpload }
        set { syncStatusRaw = newValue.rawValue }
    }

    static var pendingSyncPredicate: Predicate<SDWorkoutReflection> {
        #Predicate<SDWorkoutReflection> { reflection in
            reflection.syncStatusRaw == "pendingUpload" || reflection.syncStatusRaw == "deleted"
        }
    }
}
