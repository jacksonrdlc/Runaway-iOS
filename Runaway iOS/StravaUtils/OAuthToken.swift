//
//  OAuthToken.swift
//  Runaway
//
//  Created by Jack Rudelic on 2/1/24.
//

import Foundation
import SwiftyJSON

/**
OAuthToken which is required for requesting Strava resources
 **/
public struct OAuthToken: Strava {

    /** The access token **/
    public let accessToken: String?

    /** The refresh token **/
    public let refreshToken: String?

    /** Expiry for the token in seconds since the epoch **/
    public let expiresAt : Int?

    /** The athlete **/
    public let athlete: Athlete?

    /**
     Initializers

     - Parameter json: A SwiftyJSON object
     **/
    public init(_ json: JSON) {
        accessToken = json["access_token"].string
        refreshToken = json["refresh_token"].string
        expiresAt = json["expires_at"].int
        athlete = Athlete(json["athlete"])
    }

    public init(access: String?, refresh: String?, expiry: Int?) {
        self.accessToken = access
        self.refreshToken = refresh
        self.expiresAt = expiry
        self.athlete = nil
    }

}
