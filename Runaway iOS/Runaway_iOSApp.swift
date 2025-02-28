//
//  Runaway_iOSApp.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 2/18/25.
//

import SwiftUI

@main
struct Runaway_iOSApp: App {
    let strava: StravaClient
    
    init() {
        let config = StravaConfig(
            clientId: 118220,
            clientSecret: "b742a2a907586824514f1b3950918a6369eb29f4",
            redirectUri: "runaway://strava-node-api-203308554831.us-central1.run.app/callback",
            scopes: [.activityReadAll, .activityWrite]
        )
        strava = StravaClient.sharedInstance.initWithConfig(config)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView().onOpenURL { url in
                return strava.handleAuthorizationRedirect(url)
            }
        }
    }
}
