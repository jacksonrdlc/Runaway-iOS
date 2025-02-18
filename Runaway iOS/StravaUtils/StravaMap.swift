//
//  Map.swift
//  Runaway
//
//  Created by Jack Rudelic on 2/1/24.
//

import Foundation
import SwiftyJSON

/**
  Represents a map of a ride or route
 **/
public final class StravaMap: Strava {
    public let id: String?
    public let resourceState: ResourceState?
    public let polyline: String?
    public let summaryPolyline: String?

    /**
     Initializer

     - Parameter json: SwiftyJSON object
     - Internal
     **/
    required public init(_ json: JSON) {
        id = json["id"].string
        resourceState = json["resource_state"].strava(ResourceState.self)
        polyline = json["polyline"].string
        summaryPolyline = json["summary_polyline"].string
    }
}
