//
//  SDAthlete.swift
//  Runaway iOS
//
//  SwiftData model for Athlete with offline-first sync support
//

import Foundation
import SwiftData

@Model
final class SDAthlete {
    // MARK: - Identifiers

    /// Local UUID for offline-created athletes
    @Attribute(.unique) var localId: UUID

    /// Supabase server ID
    var supabaseId: Int?

    /// Auth user ID (links to Supabase Auth)
    var authUserId: UUID?

    // MARK: - Profile Data

    var firstName: String?
    var lastName: String?
    var email: String?
    var sex: String?
    var profileMedium: String?
    var profile: String?

    // MARK: - Location

    var city: String?
    var state: String?
    var country: String?

    // MARK: - Athletic Data

    var ftp: Int?
    var weight: Double?
    var premium: Bool

    // MARK: - Social

    var friendCount: Int?
    var followerCount: Int?
    var mutualFriendCount: Int?

    // MARK: - Preferences

    var datePreference: String?
    var athleteDescription: String?

    // MARK: - Strava Connection

    var stravaConnected: Bool
    var stravaConnectedAt: Date?
    var stravaDisconnectedAt: Date?

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

    // MARK: - Relationships

    @Relationship(deleteRule: .cascade)
    var activities: [SDActivity]

    @Relationship(deleteRule: .cascade)
    var commitments: [SDDailyCommitment]

    // MARK: - Computed Properties

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .synced }
        set { syncStatusRaw = newValue.rawValue }
    }

    var fullName: String {
        [firstName, lastName].compactMap { $0 }.joined(separator: " ")
    }

    var isPendingSync: Bool {
        syncStatus == .pendingUpload || syncStatus == .deleted
    }

    // MARK: - Initialization

    init(
        localId: UUID = UUID(),
        supabaseId: Int? = nil,
        authUserId: UUID? = nil,
        firstName: String? = nil,
        lastName: String? = nil,
        email: String? = nil,
        sex: String? = nil,
        profileMedium: String? = nil,
        profile: String? = nil,
        city: String? = nil,
        state: String? = nil,
        country: String? = nil,
        ftp: Int? = nil,
        weight: Double? = nil,
        premium: Bool = false,
        friendCount: Int? = nil,
        followerCount: Int? = nil,
        mutualFriendCount: Int? = nil,
        datePreference: String? = nil,
        athleteDescription: String? = nil,
        stravaConnected: Bool = false,
        stravaConnectedAt: Date? = nil,
        stravaDisconnectedAt: Date? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        syncStatus: SyncStatus = .pendingUpload
    ) {
        self.localId = localId
        self.supabaseId = supabaseId
        self.authUserId = authUserId
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.sex = sex
        self.profileMedium = profileMedium
        self.profile = profile
        self.city = city
        self.state = state
        self.country = country
        self.ftp = ftp
        self.weight = weight
        self.premium = premium
        self.friendCount = friendCount
        self.followerCount = followerCount
        self.mutualFriendCount = mutualFriendCount
        self.datePreference = datePreference
        self.athleteDescription = athleteDescription
        self.stravaConnected = stravaConnected
        self.stravaConnectedAt = stravaConnectedAt
        self.stravaDisconnectedAt = stravaDisconnectedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt

        // Initialize relationships
        self.activities = []
        self.commitments = []

        // Sync metadata
        self.syncStatusRaw = syncStatus.rawValue
        self.lastModifiedLocally = Date()
        self.lastSyncedAt = nil
        self.serverVersion = 0
        self.localVersion = 1
        self.lastSyncError = nil
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

    func recordSyncError(_ error: String) {
        lastSyncError = error
    }
}

// MARK: - Query Helpers

extension SDAthlete {
    /// Predicate for finding athlete by auth user ID
    static func byAuthUserId(_ userId: UUID) -> Predicate<SDAthlete> {
        #Predicate<SDAthlete> { athlete in
            athlete.authUserId == userId
        }
    }

    /// Predicate for finding athlete by supabase ID
    static func bySupabaseId(_ id: Int) -> Predicate<SDAthlete> {
        #Predicate<SDAthlete> { athlete in
            athlete.supabaseId == id
        }
    }
}
