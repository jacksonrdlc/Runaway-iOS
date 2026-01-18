//
//  SDDailyCommitment.swift
//  Runaway iOS
//
//  SwiftData model for DailyCommitment with offline-first sync support
//

import Foundation
import SwiftData

@Model
final class SDDailyCommitment {
    // MARK: - Identifiers

    /// Local UUID for offline-created commitments
    @Attribute(.unique) var localId: UUID

    /// Supabase server ID (nil for offline-created, pending sync)
    var supabaseId: Int?

    // MARK: - Commitment Data

    /// The date of the commitment (YYYY-MM-DD format stored as Date)
    var commitmentDate: Date

    /// Activity type for this commitment
    var activityTypeRaw: String

    /// Whether the commitment has been fulfilled
    var isFulfilled: Bool

    /// When the commitment was fulfilled
    var fulfilledAt: Date?

    // MARK: - Micro-Commitment Fields

    /// Commitment level (micro, mini, standard)
    var commitmentLevelRaw: String

    /// Type of micro-commitment if applicable
    var microCommitmentTypeRaw: String?

    /// Progression step for building habits
    var progressionStep: Int

    // MARK: - References

    var athleteId: Int?

    // MARK: - Timestamps

    var createdAt: Date?
    var updatedAt: Date?

    // MARK: - Sync Metadata

    var syncStatusRaw: String
    var lastModifiedLocally: Date
    var lastSyncedAt: Date?
    var serverVersion: Int
    var localVersion: Int
    var lastSyncError: String?

    // MARK: - Relationship

    @Relationship(deleteRule: .nullify, inverse: \SDAthlete.commitments)
    var athlete: SDAthlete?

    // MARK: - Computed Properties

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .synced }
        set { syncStatusRaw = newValue.rawValue }
    }

    var activityType: CommitmentActivityType {
        get { CommitmentActivityType(rawValue: activityTypeRaw) ?? .run }
        set { activityTypeRaw = newValue.rawValue }
    }

    var commitmentLevel: CommitmentLevel {
        get { CommitmentLevel(rawValue: commitmentLevelRaw) ?? .standard }
        set { commitmentLevelRaw = newValue.rawValue }
    }

    var microCommitmentType: MicroCommitmentType? {
        get {
            guard let raw = microCommitmentTypeRaw else { return nil }
            return MicroCommitmentType(rawValue: raw)
        }
        set { microCommitmentTypeRaw = newValue?.rawValue }
    }

    var isPendingSync: Bool {
        syncStatus == .pendingUpload || syncStatus == .deleted
    }

    var isToday: Bool {
        Calendar.current.isDate(commitmentDate, inSameDayAs: Date())
    }

    var commitmentDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: commitmentDate)
    }

    // MARK: - Initialization

    init(
        localId: UUID = UUID(),
        supabaseId: Int? = nil,
        commitmentDate: Date,
        activityType: CommitmentActivityType = .run,
        isFulfilled: Bool = false,
        fulfilledAt: Date? = nil,
        commitmentLevel: CommitmentLevel = .standard,
        microCommitmentType: MicroCommitmentType? = nil,
        progressionStep: Int = 0,
        athleteId: Int? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        syncStatus: SyncStatus = .pendingUpload
    ) {
        self.localId = localId
        self.supabaseId = supabaseId
        self.commitmentDate = commitmentDate
        self.activityTypeRaw = activityType.rawValue
        self.isFulfilled = isFulfilled
        self.fulfilledAt = fulfilledAt
        self.commitmentLevelRaw = commitmentLevel.rawValue
        self.microCommitmentTypeRaw = microCommitmentType?.rawValue
        self.progressionStep = progressionStep
        self.athleteId = athleteId
        self.createdAt = createdAt
        self.updatedAt = updatedAt

        // Sync metadata
        self.syncStatusRaw = syncStatus.rawValue
        self.lastModifiedLocally = Date()
        self.lastSyncedAt = nil
        self.serverVersion = 0
        self.localVersion = 1
        self.lastSyncError = nil
    }

    // MARK: - Convenience Initializers

    /// Create a standard commitment
    convenience init(athleteId: Int, activityType: CommitmentActivityType, commitmentDate: Date = Date()) {
        self.init(
            commitmentDate: Calendar.current.startOfDay(for: commitmentDate),
            activityType: activityType,
            commitmentLevel: .standard,
            athleteId: athleteId
        )
    }

    /// Create a micro commitment
    convenience init(athleteId: Int, microCommitmentType: MicroCommitmentType, commitmentDate: Date = Date()) {
        self.init(
            commitmentDate: Calendar.current.startOfDay(for: commitmentDate),
            activityType: .run,
            commitmentLevel: .micro,
            microCommitmentType: microCommitmentType,
            athleteId: athleteId
        )
    }

    // MARK: - Sync Methods

    func markModified() {
        lastModifiedLocally = Date()
        localVersion += 1
        syncStatus = .pendingUpload
        updatedAt = Date()
    }

    func markSynced(serverVersion: Int, supabaseId: Int? = nil) {
        if let id = supabaseId {
            self.supabaseId = id
        }
        self.serverVersion = serverVersion
        self.lastSyncedAt = Date()
        self.syncStatus = .synced
        self.lastSyncError = nil
    }

    func markDeleted() {
        lastModifiedLocally = Date()
        localVersion += 1
        syncStatus = .deleted
    }

    func recordSyncError(_ error: String) {
        lastSyncError = error
    }

    // MARK: - Fulfillment

    func fulfill() {
        isFulfilled = true
        fulfilledAt = Date()
        markModified()
    }

    func unfulfill() {
        isFulfilled = false
        fulfilledAt = nil
        markModified()
    }
}

// MARK: - Query Helpers

extension SDDailyCommitment {
    /// Predicate for today's commitments
    static var todayPredicate: Predicate<SDDailyCommitment> {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        return #Predicate<SDDailyCommitment> { commitment in
            commitment.commitmentDate >= startOfDay && commitment.commitmentDate < endOfDay
        }
    }

    /// Predicate for unfulfilled commitments
    static var unfulfilledPredicate: Predicate<SDDailyCommitment> {
        #Predicate<SDDailyCommitment> { commitment in
            commitment.isFulfilled == false
        }
    }

    /// Predicate for pending sync
    static var pendingSyncPredicate: Predicate<SDDailyCommitment> {
        #Predicate<SDDailyCommitment> { commitment in
            commitment.syncStatusRaw == "pendingUpload" || commitment.syncStatusRaw == "deleted"
        }
    }

    /// Predicate for commitments by athlete
    static func byAthleteId(_ athleteId: Int) -> Predicate<SDDailyCommitment> {
        #Predicate<SDDailyCommitment> { commitment in
            commitment.athleteId == athleteId
        }
    }
}
