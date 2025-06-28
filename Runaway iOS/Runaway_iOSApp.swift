//
//  Runaway_iOSApp.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 2/18/25.
//

import SwiftUI
import Foundation
import FirebaseCore

@main
struct Runaway_iOSApp: App {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var realtimeService = RealtimeService.shared
    @StateObject private var userManager = UserManager.shared
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(realtimeService)
                .environmentObject(userManager)
                .onAppear {
                    // Start location services when app appears
                    LocationManager.shared.requestLocationPermission()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    realtimeService.startRealtimeSubscription()
                    LocationManager.shared.requestLocationPermission()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    // Keep subscription running in background
                }
        }
    }
} 
