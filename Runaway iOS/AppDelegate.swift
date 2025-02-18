//
//  AppDelegate.swift
//  RunawayUI
//
//  Created by Jack Rudelic on 7/17/24.
//

import Foundation
import UIKit
import SwiftUI


class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    let strava: StravaClient
    
    override init() {
        let config = StravaConfig(
            clientId: 118220,
            clientSecret: "b742a2a907586824514f1b3950918a6369eb29f4",
            redirectUri: "runbitch://redirect",
            scopes: [.activityReadAll, .activityWrite]
        )
        strava = StravaClient.sharedInstance.initWithConfig(config)
        
        super.init()
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        return true
    }
}
