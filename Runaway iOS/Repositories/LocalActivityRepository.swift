//
//  LocalActivityRepository.swift
//  Runaway iOS
//
//  SwiftData-backed local repository for activities
//

import Foundation
import SwiftData

/// Repository implementation using SwiftData for local persistence
@MainActor
final class LocalActivityRepository: ActivityRepositoryProtocol {

    private let context: ModelContext

    init(context: ModelContext? = nil) {
        self.context = context ?? PersistenceController.shared.mainContext
    }

    // MARK: - ActivityRepositoryProtocol

    func getActivities(userId: Int, limit: Int = 50, offset: Int = 0) async throws -> [Activity] {
        let targetUserId = userId
        var descriptor = FetchDescriptor<SDActivity>(
            predicate: #Predicate<SDActivity> { activity in
                activity.athleteId == targetUserId && activity.syncStatusRaw != "deleted"
            },
            sortBy: [SortDescriptor(\.activityDate, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        descriptor.fetchOffset = offset

        let sdActivities = try context.fetch(descriptor)
        return ActivityMapper.toCodable(sdActivities)
    }

    func getActivitiesPaginated(userId: Int, page: Int = 0, pageSize: Int = 50) async throws -> PaginatedResult<Activity> {
        let offset = page * pageSize
        let targetUserId = userId

        // Fetch one extra to determine if there are more
        var descriptor = FetchDescriptor<SDActivity>(
            predicate: #Predicate<SDActivity> { activity in
                activity.athleteId == targetUserId && activity.syncStatusRaw != "deleted"
            },
            sortBy: [SortDescriptor(\.activityDate, order: .reverse)]
        )
        descriptor.fetchLimit = pageSize + 1
        descriptor.fetchOffset = offset

        let sdActivities = try context.fetch(descriptor)
        let hasMore = sdActivities.count > pageSize
        let items = hasMore ? Array(sdActivities.dropLast()) : sdActivities

        // Get total count
        let countDescriptor = FetchDescriptor<SDActivity>(
            predicate: #Predicate<SDActivity> { activity in
                activity.athleteId == targetUserId && activity.syncStatusRaw != "deleted"
            }
        )
        let totalCount = try context.fetchCount(countDescriptor)

        return PaginatedResult(
            items: ActivityMapper.toCodable(items),
            hasMore: hasMore,
            page: page,
            pageSize: pageSize,
            totalCount: totalCount
        )
    }

    func getAllActivities(userId: Int) async throws -> [Activity] {
        let targetUserId = userId
        let descriptor = FetchDescriptor<SDActivity>(
            predicate: #Predicate<SDActivity> { activity in
                activity.athleteId == targetUserId && activity.syncStatusRaw != "deleted"
            },
            sortBy: [SortDescriptor(\.activityDate, order: .reverse)]
        )

