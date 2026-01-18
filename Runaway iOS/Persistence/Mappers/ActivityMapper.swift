//
//  ActivityMapper.swift
//  Runaway iOS
//
//  Converts between Codable Activity models and SwiftData SDActivity models
//

import Foundation

/// Maps between Codable Activity and SwiftData SDActivity
enum ActivityMapper {

    // MARK: - Codable to SwiftData

    /// Convert a Codable Activity to a new SDActivity
    static func toSwiftData(_ activity: Activity) -> SDActivity {
        SDActivity(
            supabaseId: activity.id,
            name: activity.name,
            activityType: activity.type,
            activityDescription: activity.description,
            activityDate: activity.activity_date.map { Date(timeIntervalSince1970: $0) },
            startDate: activity.start_date.map { Date(timeIntervalSince1970: $0) },
            elapsedTime: activity.elapsed_time,
            movingTime: activity.moving_time,
            distance: activity.distance,
            maxSpeed: activity.max_speed,
            averageSpeed: activity.average_speed,
            elevationGain: activity.elevation_gain,
            elevationLoss: activity.elevation_loss,
            elevationLow: activity.elevation_low,
            elevationHigh: activity.elevation_high,
            maxHeartRate: activity.max_heart_rate,
            averageHeartRate: activity.average_heart_rate,
            maxWatts: activity.max_watts,
            averageWatts: activity.average_watts,
            weightedAverageWatts: activity.weighted_average_watts,
            maxCadence: activity.max_cadence,
            averageCadence: activity.average_cadence,
            calories: activity.calories,
            maxTemperature: activity.max_temperature,
            averageTemperature: activity.average_temperature,
            weatherCondition: activity.weather_condition,
            humidity: activity.humidity,
            windSpeed: activity.wind_speed,
            mapPolyline: activity.map_polyline,
            mapSummaryPolyline: activity.map_summary_polyline ?? activity.summary_polyline,
            startLatitude: activity.start_latitude,
            startLongitude: activity.start_longitude,
            endLatitude: activity.end_latitude,
            endLongitude: activity.end_longitude,
            commute: activity.commute ?? false,
            flagged: activity.flagged ?? false,
            withPet: activity.with_pet ?? false,
            competition: activity.competition ?? false,
            athleteId: activity.athlete_id,
            activityTypeId: activity.activity_type_id,
            gearId: activity.gear_id,
            filename: activity.filename,
            syncStatus: .synced // Coming from server, so already synced
        )
    }

    /// Update an existing SDActivity with data from Codable Activity
    static func update(_ sdActivity: SDActivity, from activity: Activity) {
        sdActivity.supabaseId = activity.id
        sdActivity.name = activity.name
        sdActivity.activityType = activity.type
        sdActivity.activityDescription = activity.description
        sdActivity.activityDate = activity.activity_date.map { Date(timeIntervalSince1970: $0) }
        sdActivity.startDate = activity.start_date.map { Date(timeIntervalSince1970: $0) }
        sdActivity.elapsedTime = activity.elapsed_time
        sdActivity.movingTime = activity.moving_time
        sdActivity.distance = activity.distance
        sdActivity.maxSpeed = activity.max_speed
        sdActivity.averageSpeed = activity.average_speed
        sdActivity.elevationGain = activity.elevation_gain
        sdActivity.elevationLoss = activity.elevation_loss
        sdActivity.elevationLow = activity.elevation_low
        sdActivity.elevationHigh = activity.elevation_high
        sdActivity.maxHeartRate = activity.max_heart_rate
        sdActivity.averageHeartRate = activity.average_heart_rate
        sdActivity.maxWatts = activity.max_watts
        sdActivity.averageWatts = activity.average_watts
        sdActivity.weightedAverageWatts = activity.weighted_average_watts
        sdActivity.maxCadence = activity.max_cadence
        sdActivity.averageCadence = activity.average_cadence
        sdActivity.calories = activity.calories
        sdActivity.maxTemperature = activity.max_temperature
        sdActivity.averageTemperature = activity.average_temperature
        sdActivity.weatherCondition = activity.weather_condition
        sdActivity.humidity = activity.humidity
        sdActivity.windSpeed = activity.wind_speed
        sdActivity.mapPolyline = activity.map_polyline
        sdActivity.mapSummaryPolyline = activity.map_summary_polyline ?? activity.summary_polyline
        sdActivity.startLatitude = activity.start_latitude
        sdActivity.startLongitude = activity.start_longitude
        sdActivity.endLatitude = activity.end_latitude
        sdActivity.endLongitude = activity.end_longitude
        sdActivity.commute = activity.commute ?? false
        sdActivity.flagged = activity.flagged ?? false
        sdActivity.withPet = activity.with_pet ?? false
        sdActivity.competition = activity.competition ?? false
        sdActivity.athleteId = activity.athlete_id
        sdActivity.activityTypeId = activity.activity_type_id
        sdActivity.gearId = activity.gear_id
        sdActivity.filename = activity.filename
    }

