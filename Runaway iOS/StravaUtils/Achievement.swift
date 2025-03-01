//
//  Achievement.swift
//  Runaway
//
//  Created by Jack Rudelic on 2/1/24.
//

import Foundation
import SwiftyJSON

/**
   Achievement struct - details the type of achievement and the rank
 **/
public struct Achievement: Strava {
    /** Achievement type enum **/
    public let type: AchievementType?

    /** Rank for the achievement **/
    public let rank: Int?

    /**
     Initializer

     - Parameter json: SwiftyJSON object
     - Internal
     **/
    public init(_ json: JSON) {
        type = json["type"].strava(AchievementType.self)
        rank = json["rank"].int
    }
}
