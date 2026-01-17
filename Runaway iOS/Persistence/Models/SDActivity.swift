//
//  SDActivity.swift
//  Runaway iOS
//
//  SwiftData model for Activity with offline-first sync support
//

import Foundation
import SwiftData

@Model
final class SDActivity {
    // MARK: - Identifiers

    /// Local UUID for offline-created activities
    @Attribute(.unique) var localId: UUID

    /// Supabase server ID (nil for offline-created, pending sync)
    var supabaseId: Int?

    // MARK: - Core Activity Data

    var name: String?
    var activityType: String?
    var activityDescription: String?

    // MARK: - Timing

    var activityDate: Date?
    var startDate: Date?
    var elapsedTime: Double?
    var movingTime: Int?

    // MARK: - Distance & Speed

    var distance: Double?
    var maxSpeed: Double?
    var averageSpeed: Double?

    // MARK: - Elevation

    var elevationGain: Double?
    var elevationLoss: Double?
    var elevationLow: Double?
    var elevationHigh: Double?

    // MARK: - Heart Rate

    var maxHeartRate: Int?
    var averageHeartRate: Int?

    // MARK: - Power (Cycling)

    var maxWatts: Int?
    var averageWatts: Int?
    var weightedAverageWatts: Int?

    // MARK: - Cadence

    var maxCadence: Int?
    var averageCadence: Int?

    // MARK: - Calories

    var calories: Int?

    // MARK: - Weather

    var maxTemperature: Double?
    var averageTemperature: Double?
    var weatherCondition: String?
    var humidity: Double?
    var windSpeed: Double?

    // MARK: - Map & Location

    var mapPolyline: String?
    var mapSummaryPolyline: String?
    var startLatitude: Double?
    var startLongitude: Double?
    var endLatitude: Double?
    var endLongitude: Double?

    // MARK: - Flags

    var commute: Bool
    var flagged: Bool
    var withPet: Bool
    var competition: Bool

    // MARK: - References

    var athleteId: Int?
    var activityTypeId: Int?
    var gearId: Int?
    var filename: String?

    // MARK: - Sync Metadata

    var syncStatusRaw: String
    var lastModifiedLocally: Date
    var lastSyncedAt: Date?
    var serverVersion: Int
    var localVersion: Int
    var lastSyncError: String?

    // MARK: - Relationship

    @Relationship(deleteRule: .nullify, inverse: \SDAthlete.activities)
    var athlete: SDAthlete?

