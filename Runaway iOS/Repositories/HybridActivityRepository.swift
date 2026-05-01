//
//  HybridActivityRepository.swift
//  Runaway iOS
//
//  Hybrid repository that orchestrates local SwiftData and remote Supabase
//

import Foundation

/// Hybrid repository that uses local-first pattern:
/// - Reads from local SwiftData first
/// - Writes to local immediately, then queues for cloud sync
/// - Background sync keeps local and remote in sync
@MainActor
final class HybridActivityRepository: ActivityRepositoryProtocol {

    private let localRepository: LocalActivityRepository
    private let remoteRepository: SupabaseActivityRepository
    private weak var syncEngine: SyncEngine?

    init(
        localRepository: LocalActivityRepository? = nil,
        remoteRepository: SupabaseActivityRepository? = nil,
        syncEngine: SyncEngine? = nil
    ) {
        self.localRepository = localRepository ?? LocalActivityRepository()
        self.remoteRepository = remoteRepository ?? SupabaseActivityRepository.shared
        self.syncEngine = syncEngine
    }

    // MARK: - ActivityRepositoryProtocol

    /// Get activities: local first, then optionally refresh from server
    func getActivities(userId: Int, limit: Int = 50, offset: Int = 0) async throws -> [Activity] {
        // Return local data immediately
        let localActivities = try await localRepository.getActivities(userId: userId, limit: limit, offset: offset)

        // Trigger background sync if we have few local results
        if localActivities.isEmpty || offset == 0 {
            Task {
                await refreshFromServer(userId: userId, limit: limit)
            }
        }

        return localActivities
    }

    /// Get paginated activities: local first
    func getActivitiesPaginated(userId: Int, page: Int = 0, pageSize: Int = 50) async throws -> PaginatedResult<Activity> {
        // Return local data immediately
        let localResult = try await localRepository.getActivitiesPaginated(userId: userId, page: page, pageSize: pageSize)

        // Trigger background sync on first page
        if page == 0 {
            Task {
                await refreshFromServer(userId: userId, limit: pageSize * 2)
            }
        }

        return localResult
    }

    /// Get all activities: local first, then sync
    func getAllActivities(userId: Int) async throws -> [Activity] {
        // Return local data immediately
        let localActivities = try await localRepository.getAllActivities(userId: userId)

        // Trigger full sync in background
        Task {
            await fullSync(userId: userId)
        }

        return localActivities
    }

    /// Get single activity: local first
    func getActivity(id: Int) async throws -> Activity {
        do {
            return try await localRepository.getActivity(id: id)
        } catch RepositoryError.notFound {
            // Try to fetch from server
            let activity = try await remoteRepository.getActivity(id: id)
            try localRepository.upsertFromServer(activity)
            return activity
        }
    }

    /// Create activity: local first, then queue sync
    func createActivity(_ activity: Activity) async throws -> Activity {
        // Save locally first
        let savedActivity = try await localRepository.createActivity(activity)

        // Queue for sync
        syncEngine?.queueUpload(entityType: .activity, entityId: String(activity.id))

        // Try immediate sync if online
        Task {
            await attemptImmediateSync(activity: savedActivity)
        }

        return savedActivity
    }

    /// Update activity: local first, then queue sync
    func updateActivity(_ activity: Activity) async throws -> Activity {
        // Update locally first
        let updatedActivity = try await localRepository.updateActivity(activity)

        // Queue for sync
        syncEngine?.queueUpload(entityType: .activity, entityId: String(activity.id))

        // Try immediate sync if online
        Task {
            await attemptImmediateUpdate(activity: updatedActivity)
        }

        return updatedActivity
    }

    /// Delete activity: local first, then queue sync
    func deleteActivity(id: Int) async throws {
        // Mark as deleted locally
        try await localRepository.deleteActivity(id: id)

        // Queue deletion for sync
        syncEngine?.queueDeletion(entityType: .activity, entityId: String(id))

        // Try immediate sync if online
        Task {
            await attemptImmediateDeletion(id: id)
        }
    }

    /// Get activities by date range: local first
    func getActivitiesByDateRange(userId: Int, startDate: Date, endDate: Date) async throws -> [Activity] {
        return try await localRepository.getActivitiesByDateRange(userId: userId, startDate: startDate, endDate: endDate)
    }

    /// Get activities by type: local first
    func getActivitiesByType(userId: Int, activityTypeId: Int) async throws -> [Activity] {
        return try await localRepository.getActivitiesByType(userId: userId, activityTypeId: activityTypeId)
    }

