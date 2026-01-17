//
//  SyncTypes.swift
//  Runaway iOS
//
//  SwiftData sync metadata types for offline-first architecture
//

import Foundation

// MARK: - Sync Status

/// Represents the synchronization state of a local record
enum SyncStatus: String, Codable {
    /// Record is fully synced with server
    case synced

    /// Record was created or modified locally, pending upload
    case pendingUpload

    /// Server has newer version, pending download/merge
    case pendingDownload

    /// Local and server versions conflict, needs resolution
    case conflict

    /// Record marked for deletion, pending server sync
    case deleted
}

// MARK: - Sync Metadata

/// Metadata for tracking sync state of a record
struct SyncMetadata: Codable {
    /// When the record was last modified locally
    var lastModifiedLocally: Date

    /// When the record was last successfully synced with server
    var lastSyncedAt: Date?

    /// Server-side version number for conflict detection
    var serverVersion: Int

    /// Local version number, incremented on each local change
    var localVersion: Int

    /// Current sync status
    var syncStatus: SyncStatus

    /// Error message if sync failed
    var lastSyncError: String?

    init(
        lastModifiedLocally: Date = Date(),
        lastSyncedAt: Date? = nil,
        serverVersion: Int = 0,
        localVersion: Int = 1,
        syncStatus: SyncStatus = .pendingUpload,
        lastSyncError: String? = nil
    ) {
        self.lastModifiedLocally = lastModifiedLocally
        self.lastSyncedAt = lastSyncedAt
        self.serverVersion = serverVersion
        self.localVersion = localVersion
        self.syncStatus = syncStatus
        self.lastSyncError = lastSyncError
    }

    /// Mark as synced with current server version
    mutating func markSynced(serverVersion: Int) {
        self.syncStatus = .synced
        self.lastSyncedAt = Date()
        self.serverVersion = serverVersion
        self.lastSyncError = nil
    }

    /// Mark as modified locally
    mutating func markModified() {
        self.lastModifiedLocally = Date()
        self.localVersion += 1
        self.syncStatus = .pendingUpload
    }

    /// Mark as deleted (pending deletion sync)
    mutating func markDeleted() {
        self.lastModifiedLocally = Date()
        self.localVersion += 1
        self.syncStatus = .deleted
    }

    /// Mark as having a conflict
    mutating func markConflict() {
        self.syncStatus = .conflict
    }

    /// Record sync error
    mutating func recordError(_ error: String) {
        self.lastSyncError = error
    }
}

// MARK: - Sync Operation

/// Represents a pending sync operation
struct SyncOperation: Codable, Identifiable {
    let id: UUID
    let entityType: SyncEntityType
    let entityId: String
    let operationType: SyncOperationType
    let createdAt: Date
    var retryCount: Int
    var lastAttemptAt: Date?
    var lastError: String?

    init(
        entityType: SyncEntityType,
        entityId: String,
        operationType: SyncOperationType
    ) {
        self.id = UUID()
        self.entityType = entityType
        self.entityId = entityId
        self.operationType = operationType
        self.createdAt = Date()
        self.retryCount = 0
        self.lastAttemptAt = nil
        self.lastError = nil
    }
}

/// Types of entities that can be synced
enum SyncEntityType: String, Codable {
    case activity
    case athlete
    case dailyCommitment
}

/// Types of sync operations
enum SyncOperationType: String, Codable {
    case create
    case update
    case delete
}

// MARK: - Conflict Resolution

/// Strategy for resolving sync conflicts
enum ConflictResolutionStrategy: String, Codable {
    /// Server version always wins
    case serverWins

    /// Local version always wins
    case localWins

    /// Most recently modified version wins
    case lastWriteWins

    /// Prompt user to resolve manually
    case manual
}

/// Represents a sync conflict that needs resolution
struct SyncConflict: Identifiable {
    let id: UUID
    let entityType: SyncEntityType
    let entityId: String
    let localData: Data
    let serverData: Data
    let localModifiedAt: Date
    let serverModifiedAt: Date
    let createdAt: Date

    init(
        entityType: SyncEntityType,
        entityId: String,
        localData: Data,
        serverData: Data,
        localModifiedAt: Date,
        serverModifiedAt: Date
    ) {
        self.id = UUID()
        self.entityType = entityType
        self.entityId = entityId
        self.localData = localData
        self.serverData = serverData
        self.localModifiedAt = localModifiedAt
        self.serverModifiedAt = serverModifiedAt
        self.createdAt = Date()
    }
}