    // MARK: - Computed Properties

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .synced }
        set { syncStatusRaw = newValue.rawValue }
    }

    var isPendingSync: Bool {
        syncStatus == .pendingUpload || syncStatus == .deleted
    }

    var hasConflict: Bool {
        syncStatus == .conflict
    }

    // MARK: - Initialization

    init(
        localId: UUID = UUID(),
        supabaseId: Int? = nil,
        name: String? = nil,
        activityType: String? = nil,
        activityDescription: String? = nil,
        activityDate: Date? = nil,
        startDate: Date? = nil,
        elapsedTime: Double? = nil,
        movingTime: Int? = nil,
        distance: Double? = nil,
        maxSpeed: Double? = nil,
        averageSpeed: Double? = nil,
        elevationGain: Double? = nil,
        elevationLoss: Double? = nil,
        elevationLow: Double? = nil,
        elevationHigh: Double? = nil,
        maxHeartRate: Int? = nil,
        averageHeartRate: Int? = nil,
        maxWatts: Int? = nil,
        averageWatts: Int? = nil,
        weightedAverageWatts: Int? = nil,
        maxCadence: Int? = nil,
        averageCadence: Int? = nil,
        calories: Int? = nil,
        maxTemperature: Double? = nil,
        averageTemperature: Double? = nil,
        weatherCondition: String? = nil,
        humidity: Double? = nil,
        windSpeed: Double? = nil,
        mapPolyline: String? = nil,
        mapSummaryPolyline: String? = nil,
        startLatitude: Double? = nil,
        startLongitude: Double? = nil,
        endLatitude: Double? = nil,
        endLongitude: Double? = nil,
        commute: Bool = false,
        flagged: Bool = false,
        withPet: Bool = false,
        competition: Bool = false,
        athleteId: Int? = nil,
        activityTypeId: Int? = nil,
        gearId: Int? = nil,
        filename: String? = nil,
        syncStatus: SyncStatus = .pendingUpload
    ) {
        self.localId = localId
        self.supabaseId = supabaseId
        self.name = name
        self.activityType = activityType
        self.activityDescription = activityDescription
        self.activityDate = activityDate
        self.startDate = startDate
        self.elapsedTime = elapsedTime
        self.movingTime = movingTime
        self.distance = distance
        self.maxSpeed = maxSpeed
        self.averageSpeed = averageSpeed
        self.elevationGain = elevationGain
        self.elevationLoss = elevationLoss
        self.elevationLow = elevationLow
        self.elevationHigh = elevationHigh
        self.maxHeartRate = maxHeartRate
        self.averageHeartRate = averageHeartRate
        self.maxWatts = maxWatts
        self.averageWatts = averageWatts
        self.weightedAverageWatts = weightedAverageWatts
        self.maxCadence = maxCadence
        self.averageCadence = averageCadence
        self.calories = calories
        self.maxTemperature = maxTemperature
        self.averageTemperature = averageTemperature
        self.weatherCondition = weatherCondition
        self.humidity = humidity
        self.windSpeed = windSpeed
        self.mapPolyline = mapPolyline
        self.mapSummaryPolyline = mapSummaryPolyline
        self.startLatitude = startLatitude
        self.startLongitude = startLongitude
        self.endLatitude = endLatitude
        self.endLongitude = endLongitude
        self.commute = commute
        self.flagged = flagged
        self.withPet = withPet
        self.competition = competition
        self.athleteId = athleteId
        self.activityTypeId = activityTypeId
        self.gearId = gearId
        self.filename = filename

        // Sync metadata
        self.syncStatusRaw = syncStatus.rawValue
        self.lastModifiedLocally = Date()
        self.lastSyncedAt = nil
        self.serverVersion = 0
        self.localVersion = 1
        self.lastSyncError = nil
    }

    // MARK: - Sync Methods

    /// Mark record as modified locally
    func markModified() {
        lastModifiedLocally = Date()
        localVersion += 1
        syncStatus = .pendingUpload
    }

    /// Mark record as synced with server
    func markSynced(serverVersion: Int, supabaseId: Int? = nil) {
        if let id = supabaseId {
            self.supabaseId = id
        }
        self.serverVersion = serverVersion
        self.lastSyncedAt = Date()
        self.syncStatus = .synced
        self.lastSyncError = nil
    }

    /// Mark record for deletion
    func markDeleted() {
        lastModifiedLocally = Date()
        localVersion += 1
        syncStatus = .deleted
    }

    /// Record a sync error
    func recordSyncError(_ error: String) {
        lastSyncError = error
    }
}

// MARK: - Query Helpers

extension SDActivity {
    /// Predicate for finding activities pending sync
    static var pendingSyncPredicate: Predicate<SDActivity> {
        #Predicate<SDActivity> { activity in
            activity.syncStatusRaw == "pendingUpload" || activity.syncStatusRaw == "deleted"
        }
    }

    /// Predicate for finding synced activities
    static var syncedPredicate: Predicate<SDActivity> {
        #Predicate<SDActivity> { activity in
            activity.syncStatusRaw == "synced"
        }
    }

    /// Predicate for finding activities with conflicts
    static var conflictPredicate: Predicate<SDActivity> {
        #Predicate<SDActivity> { activity in
            activity.syncStatusRaw == "conflict"
        }
    }
}
