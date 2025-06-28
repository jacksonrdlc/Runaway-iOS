//
//  Athlete.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 3/2/25.
//


import Foundation
/**
  Athletes are Strava users, Strava users are athletes. The object is returned in detailed, summary or meta representations.
 **/
public final class Athlete: Identifiable, Decodable {
//    public var id: Int
    public var userId: UUID?
//    public let resourceState: ResourceState?
    public var firstname: String?
    public var lastname: String?
    public var profileMedium: URL?
    public var profile: URL?
    public var city: String?
    public var state: String?
    public var country: String?
//    public let sex: Sex?
//    public let friend: FollowingStatus?
//    public let follower: FollowingStatus?
    public var premium: Bool?
    public var createdAt: Date?
    public var updatedAt: Date?
    public var friendCount: Int?
    public var followerCount: Int?
    public var mutualFriendCount: Int?
    public var datePreference: String?
//    public let measurementPreference: Units?
    public var email: String?
    public var FTP: Int?
    public var weight: Double?
//    public let clubs: [Club]?
//    public let bikes: [Bike]?
//    public let shoes: [Shoe]?

    required public init(userId: UUID?, firstname: String?, lastname: String?, profileMedium: URL?, profile: URL?, city: String?, state: String?, country: String?, premium: Bool?, createdAt: Date?, updatedAt: Date?, friendCount: Int?, followerCount: Int?, mutualFriendCount: Int?, datePreference: String?, email: String?, FTP: Int?, weight: Double?) {
//        self.id = id
        self.userId = userId
        self.firstname = firstname
        self.lastname = lastname
        self.profileMedium = profileMedium
        self.profile = profile
        self.city = city
        self.state = state
        self.country = country
        self.premium = premium
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.friendCount = friendCount
        self.followerCount = followerCount
        self.mutualFriendCount = mutualFriendCount
        self.datePreference = datePreference
        self.email = email
        self.FTP = FTP
        self.weight = weight
    }
}

public final class AthleteStats: Decodable {
    public var userId: Int?
    public var count: Int?
    public var distance: Double?
    public var movingTime: TimeInterval?
    public var elapsedTime: TimeInterval?
    public var elevationGain: Double?
    public var achievementCount: Int?
    public var ytdDistance: Double?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case count = "count"
        case distance = "distance"
        case movingTime = "moving_time"
        case elapsedTime = "elapsed_time"
        case elevationGain = "elevation_gain"
        case achievementCount = "achievement_count"
        case ytdDistance = "ytd_distance"
    }
}
