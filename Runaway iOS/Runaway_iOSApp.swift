//
//  Runaway_iOSApp.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 2/18/25.
//

import SwiftUI
import Foundation
import FirebaseCore
import AppIntents
import HealthKit

@main
struct Runaway_iOSApp: App {
    @StateObject private var userSession = UserSession.shared
    @StateObject private var realtimeService = RealtimeService.shared
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var stravaService = StravaService()
    @StateObject private var activityRecordingService = ActivityRecordingService()
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

                    // Request HealthKit authorization if available
                    if HealthKitManager.shared.isHealthKitAvailable {
                        Task {
                            let authorized = await HealthKitManager.shared.requestAuthorization()
                            if authorized {
                                print("✅ HealthKit authorization complete")
                            } else {
                                print("⚠️ HealthKit authorization not granted")
                            }
                        }
                    }

                    // Track analytics session
                    AnalyticsService.shared.startSession()
                    AnalyticsService.shared.track(.appOpened, category: .engagement)
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    print("📱 App entered background - using silent push notifications for background sync")
                    // Background tasks disabled - using silent push notifications instead
                    // realtimeService.scheduleBackgroundRefresh()

                    // Track analytics
                    AnalyticsService.shared.track(.appBackgrounded, category: .engagement)
                    AnalyticsService.shared.endSession()
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                    // Also pass to router for navigation deep links
                    router.handleDeepLink(url)
                }
                // MARK: - Siri Intent Handlers
                .onReceive(NotificationCenter.default.publisher(for: .startRecordingFromSiri)) { notification in
                    handleStartRecordingFromSiri(notification)
                }
                .onReceive(NotificationCenter.default.publisher(for: .stopRecordingFromSiri)) { _ in
                    handleStopRecordingFromSiri()
                }
                .onReceive(NotificationCenter.default.publisher(for: .pauseRecordingFromSiri)) { _ in
                    activityRecordingService.pauseRecording()
                }
                .onReceive(NotificationCenter.default.publisher(for: .resumeRecordingFromSiri)) { _ in
                    activityRecordingService.resumeRecording()
                }
        }
    }

    // MARK: - Siri Recording Handlers

    private func handleStartRecordingFromSiri(_ notification: Notification) {
        let activityType = notification.userInfo?["activityType"] as? String ?? "Run"

        // Navigate to recording tab via notification
        NotificationCenter.default.post(name: .navigateToRecordTab, object: nil)

        // Start recording after a brief delay to let the view appear
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            await MainActor.run {
                activityRecordingService.startRecording(activityType: activityType)
            }
        }
    }

    private func handleStopRecordingFromSiri() {
        activityRecordingService.stopRecording()
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
