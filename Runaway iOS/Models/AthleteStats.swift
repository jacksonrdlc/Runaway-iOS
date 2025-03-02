//
//  AthleteStats.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 3/2/25.
//



import Foundation
/**
 Stats are aggregated data for an athlete
 **/
public final class AthleteStats: Decodable {
    public let biggestRideDistance: Double?
    public let biggestClimbElevationGain: Double?
    public let recentRideTotals: Totals?
    public let recentRunTotals: Totals?
    public let recentSwimTotals: Totals?
    public let ytdRideTotals: Totals?
    public let ytdRunTotals: Totals?
    public let ytdSwimTotals: Totals?
    public let allRideTotals: Totals?
    public let allRunTotals: Totals?
    public let allSwimTotals: Totals?

    required public init(biggestRideDistance: Double?, biggestClimbElevationGain: Double?, recentRideTotals: Totals?, recentRunTotals: Totals?, recentSwimTotals: Totals?, ytdRideTotals: Totals?, ytdRunTotals: Totals?, ytdSwimTotals: Totals?, allRideTotals: Totals?, allRunTotals: Totals?, allSwimTotals: Totals?) {
        self.biggestRideDistance = biggestRideDistance
        self.biggestClimbElevationGain = biggestClimbElevationGain
        self.recentRideTotals = recentRideTotals
        self.recentRunTotals = recentRunTotals
        self.recentSwimTotals = recentSwimTotals
        self.ytdRideTotals = ytdRideTotals
        self.ytdRunTotals = ytdRunTotals
        self.ytdSwimTotals = ytdSwimTotals
        self.allRideTotals = allRideTotals
        self.allRunTotals = allRunTotals
        self.allSwimTotals = allSwimTotals
    }
}

public final class Totals: Decodable {

    public let count: Int?
    public let distance: Double?
    public let movingTime: TimeInterval?
    public let elapsedTime: TimeInterval?
    public let elevationGain: Double?
    public let achievementCount: Int?

    required public init(count: Int? = nil, distance: Double? = nil, movingTime: TimeInterval? = nil, elapsedTime: TimeInterval? = nil, elevationGain: Double? = nil, achievementCount: Int? = nil) {
        self.count = count
        self.distance = distance
        self.movingTime = movingTime
        self.elapsedTime = elapsedTime
        self.elevationGain = elevationGain
        self.achievementCount = achievementCount
    }
}