    // MARK: - Sync Operations

    /// Refresh local data from server
    private func refreshFromServer(userId: Int, limit: Int) async {
        guard syncEngine?.isOnline ?? true else { return }

        do {
            let remoteActivities = try await remoteRepository.getActivities(userId: userId, limit: limit, offset: 0)
            try localRepository.batchUpsertFromServer(remoteActivities)

            if FeatureFlags.debugSyncLogging {
                #if DEBUG
                print("[HybridActivityRepository] Refreshed \(remoteActivities.count) activities from server")
                #endif
            }
        } catch {
            if FeatureFlags.debugSyncLogging {
                #if DEBUG
                print("[HybridActivityRepository] Refresh failed: \(error)")
                #endif
            }
        }
    }

    /// Full sync: upload pending, then download all
    private func fullSync(userId: Int) async {
        guard syncEngine?.isOnline ?? true else { return }

        do {
            // Upload pending changes first
            let pendingActivities = try localRepository.getPendingSyncActivities()
            for activity in pendingActivities {
                if activity.syncStatus == .pendingUpload {
                    let codableActivity = ActivityMapper.toCodable(activity)
                    if activity.supabaseId == nil {
                        // Create on server
                        let created = try await remoteRepository.createActivity(codableActivity)
                        try localRepository.markSynced(localId: activity.localId, supabaseId: created.id, serverVersion: 1)
                    } else {
                        // Update on server
                        _ = try await remoteRepository.updateActivity(codableActivity)
                        activity.markSynced(serverVersion: activity.serverVersion + 1)
                    }
                } else if activity.syncStatus == .deleted {
                    if let supabaseId = activity.supabaseId {
                        try await remoteRepository.deleteActivity(id: supabaseId)
                    }
                    // Remove locally after successful deletion
                    PersistenceController.shared.mainContext.delete(activity)
                }
            }

            // Download all from server
            let remoteActivities = try await remoteRepository.getAllActivities(userId: userId)
            try localRepository.batchUpsertFromServer(remoteActivities)

            try PersistenceController.shared.save()

            if FeatureFlags.debugSyncLogging {
                #if DEBUG
                print("[HybridActivityRepository] Full sync complete")
                #endif
            }
        } catch {
            if FeatureFlags.debugSyncLogging {
                #if DEBUG
                print("[HybridActivityRepository] Full sync failed: \(error)")
                #endif
            }
        }
    }

    /// Attempt immediate sync after create
    private func attemptImmediateSync(activity: Activity) async {
        guard syncEngine?.isOnline ?? true else { return }

        do {
            let created = try await remoteRepository.createActivity(activity)

            // Find local activity by matching data since we don't have local ID here
            if let localActivity = try? localRepository.getActivityByLocalId(UUID()) {
                try localRepository.markSynced(localId: localActivity.localId, supabaseId: created.id, serverVersion: 1)
            }

            if FeatureFlags.debugSyncLogging {
                #if DEBUG
                print("[HybridActivityRepository] Immediate sync successful for activity \(created.id)")
                #endif
            }
        } catch {
            if FeatureFlags.debugSyncLogging {
                #if DEBUG
                print("[HybridActivityRepository] Immediate sync failed: \(error)")
                #endif
            }
            // Activity remains in pending state, will be synced later
        }
    }

    /// Attempt immediate update sync
    private func attemptImmediateUpdate(activity: Activity) async {
        guard syncEngine?.isOnline ?? true else { return }

        do {
            _ = try await remoteRepository.updateActivity(activity)

            if FeatureFlags.debugSyncLogging {
                #if DEBUG
                print("[HybridActivityRepository] Immediate update sync successful")
                #endif
            }
        } catch {
            if FeatureFlags.debugSyncLogging {
                #if DEBUG
                print("[HybridActivityRepository] Immediate update sync failed: \(error)")
                #endif
            }
        }
    }

    /// Attempt immediate deletion sync
    private func attemptImmediateDeletion(id: Int) async {
        guard syncEngine?.isOnline ?? true else { return }

        do {
            try await remoteRepository.deleteActivity(id: id)

            // Purge local record
            try localRepository.purgeDeletedActivities()

            if FeatureFlags.debugSyncLogging {
                #if DEBUG
                print("[HybridActivityRepository] Immediate deletion sync successful")
                #endif
            }
        } catch {
            if FeatureFlags.debugSyncLogging {
                #if DEBUG
                print("[HybridActivityRepository] Immediate deletion sync failed: \(error)")
                #endif
            }
        }
    }
}