    // MARK: - SwiftData to Codable

    /// Convert SDActivity to Codable Activity
    static func toCodable(_ sdActivity: SDActivity) -> Activity {
        Activity(
            id: sdActivity.supabaseId ?? 0,
            name: sdActivity.name,
            type: sdActivity.activityType,
            summary_polyline: sdActivity.mapSummaryPolyline,
            distance: sdActivity.distance,
            start_date: sdActivity.startDate?.timeIntervalSince1970,
            elapsed_time: sdActivity.elapsedTime,
            athlete_id: sdActivity.athleteId,
            activity_type_id: sdActivity.activityTypeId,
            description: sdActivity.activityDescription,
            activity_date: sdActivity.activityDate?.timeIntervalSince1970,
            moving_time: sdActivity.movingTime,
            elevation_gain: sdActivity.elevationGain,
            elevation_loss: sdActivity.elevationLoss,
            elevation_low: sdActivity.elevationLow,
            elevation_high: sdActivity.elevationHigh,
            max_speed: sdActivity.maxSpeed,
            average_speed: sdActivity.averageSpeed,
            max_heart_rate: sdActivity.maxHeartRate,
            average_heart_rate: sdActivity.averageHeartRate,
            max_watts: sdActivity.maxWatts,
            average_watts: sdActivity.averageWatts,
            weighted_average_watts: sdActivity.weightedAverageWatts,
            max_cadence: sdActivity.maxCadence,
            average_cadence: sdActivity.averageCadence,
            calories: sdActivity.calories,
            max_temperature: sdActivity.maxTemperature,
            average_temperature: sdActivity.averageTemperature,
            weather_condition: sdActivity.weatherCondition,
            humidity: sdActivity.humidity,
            wind_speed: sdActivity.windSpeed,
            map_polyline: sdActivity.mapPolyline,
            map_summary_polyline: sdActivity.mapSummaryPolyline,
            start_latitude: sdActivity.startLatitude,
            start_longitude: sdActivity.startLongitude,
            end_latitude: sdActivity.endLatitude,
            end_longitude: sdActivity.endLongitude,
            commute: sdActivity.commute,
            flagged: sdActivity.flagged,
            with_pet: sdActivity.withPet,
            competition: sdActivity.competition,
            filename: sdActivity.filename,
            gear_id: sdActivity.gearId
        )
    }

    /// Convert SDActivity to LocalActivity (lightweight version for lists)
    static func toLocalActivity(_ sdActivity: SDActivity) -> LocalActivity {
        LocalActivity(
            id: sdActivity.supabaseId ?? Int(sdActivity.localId.hashValue),
            name: sdActivity.name,
            type: sdActivity.activityType,
            summary_polyline: sdActivity.mapSummaryPolyline,
            distance: sdActivity.distance,
            start_date: sdActivity.startDate,
            elapsed_time: sdActivity.elapsedTime
        )
    }

    // MARK: - Batch Operations

    /// Convert multiple Codable Activities to SwiftData
    static func toSwiftData(_ activities: [Activity]) -> [SDActivity] {
        activities.map { toSwiftData($0) }
    }

    /// Convert multiple SDActivities to Codable
    static func toCodable(_ sdActivities: [SDActivity]) -> [Activity] {
        sdActivities.map { toCodable($0) }
    }

    /// Convert multiple SDActivities to LocalActivity
    static func toLocalActivities(_ sdActivities: [SDActivity]) -> [LocalActivity] {
        sdActivities.map { toLocalActivity($0) }
    }
}

// MARK: - Athlete Mapper

/// Maps between Codable Athlete and SwiftData SDAthlete
enum AthleteMapper {

    /// Convert a Codable Athlete to a new SDAthlete
    static func toSwiftData(_ athlete: Athlete) -> SDAthlete {
        SDAthlete(
            supabaseId: athlete.id,
            authUserId: athlete.userId,
            firstName: athlete.firstname,
            lastName: athlete.lastname,
            email: athlete.email,
            sex: athlete.sex,
            profileMedium: athlete.profileMedium?.absoluteString,
            profile: athlete.profile?.absoluteString,
            city: athlete.city,
            state: athlete.state,
            country: athlete.country,
            ftp: athlete.FTP,
            weight: athlete.weight,
            premium: athlete.premium ?? false,
            friendCount: athlete.friendCount,
            followerCount: athlete.followerCount,
            mutualFriendCount: athlete.mutualFriendCount,
            datePreference: athlete.datePreference,
            athleteDescription: athlete.description,
            stravaConnected: athlete.stravaConnected ?? false,
            stravaConnectedAt: athlete.stravaConnectedAt,
            stravaDisconnectedAt: athlete.stravaDisconnectedAt,
            createdAt: athlete.createdAt,
            updatedAt: athlete.updatedAt,
            syncStatus: .synced
        )
    }

