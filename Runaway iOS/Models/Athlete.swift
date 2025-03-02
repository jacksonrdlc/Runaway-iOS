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
    public let userId: Int?
//    public let resourceState: ResourceState?
    public let firstname: String?
    public let lastname: String?
    public let profileMedium: URL?
    public let profile: URL?
    public let city: String?
    public let state: String?
    public let country: String?
//    public let sex: Sex?
//    public let friend: FollowingStatus?
//    public let follower: FollowingStatus?
    public let premium:Bool?
    public let createdAt: Date?
    public let updatedAt: Date?
    public let friendCount: Int?
    public let followerCount: Int?
    public let mutualFriendCount: Int?
    public let datePreference: String?
//    public let measurementPreference: Units?
    public let email: String?
    public let FTP: Int?
    public let weight: Double?
//    public let clubs: [Club]?
//    public let bikes: [Bike]?
//    public let shoes: [Shoe]?

    required public init(userId: Int?, firstname: String?, lastname: String?, profileMedium: URL?, profile: URL?, city: String?, state: String?, country: String?, premium: Bool?, createdAt: Date?, updatedAt: Date?, friendCount: Int?, followerCount: Int?, mutualFriendCount: Int?, datePreference: String?, email: String?, FTP: Int?, weight: Double?) {
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
