//
//  SyncEngine.swift
//  Runaway iOS
//
//  Manages synchronization between local SwiftData and remote Supabase
//

import Foundation
import Network
import Combine

/// Manages offline-first synchronization with cloud backend
@MainActor
final class SyncEngine: ObservableObject {

    // MARK: - Published State

    /// Whether a sync is currently in progress
    @Published private(set) var isSyncing = false

    /// Number of changes pending upload
    @Published private(set) var pendingChangesCount = 0

    /// Current network connectivity status
    @Published private(set) var isOnline = true

    /// Last successful sync date
    @Published private(set) var lastSyncDate: Date?

    /// Current sync error (if any)
    @Published private(set) var lastError: Error?

    // MARK: - Private Properties

    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.runaway.syncengine.network")

    private var uploadQueue: [SyncOperation] = []
    private var deletionQueue: [SyncOperation] = []

    private let maxRetryCount = 3
    private let retryDelay: TimeInterval = 5.0

    private var syncTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Singleton

    static let shared = SyncEngine()

    // MARK: - Initialization

    private init() {
        setupNetworkMonitor()
        loadPendingOperations()
    }

    deinit {
        networkMonitor.cancel()
        syncTimer?.invalidate()
    }

    // MARK: - Network Monitoring

    private func setupNetworkMonitor() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let wasOnline = self?.isOnline ?? false
                self?.isOnline = path.status == .satisfied

                if FeatureFlags.debugSyncLogging {
                    print("[SyncEngine] Network status: \(path.status == .satisfied ? "online" : "offline")")
                }

