//
//  SbActivity.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 2/21/25.
//
import Foundation

public class Activity: Identifiable, Decodable {
    
    public typealias Speed = Double
    public typealias Count = Int
    
    public let id: Int
//    public let resourceState: ResourceState?
    public let externalId: String?
    public let uploadId: Int?
//    public let athlete: Athlete?
    public let name: String?
    public let detail: String?
    public let distance: Double?
    public let movingTime: TimeInterval?
    public let elapsedTime: TimeInterval?
    public let highElevation : Double?
    public let lowElevation : Double?
    public let totalElevationGain: Double?
    public let type: String?
    public let start_date: Date?
    public let startDateLocal: Date?
    public let timeZone: String?
//    public let startLatLng: Location?
//    public let endLatLng: Location?
    public let achievementCount: Count?
    public let kudosCount: Count?
    public let commentCount: Count?
    public let athleteCount: Count?
    public let photoCount: Count?
    public let totalPhotoCount: Count?
//    public let photos: [Photo]?
//    public let map: StravaMap?
    public let trainer: Bool?
    public let commute: Bool?
    public let manual: Bool?
    public let `private`: Bool?
    public let flagged: Bool?
//    public let workoutType: WorkoutType?
//    public let gear: Gear?
    public let averageSpeed: Speed?
    public let maxSpeed: Speed?
    public let calories: Double?
    public let hasKudoed: Bool?
//    public let segmentEfforts: [Effort]?
//    public let splitsMetric: [Split]?
//    public let splitsStandard: [Split]?
//    public let bestEfforts: [Split]?
    public let kiloJoules: Double?
    public let averagePower : Double?
    public let maxPower : Double?
    public let deviceWatts : Bool?
    public let hasHeartRate : Bool?
    public let averageHeartRate : Double?
    public let maxHeartRate : Double?
    
    public init(id: Int, externalId: String?, uploadId: Int?, name: String, detail: String, distance: Double, movingTime: TimeInterval, elapsedTime: TimeInterval, highElevation: Double, lowElevation: Double, totalElevationGain: Double, type: String, start_date: Date, startDateLocal: Date, timeZone: String, achievementCount: Int, kudosCount: Int, commentCount: Int, athleteCount: Int, photoCount: Int, totalPhotoCount: Int, trainer: Bool, commute: Bool, manual: Bool, `private`: Bool, flagged: Bool, averageSpeed: Speed, maxSpeed: Speed, calories: Double, hasKudoed: Bool?, kiloJoules: Double, averagePower: Double, maxPower: Double, deviceWatts: Bool, hasHeartRate: Bool, averageHeartRate: Double, maxHeartRate: Double) {
        self.id = id
        self.externalId = externalId
        self.uploadId = uploadId
        self.name = name
        self.detail = detail
        self.distance = distance
        self.movingTime = movingTime
        self.elapsedTime = elapsedTime
        self.highElevation = highElevation
        self.lowElevation = lowElevation
        self.totalElevationGain = totalElevationGain
        self.type = type
        self.start_date = start_date
        self.startDateLocal = startDateLocal
        self.timeZone = timeZone
        self.achievementCount = achievementCount
        self.kudosCount = kudosCount
        self.commentCount = commentCount
        self.athleteCount = athleteCount
        self.photoCount = photoCount
        self.totalPhotoCount = totalPhotoCount
        self.trainer = trainer
        self.commute = commute
        self.manual = manual
        self.private = `private`
        self.flagged = flagged
        self.averageSpeed = averageSpeed
        self.maxSpeed = maxSpeed
        self.calories = calories
        self.hasKudoed = hasKudoed
        self.kiloJoules = kiloJoules
        self.averagePower = averagePower
        self.maxPower = maxPower
        self.deviceWatts = deviceWatts
        self.hasHeartRate = hasHeartRate
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
    }
}

