//
//  TokenDelegate.swift
//  Runaway
//
//  Created by Jack Rudelic on 2/1/24.
//

/**
 Token Delegate protocol - responsible for storing and retrieving the OAuth token
 **/
public protocol TokenDelegate {

    /**
     Retrieves the token

     - Returns: an optional OAuthToken
     **/
    func get() -> OAuthToken?

    /**
     Store the token

     - Parameter token: an optional OAuthToken
     **/
    func set(_ token: OAuthToken?)
}
