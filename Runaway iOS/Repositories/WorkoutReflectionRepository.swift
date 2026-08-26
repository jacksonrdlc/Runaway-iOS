import Foundation
import SwiftData

@MainActor
protocol WorkoutReflectionRepositoryProtocol {
    func reflection(activityId: Int, userId: UUID) throws -> WorkoutReflection?
    func reflection(localID: UUID) throws -> WorkoutReflection?
    func upsert(_ reflection: WorkoutReflection) throws
    func markSynced(localID: UUID, serverUpdatedAt: Date) throws
    func applyServerDebrief(localID: UUID, content: String, generatedAt: Date) throws
    func delete(activityId: Int, userId: UUID) throws
}

@MainActor
final class LocalWorkoutReflectionRepository: WorkoutReflectionRepositoryProtocol {
    private let context: ModelContext

    init(context: ModelContext? = nil) {
        self.context = context ?? PersistenceController.shared.mainContext
    }

    func reflection(activityId: Int, userId: UUID) throws -> WorkoutReflection? {
        let key = SDWorkoutReflection.ownerActivityKey(userId: userId, activityId: activityId)
        var descriptor = FetchDescriptor<SDWorkoutReflection>(
            predicate: #Predicate<SDWorkoutReflection> { reflection in
                reflection.ownerActivityKey == key
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first.map(toDomain)
    }

    func reflection(localID: UUID) throws -> WorkoutReflection? {
        var descriptor = FetchDescriptor<SDWorkoutReflection>(
            predicate: #Predicate<SDWorkoutReflection> { reflection in
                reflection.localId == localID
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first.map(toDomain)
    }

    func upsert(_ reflection: WorkoutReflection) throws {
        let key = SDWorkoutReflection.ownerActivityKey(
            userId: reflection.userId,
            activityId: reflection.activityId
        )
        var descriptor = FetchDescriptor<SDWorkoutReflection>(
            predicate: #Predicate<SDWorkoutReflection> { stored in
                stored.ownerActivityKey == key
            }
        )
        descriptor.fetchLimit = 1

        if let stored = try context.fetch(descriptor).first {
            stored.perceivedEffort = reflection.perceivedEffort
            stored.bodyStateRaw = reflection.bodyState.rawValue
            stored.moodRaw = reflection.mood.rawValue
            stored.conditionTagsRaw = reflection.conditionTags.map(\.rawValue)
            stored.note = reflection.note
            stored.localDebrief = reflection.localDebrief
            stored.serverDebrief = nil
            stored.serverDebriefGeneratedAt = nil
            stored.updatedAt = reflection.updatedAt
            stored.lastModifiedLocally = reflection.updatedAt
            stored.localVersion += 1
            stored.syncStatus = .pendingUpload
            stored.lastSyncError = nil
        } else {
            context.insert(SDWorkoutReflection(reflection: reflection))
        }

        try context.save()
    }

    func markSynced(localID: UUID, serverUpdatedAt: Date) throws {
        guard let stored = try storedReflection(localID: localID) else {
            throw RepositoryError.notFound
        }

        stored.syncStatus = .synced
        stored.lastSyncedAt = serverUpdatedAt
        stored.serverVersion += 1
        stored.lastSyncError = nil
        try context.save()
    }

    func applyServerDebrief(
        localID: UUID,
        content: String,
        generatedAt: Date
    ) throws {
        guard let stored = try storedReflection(localID: localID) else {
            throw RepositoryError.notFound
        }

        stored.serverDebrief = content
        stored.serverDebriefGeneratedAt = generatedAt
        try context.save()
    }

    func delete(activityId: Int, userId: UUID) throws {
        let key = SDWorkoutReflection.ownerActivityKey(userId: userId, activityId: activityId)
        var descriptor = FetchDescriptor<SDWorkoutReflection>(
            predicate: #Predicate<SDWorkoutReflection> { reflection in
                reflection.ownerActivityKey == key
            }
        )
        descriptor.fetchLimit = 1

        if let stored = try context.fetch(descriptor).first {
            context.delete(stored)
            try context.save()
        }
    }

    private func storedReflection(localID: UUID) throws -> SDWorkoutReflection? {
        var descriptor = FetchDescriptor<SDWorkoutReflection>(
            predicate: #Predicate<SDWorkoutReflection> { reflection in
                reflection.localId == localID
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func toDomain(_ stored: SDWorkoutReflection) -> WorkoutReflection {
        WorkoutReflection(
            id: stored.localId,
            activityId: stored.activityId,
            userId: stored.userId,
            athleteId: stored.athleteId,
            perceivedEffort: stored.perceivedEffort,
            bodyState: ReflectionBodyState(rawValue: stored.bodyStateRaw) ?? .good,
            mood: ReflectionMood(rawValue: stored.moodRaw) ?? .same,
            conditionTags: stored.conditionTagsRaw.compactMap(ReflectionCondition.init(rawValue:)),
            note: stored.note,
            localDebrief: stored.localDebrief,
            serverDebrief: stored.serverDebrief,
            createdAt: stored.createdAt,
            updatedAt: stored.updatedAt,
            syncMetadata: SyncMetadata(
                lastModifiedLocally: stored.lastModifiedLocally,
                lastSyncedAt: stored.lastSyncedAt,
                serverVersion: stored.serverVersion,
                localVersion: stored.localVersion,
                syncStatus: stored.syncStatus,
                lastSyncError: stored.lastSyncError
            )
        )
    }
}
