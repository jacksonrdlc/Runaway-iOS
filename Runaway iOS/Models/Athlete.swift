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
public final class Athlete: Identifiable, Decodable, Equatable {
    public static func == (lhs: Athlete, rhs: Athlete) -> Bool {
        return lhs.id == rhs.id &&
               lhs.userId == rhs.userId &&
               lhs.stravaConnected == rhs.stravaConnected
    }
    public var id: Int?
    public var userId: UUID?
    public var firstname: String?
    public var lastname: String?
    public var profileMedium: URL?
    public var profile: URL?
    public var city: String?
    public var state: String?
    public var country: String?
    public var sex: String?
    public var description: String?
    public var premium: Bool?
    public var createdAt: Date?
    public var updatedAt: Date?
    public var friendCount: Int?
    public var followerCount: Int?
    public var mutualFriendCount: Int?
    public var datePreference: String?
    public var email: String?
    public var FTP: Int?
    public var weight: Double?

    // Strava connection tracking
    public var stravaConnected: Bool?
    public var stravaConnectedAt: Date?
    public var stravaDisconnectedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "auth_user_id"
        case firstname = "first_name"
        case lastname = "last_name"
        case profileMedium = "profile_medium"
        case profile = "profile"
        case city
        case state
        case country
        case sex
        case description
        case premium
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case friendCount = "friend_count"
        case followerCount = "follower_count"
        case mutualFriendCount = "mutual_friend_count"
        case datePreference = "date_preference"
        case email
        case FTP = "ftp"
        case weight
        case stravaConnected = "strava_connected"
        case stravaConnectedAt = "strava_connected_at"
        case stravaDisconnectedAt = "strava_disconnected_at"
    }

    required public init(userId: UUID?, firstname: String?, lastname: String?, profileMedium: URL?, profile: URL?, city: String?, state: String?, country: String?, premium: Bool?, createdAt: Date?, updatedAt: Date?, friendCount: Int?, followerCount: Int?, mutualFriendCount: Int?, datePreference: String?, email: String?, FTP: Int?, weight: Double?, stravaConnected: Bool? = false, stravaConnectedAt: Date? = nil, stravaDisconnectedAt: Date? = nil) {
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
        self.stravaConnected = stravaConnected
        self.stravaConnectedAt = stravaConnectedAt
        self.stravaDisconnectedAt = stravaDisconnectedAt
    }
}

public final class AthleteStats: Decodable {
    public var athleteId: Int?
    public var count: Int?
    public var distance: Double?
    public var movingTime: TimeInterval?
    public var elapsedTime: TimeInterval?
    public var elevationGain: Double?
    public var achievementCount: Int?
    public var ytdDistance: Double?
    
    enum CodingKeys: String, CodingKey {
        case athleteId = "athlete_id"
        case count = "count"
        case distance = "distance"
        case movingTime = "moving_time"
        case elapsedTime = "elapsed_time"
        case elevationGain = "elevation_gain"
        case achievementCount = "achievement_count"
        case ytdDistance = "ytd_distance"
    }
}