                // Trigger sync when coming back online
                if self?.isOnline == true && !wasOnline {
                    await self?.syncPendingChanges()
                }
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }

    // MARK: - Queue Management

    /// Queue an entity for upload
    func queueUpload(entityType: SyncEntityType, entityId: String) {
        let operation = SyncOperation(
            entityType: entityType,
            entityId: entityId,
            operationType: .create
        )

        // Avoid duplicates
        if !uploadQueue.contains(where: { $0.entityType == entityType && $0.entityId == entityId }) {
            uploadQueue.append(operation)
            updatePendingCount()
            savePendingOperations()

            if FeatureFlags.debugSyncLogging {
                print("[SyncEngine] Queued upload: \(entityType) \(entityId)")
            }
        }
    }

    /// Queue an entity for deletion
    func queueDeletion(entityType: SyncEntityType, entityId: String) {
        let operation = SyncOperation(
            entityType: entityType,
            entityId: entityId,
            operationType: .delete
        )

        // Remove any pending upload for this entity
        uploadQueue.removeAll { $0.entityType == entityType && $0.entityId == entityId }

        // Avoid duplicate deletions
        if !deletionQueue.contains(where: { $0.entityType == entityType && $0.entityId == entityId }) {
            deletionQueue.append(operation)
            updatePendingCount()
            savePendingOperations()

            if FeatureFlags.debugSyncLogging {
                print("[SyncEngine] Queued deletion: \(entityType) \(entityId)")
            }
        }
    }

    // MARK: - Sync Operations

    /// Sync all pending changes
    func syncPendingChanges() async {
        guard isOnline else {
            if FeatureFlags.debugSyncLogging {
                print("[SyncEngine] Skipping sync - offline")
            }
            return
        }

        guard !isSyncing else {
            if FeatureFlags.debugSyncLogging {
                print("[SyncEngine] Skipping sync - already in progress")
            }
            return
        }

        isSyncing = true
        lastError = nil

        if FeatureFlags.debugSyncLogging {
            print("[SyncEngine] Starting sync - \(uploadQueue.count) uploads, \(deletionQueue.count) deletions")
        }

        do {
            // Process deletions first
            await processDeletions()

            // Then process uploads
            await processUploads()

            lastSyncDate = Date()
            updatePendingCount()

            if FeatureFlags.debugSyncLogging {
                print("[SyncEngine] Sync complete")
            }
        }

        isSyncing = false
    }

    /// Process pending deletions
    private func processDeletions() async {
        var failedOperations: [SyncOperation] = []

        for var operation in deletionQueue {
            do {
                try await processOperation(operation)
            } catch {
                operation.retryCount += 1
                operation.lastError = error.localizedDescription
                operation.lastAttemptAt = Date()

                if operation.retryCount < maxRetryCount {
                    failedOperations.append(operation)
                } else {
                    if FeatureFlags.debugSyncLogging {
                        print("[SyncEngine] Deletion failed after \(maxRetryCount) retries: \(operation.entityType) \(operation.entityId)")
                    }
                }
            }
        }

        deletionQueue = failedOperations
        savePendingOperations()
    }

    /// Process pending uploads
    private func processUploads() async {
        var failedOperations: [SyncOperation] = []

        for var operation in uploadQueue {
            do {
                try await processOperation(operation)
            } catch {
                operation.retryCount += 1
                operation.lastError = error.localizedDescription
                operation.lastAttemptAt = Date()

                if operation.retryCount < maxRetryCount {
                    failedOperations.append(operation)
                } else {
                    if FeatureFlags.debugSyncLogging {
                        print("[SyncEngine] Upload failed after \(maxRetryCount) retries: \(operation.entityType) \(operation.entityId)")
                    }
                }
            }
        }

        uploadQueue = failedOperations
        savePendingOperations()
    }

    /// Process a single sync operation
    private func processOperation(_ operation: SyncOperation) async throws {
        switch operation.entityType {
        case .activity:
            try await processActivityOperation(operation)
        case .athlete:
            try await processAthleteOperation(operation)
        case .dailyCommitment:
            try await processCommitmentOperation(operation)
        }
    }

    private func processActivityOperation(_ operation: SyncOperation) async throws {
        let localRepo = LocalActivityRepository()

        switch operation.operationType {
        case .create, .update:
            if let localId = UUID(uuidString: operation.entityId),
               let sdActivity = try localRepo.getActivityByLocalId(localId) {
                let activity = ActivityMapper.toCodable(sdActivity)

                if sdActivity.supabaseId == nil {
                    // Create on server
                    let created = try await SupabaseActivityRepository.shared.createActivity(activity)
                    try localRepo.markSynced(localId: localId, supabaseId: created.id, serverVersion: 1)
                } else {
                    // Update on server
                    _ = try await SupabaseActivityRepository.shared.updateActivity(activity)
                    sdActivity.markSynced(serverVersion: sdActivity.serverVersion + 1)
                    try PersistenceController.shared.save()
                }
            }

        case .delete:
            if let id = Int(operation.entityId) {
                try await SupabaseActivityRepository.shared.deleteActivity(id: id)
                try localRepo.purgeDeletedActivities()
            }
        }
    }

    private func processAthleteOperation(_ operation: SyncOperation) async throws {
        // Athlete sync implementation
        // Similar pattern to activity
    }

    private func processCommitmentOperation(_ operation: SyncOperation) async throws {
        // Commitment sync implementation
        // Similar pattern to activity
    }

    // MARK: - Persistence

    private let pendingOperationsKey = "SyncEngine.pendingOperations"

    private func savePendingOperations() {
        let allOperations = uploadQueue + deletionQueue

        if let data = try? JSONEncoder().encode(allOperations) {
            UserDefaults.standard.set(data, forKey: pendingOperationsKey)
        }
    }

    private func loadPendingOperations() {
        guard let data = UserDefaults.standard.data(forKey: pendingOperationsKey),
              let operations = try? JSONDecoder().decode([SyncOperation].self, from: data) else {
            return
        }

        for operation in operations {
            if operation.operationType == .delete {
                deletionQueue.append(operation)
            } else {
                uploadQueue.append(operation)
            }
        }

        updatePendingCount()
    }

    private func updatePendingCount() {
        pendingChangesCount = uploadQueue.count + deletionQueue.count
    }

    // MARK: - Background Sync

    /// Start periodic background sync
    func startBackgroundSync(interval: TimeInterval = 300) {
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.syncPendingChanges()
            }
        }

        if FeatureFlags.debugSyncLogging {
            print("[SyncEngine] Background sync started with interval: \(interval)s")
        }
    }

    /// Stop periodic background sync
    func stopBackgroundSync() {
        syncTimer?.invalidate()
        syncTimer = nil

        if FeatureFlags.debugSyncLogging {
            print("[SyncEngine] Background sync stopped")
        }
    }

    // MARK: - Manual Sync

    /// Force a full sync
    func forceSync() async {
        isSyncing = false // Reset to allow new sync
        await syncPendingChanges()
    }

    /// Clear all pending operations (use with caution)
    func clearPendingOperations() {
        uploadQueue.removeAll()
        deletionQueue.removeAll()
        updatePendingCount()
        savePendingOperations()

        if FeatureFlags.debugSyncLogging {
            print("[SyncEngine] Cleared all pending operations")
        }
    }
}

// MARK: - Sync Status View Model

extension SyncEngine {
    /// Human-readable sync status
    var statusText: String {
        if isSyncing {
            return "Syncing..."
        } else if !isOnline {
            return "Offline"
        } else if pendingChangesCount > 0 {
            return "\(pendingChangesCount) pending"
        } else if let date = lastSyncDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            return "Synced \(formatter.localizedString(for: date, relativeTo: Date()))"
        } else {
            return "Ready"
        }
    }

    /// Color indicator for sync status
    var statusColor: String {
        if !isOnline {
            return "gray"
        } else if isSyncing {
            return "blue"
        } else if pendingChangesCount > 0 {
            return "orange"
        } else if lastError != nil {
            return "red"
        } else {
            return "green"
        }
    }
}