    /// Update an existing SDAthlete with data from Codable Athlete
    static func update(_ sdAthlete: SDAthlete, from athlete: Athlete) {
        sdAthlete.supabaseId = athlete.id
        sdAthlete.authUserId = athlete.userId
        sdAthlete.firstName = athlete.firstname
        sdAthlete.lastName = athlete.lastname
        sdAthlete.email = athlete.email
        sdAthlete.sex = athlete.sex
        sdAthlete.profileMedium = athlete.profileMedium?.absoluteString
        sdAthlete.profile = athlete.profile?.absoluteString
        sdAthlete.city = athlete.city
        sdAthlete.state = athlete.state
        sdAthlete.country = athlete.country
        sdAthlete.ftp = athlete.FTP
        sdAthlete.weight = athlete.weight
        sdAthlete.premium = athlete.premium ?? false
        sdAthlete.friendCount = athlete.friendCount
        sdAthlete.followerCount = athlete.followerCount
        sdAthlete.mutualFriendCount = athlete.mutualFriendCount
        sdAthlete.datePreference = athlete.datePreference
        sdAthlete.athleteDescription = athlete.description
        sdAthlete.stravaConnected = athlete.stravaConnected ?? false
        sdAthlete.stravaConnectedAt = athlete.stravaConnectedAt
        sdAthlete.stravaDisconnectedAt = athlete.stravaDisconnectedAt
        sdAthlete.createdAt = athlete.createdAt
        sdAthlete.updatedAt = athlete.updatedAt
    }
}

// MARK: - Commitment Mapper

/// Maps between Codable DailyCommitment and SwiftData SDDailyCommitment
enum CommitmentMapper {

    /// Convert a Codable DailyCommitment to a new SDDailyCommitment
    static func toSwiftData(_ commitment: DailyCommitment) -> SDDailyCommitment {
        let commitmentDate = DateFormatter.dateOnly.date(from: commitment.commitmentDate) ?? Date()

        return SDDailyCommitment(
            supabaseId: commitment.id,
            commitmentDate: commitmentDate,
            activityType: commitment.activityType,
            isFulfilled: commitment.isFulfilled,
            fulfilledAt: commitment.fulfilledAtAsDate,
            commitmentLevel: commitment.commitmentLevel,
            microCommitmentType: commitment.microCommitmentType,
            progressionStep: commitment.progressionStep,
            athleteId: commitment.athleteId,
            syncStatus: .synced
        )
    }

    /// Convert SDDailyCommitment to Codable DailyCommitment
    static func toCodable(_ sdCommitment: SDDailyCommitment) -> DailyCommitment {
        let formatter = ISO8601DateFormatter()

        return DailyCommitment(
            id: sdCommitment.supabaseId,
            athleteId: sdCommitment.athleteId,
            commitmentDate: sdCommitment.commitmentDateString,
            activityType: sdCommitment.activityType,
            isFulfilled: sdCommitment.isFulfilled,
            fulfilledAt: sdCommitment.fulfilledAt.map { formatter.string(from: $0) },
            createdAt: sdCommitment.createdAt.map { formatter.string(from: $0) },
            updatedAt: sdCommitment.updatedAt.map { formatter.string(from: $0) },
            commitmentLevel: sdCommitment.commitmentLevel,
            microCommitmentType: sdCommitment.microCommitmentType,
            progressionStep: sdCommitment.progressionStep
        )
    }

    /// Update an existing SDDailyCommitment with data from Codable DailyCommitment
    static func update(_ sdCommitment: SDDailyCommitment, from commitment: DailyCommitment) {
        sdCommitment.supabaseId = commitment.id
        sdCommitment.commitmentDate = DateFormatter.dateOnly.date(from: commitment.commitmentDate) ?? Date()
        sdCommitment.activityType = commitment.activityType
        sdCommitment.isFulfilled = commitment.isFulfilled
        sdCommitment.fulfilledAt = commitment.fulfilledAtAsDate
        sdCommitment.commitmentLevel = commitment.commitmentLevel
        sdCommitment.microCommitmentType = commitment.microCommitmentType
        sdCommitment.progressionStep = commitment.progressionStep
        sdCommitment.athleteId = commitment.athleteId
    }
}
