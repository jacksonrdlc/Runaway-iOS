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
    @StateObject private var userSession = UserSession.shared
    @StateObject private var realtimeService = RealtimeService.shared
    @StateObject private var dataManager = DataManager.shared
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(userSession)
                .environmentObject(realtimeService)
                .environmentObject(dataManager)
                .onAppear {
                    // Start location services when app appears
                    LocationManager.shared.requestLocationPermission()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    print("📱 App became active - starting realtime services")
                    realtimeService.startRealtimeSubscription()
                    LocationManager.shared.requestLocationPermission()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    print("📱 App entered background - using silent push notifications for background sync")
                    // Background tasks disabled - using silent push notifications instead
                    // realtimeService.scheduleBackgroundRefresh()
                }
        }
    }
} 
