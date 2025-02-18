//
//  StravaProtocols.swift
//  Runaway
//
//  Created by Jack Rudelic on 2/1/24.
//

import Foundation
import SwiftyJSON

/**
  Base protocol for Strava resources

  - Internal
 **/
public protocol Strava: CustomStringConvertible {
    init(_ json: JSON)
}

extension Strava {
    public var description: String {
        let mirror = Mirror(reflecting: self)
        var desc = ""
        for child in mirror.children {
            desc += "\(child.label!): \(child.value) \n"
        }
        return desc
    }
}