        let sdActivities = try context.fetch(descriptor)
        return ActivityMapper.toCodable(sdActivities)
    }

    func getActivity(id: Int) async throws -> Activity {
        let targetId = id
        var descriptor = FetchDescriptor<SDActivity>(
            predicate: #Predicate<SDActivity> { activity in
                activity.supabaseId == targetId
            }
        )
        descriptor.fetchLimit = 1

        guard let sdActivity = try context.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }

        return ActivityMapper.toCodable(sdActivity)
    }

    func createActivity(_ activity: Activity) async throws -> Activity {
        let sdActivity = ActivityMapper.toSwiftData(activity)
        sdActivity.syncStatus = .pendingUpload
        sdActivity.lastModifiedLocally = Date()

        context.insert(sdActivity)
        try context.save()

        return ActivityMapper.toCodable(sdActivity)
    }

    func updateActivity(_ activity: Activity) async throws -> Activity {
        let targetId = activity.id
        var descriptor = FetchDescriptor<SDActivity>(
            predicate: #Predicate<SDActivity> { sdActivity in
                sdActivity.supabaseId == targetId
            }
        )
        descriptor.fetchLimit = 1

        guard let existingActivity = try context.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }

        ActivityMapper.update(existingActivity, from: activity)
        existingActivity.markModified()

        try context.save()

        return ActivityMapper.toCodable(existingActivity)
    }

    func deleteActivity(id: Int) async throws {
        let targetId = id
        var descriptor = FetchDescriptor<SDActivity>(
            predicate: #Predicate<SDActivity> { activity in
                activity.supabaseId == targetId
            }
        )
        descriptor.fetchLimit = 1

        guard let sdActivity = try context.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }

        // If it has a server ID, mark for deletion sync
        // If it's a local-only record, delete immediately
        if sdActivity.supabaseId != nil {
            sdActivity.markDeleted()
        } else {
            context.delete(sdActivity)
        }

        try context.save()
    }

    func getActivitiesByDateRange(userId: Int, startDate: Date, endDate: Date) async throws -> [Activity] {
        let targetUserId = userId
        let targetStartDate = startDate
        let targetEndDate = endDate
        let descriptor = FetchDescriptor<SDActivity>(
            predicate: #Predicate<SDActivity> { activity in
                activity.athleteId == targetUserId &&
                activity.syncStatusRaw != "deleted" &&
                activity.activityDate != nil &&
                activity.activityDate! >= targetStartDate &&
                activity.activityDate! <= targetEndDate
            },
            sortBy: [SortDescriptor(\.activityDate, order: .reverse)]
        )

        let sdActivities = try context.fetch(descriptor)
        return ActivityMapper.toCodable(sdActivities)
    }

    func getActivitiesByType(userId: Int, activityTypeId: Int) async throws -> [Activity] {
        let targetUserId = userId
        let targetTypeId = activityTypeId
        let descriptor = FetchDescriptor<SDActivity>(
            predicate: #Predicate<SDActivity> { activity in
                activity.athleteId == targetUserId &&
                activity.syncStatusRaw != "deleted" &&
                activity.activityTypeId == targetTypeId
            },
            sortBy: [SortDescriptor(\.activityDate, order: .reverse)]
        )

        let sdActivities = try context.fetch(descriptor)
        return ActivityMapper.toCodable(sdActivities)
    }

    // MARK: - Local-Only Methods

    /// Get activity by local UUID
    func getActivityByLocalId(_ localId: UUID) throws -> SDActivity? {
        var descriptor = FetchDescriptor<SDActivity>(
            predicate: #Predicate<SDActivity> { activity in
                activity.localId == localId
            }
        )
        descriptor.fetchLimit = 1

        return try context.fetch(descriptor).first
    }

    /// Get all activities pending sync
    func getPendingSyncActivities() throws -> [SDActivity] {
        let descriptor = FetchDescriptor<SDActivity>(
            predicate: SDActivity.pendingSyncPredicate,
            sortBy: [SortDescriptor(\.lastModifiedLocally)]
        )

        return try context.fetch(descriptor)
    }

    /// Get activities marked for deletion
    func getDeletedActivities() throws -> [SDActivity] {
        let descriptor = FetchDescriptor<SDActivity>(
            predicate: #Predicate<SDActivity> { activity in
                activity.syncStatusRaw == "deleted"
            }
        )

        return try context.fetch(descriptor)
    }

    /// Permanently remove activities that have been synced for deletion
    func purgeDeletedActivities() throws {
        let activities = try getDeletedActivities()
        for activity in activities where activity.syncStatus == .synced {
            context.delete(activity)
        }
        try context.save()
    }

    /// Save or update an activity from server data
    func upsertFromServer(_ activity: Activity) throws {
        let targetId = activity.id
        var descriptor = FetchDescriptor<SDActivity>(
            predicate: #Predicate<SDActivity> { sdActivity in
                sdActivity.supabaseId == targetId
            }
        )
        descriptor.fetchLimit = 1

        if let existing = try context.fetch(descriptor).first {
            // Update existing
            ActivityMapper.update(existing, from: activity)
            existing.markSynced(serverVersion: existing.serverVersion + 1)
        } else {
            // Create new
            let sdActivity = ActivityMapper.toSwiftData(activity)
            sdActivity.markSynced(serverVersion: 1, supabaseId: activity.id)
            context.insert(sdActivity)
        }

        try context.save()
    }

    /// Batch upsert from server
    func batchUpsertFromServer(_ activities: [Activity]) throws {
        for activity in activities {
            try upsertFromServer(activity)
        }
    }

    /// Mark activity as synced after successful upload
    func markSynced(localId: UUID, supabaseId: Int, serverVersion: Int) throws {
        guard let activity = try getActivityByLocalId(localId) else {
            throw RepositoryError.notFound
        }

        activity.markSynced(serverVersion: serverVersion, supabaseId: supabaseId)
        try context.save()
    }
}
