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

    private let userDefaults: UserDefaults
    private let operationProcessor: ((SyncOperation) async throws -> Void)?

    private var syncTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Singleton

    static let shared = SyncEngine()

    // MARK: - Initialization

    init(
        userDefaults: UserDefaults = .standard,
        startsNetworkMonitor: Bool = true,
        initialOnlineState: Bool = true,
        operationProcessor: ((SyncOperation) async throws -> Void)? = nil
    ) {
        self.userDefaults = userDefaults
        self.operationProcessor = operationProcessor
        self.isOnline = initialOnlineState
        if startsNetworkMonitor {
            setupNetworkMonitor()
        }
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
                    #if DEBUG
                    print("[SyncEngine] Network status: \(path.status == .satisfied ? "online" : "offline")")
                    #endif
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
                #if DEBUG
                print("[SyncEngine] Queued upload: \(entityType) \(entityId)")
                #endif
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
                #if DEBUG
                print("[SyncEngine] Queued deletion: \(entityType) \(entityId)")
                #endif
            }
        }
    }

    // MARK: - Sync Operations

    /// Sync all pending changes
    func syncPendingChanges() async {
        guard isOnline else {
            if FeatureFlags.debugSyncLogging {
                #if DEBUG
                print("[SyncEngine] Skipping sync - offline")
                #endif
            }
            return
        }

        guard !isSyncing else {
            if FeatureFlags.debugSyncLogging {
                #if DEBUG
                print("[SyncEngine] Skipping sync - already in progress")
                #endif
            }
            return
        }

        isSyncing = true
        lastError = nil

        if FeatureFlags.debugSyncLogging {
            #if DEBUG
            print("[SyncEngine] Starting sync - \(uploadQueue.count) uploads, \(deletionQueue.count) deletions")
            #endif
        }

        // Process deletions first, then uploads. Each queue removes only
        // operations whose remote side effect completed successfully.
        await processDeletions()
        await processUploads()
        updatePendingCount()

        if pendingChangesCount == 0 {
            lastSyncDate = Date()
            if FeatureFlags.debugSyncLogging {
                #if DEBUG
                print("[SyncEngine] Sync complete")
                #endif
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

                failedOperations.append(operation)
                lastError = error
                if FeatureFlags.debugSyncLogging {
                    #if DEBUG
                    print("[SyncEngine] Deletion retained after retry \(operation.retryCount): \(operation.entityType) \(operation.entityId)")
                    #endif
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

                failedOperations.append(operation)
                lastError = error
                if FeatureFlags.debugSyncLogging {
                    #if DEBUG
                    print("[SyncEngine] Upload retained after retry \(operation.retryCount): \(operation.entityType) \(operation.entityId)")
                    #endif
                }
            }
        }

        uploadQueue = failedOperations
        savePendingOperations()
    }

    /// Process a single sync operation
    private func processOperation(_ operation: SyncOperation) async throws {
        if let operationProcessor {
            try await operationProcessor(operation)
            return
        }
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
            guard let localId = UUID(uuidString: operation.entityId),
                  let sdActivity = try localRepo.getActivityByLocalId(localId) else {
                throw SyncEngineError.localRecordMissing
            }
            let activity = ActivityMapper.toCodable(sdActivity)

            if sdActivity.supabaseId == nil {
                let created = try await SupabaseActivityRepository.shared.createActivity(activity)
                try localRepo.markSynced(localId: localId, supabaseId: created.id, serverVersion: 1)
            } else {
                _ = try await SupabaseActivityRepository.shared.updateActivity(activity)
                sdActivity.markSynced(serverVersion: sdActivity.serverVersion + 1)
                try PersistenceController.shared.save()
            }

        case .delete:
            guard let id = Int(operation.entityId) else {
                throw SyncEngineError.invalidEntityIdentifier
            }
            try await SupabaseActivityRepository.shared.deleteActivity(id: id)
        }
    }

    private func processAthleteOperation(_ operation: SyncOperation) async throws {
        throw SyncEngineError.unsupportedOperation(operation.entityType)
    }

    private func processCommitmentOperation(_ operation: SyncOperation) async throws {
        throw SyncEngineError.unsupportedOperation(operation.entityType)
    }

    // MARK: - Persistence

    private let pendingOperationsKey = "SyncEngine.pendingOperations"

    private func savePendingOperations() {
        let allOperations = uploadQueue + deletionQueue

        if let data = try? JSONEncoder().encode(allOperations) {
            userDefaults.set(data, forKey: pendingOperationsKey)
        }
    }

    private func loadPendingOperations() {
        guard let data = userDefaults.data(forKey: pendingOperationsKey),
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
            #if DEBUG
            print("[SyncEngine] Background sync started with interval: \(interval)s")
            #endif
        }
    }

    /// Stop periodic background sync
    func stopBackgroundSync() {
        syncTimer?.invalidate()
        syncTimer = nil

        if FeatureFlags.debugSyncLogging {
            #if DEBUG
            print("[SyncEngine] Background sync stopped")
            #endif
        }
    }

    // MARK: - Manual Sync

    /// Force a full sync
    func forceSync() async {
        isSyncing = false // Reset to allow new sync
        await syncPendingChanges()
    }

}

private enum SyncEngineError: Error {
    case invalidEntityIdentifier
    case localRecordMissing
    case unsupportedOperation(SyncEntityType)
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
