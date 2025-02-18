//
//  StravaClientError.swift
//  Runaway
//
//  Created by Jack Rudelic on 2/1/24.
//

import Foundation

/**
 StravaClientError Enum
*/
public enum StravaClientError: Error {

    /**
     The OAuthCredentials are invalid
    **/
    case invalidCredentials

    /**
     Uknown error
    **/
    case unknown
}
