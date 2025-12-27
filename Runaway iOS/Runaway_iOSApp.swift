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
    @StateObject private var stravaService = StravaService()
    @State private var router = AppRouter()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    init() {
        // Configure navigation bar appearance for light mode - FORCE DARK TEXT
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(AppTheme.Colors.LightMode.background)

        // Large title - FORCE DARK TEXT (near black)
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor.black
        ]

        // Inline title - FORCE DARK TEXT
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.black
        ]

        // Button items
        appearance.buttonAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(AppTheme.Colors.LightMode.accent)
        ]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().tintColor = UIColor(AppTheme.Colors.LightMode.accent)

        // Tab bar appearance - light gray unselected, electric blue selected
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(AppTheme.Colors.LightMode.cardBackground)

        // Unselected items - light gray
        let normalColor = UIColor(AppTheme.Colors.LightMode.textTertiary)
        tabBarAppearance.stackedLayoutAppearance.normal.iconColor = normalColor
        tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: normalColor]
        tabBarAppearance.inlineLayoutAppearance.normal.iconColor = normalColor
        tabBarAppearance.inlineLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: normalColor]
        tabBarAppearance.compactInlineLayoutAppearance.normal.iconColor = normalColor
        tabBarAppearance.compactInlineLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: normalColor]

        // Selected items - electric blue
        let selectedColor = UIColor(AppTheme.Colors.LightMode.accent)
        tabBarAppearance.stackedLayoutAppearance.selected.iconColor = selectedColor
        tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selectedColor]
        tabBarAppearance.inlineLayoutAppearance.selected.iconColor = selectedColor
        tabBarAppearance.inlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selectedColor]
        tabBarAppearance.compactInlineLayoutAppearance.selected.iconColor = selectedColor
        tabBarAppearance.compactInlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selectedColor]

        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        UITabBar.appearance().tintColor = selectedColor
        UITabBar.appearance().unselectedItemTintColor = normalColor
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
                .environmentObject(userSession)
                .environmentObject(realtimeService)
                .environmentObject(dataManager)
                .environment(router)
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
                .onOpenURL { url in
                    handleDeepLink(url)
                    // Also pass to router for navigation deep links
                    router.handleDeepLink(url)
                }
        }
    }

    // MARK: - Deep Link Handling

    private func handleDeepLink(_ url: URL) {
        #if DEBUG
        print("🔗 Deep link received: \(url)")
        #endif

        // Handle Strava OAuth callback
        if url.scheme == "runaway" && url.host == "strava-connected" {
            Task {
                await stravaService.handleStravaCallback(url: url)
            }
        }
    }
} 
