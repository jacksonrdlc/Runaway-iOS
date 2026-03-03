//
//  Runaway_iOSApp.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 2/18/25.
//

import SwiftUI
import SwiftData
import Foundation
import FirebaseCore
import AppIntents
import HealthKit

@main
struct Runaway_iOSApp: App {
    @State private var userSession = UserSession.shared
    @State private var realtimeService = RealtimeService.shared
    @State private var dataManager = DataManager.shared
    @StateObject private var stravaService = StravaService()
    @StateObject private var activityRecordingService = ActivityRecordingService()
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var syncEngine = SyncEngine.shared
    @State private var router = AppRouter()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    init() {
        // Initial appearance setup - will be updated dynamically based on theme
        Self.configureAppearance(isDark: ThemeManager.shared.isDarkMode)
    }

    /// Configure UIKit appearance for navigation and tab bars
    static func configureAppearance(isDark: Bool) {
        // Navigation bar appearance
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()

        if isDark {
            navAppearance.backgroundColor = UIColor(AppTheme.Colors.DarkMode.background)
            navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
            navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        } else {
            navAppearance.backgroundColor = UIColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.background : AppTheme.Colors.LightMode.background)
            navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.black]
            navAppearance.titleTextAttributes = [.foregroundColor: UIColor.black]
        }

        navAppearance.buttonAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(AppTheme.Colors.accent)
        ]

        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = UIColor(AppTheme.Colors.accent)

        // Tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()

        let normalColor: UIColor
        let selectedColor = UIColor(AppTheme.Colors.accent)

        if isDark {
            tabBarAppearance.backgroundColor = UIColor(AppTheme.Colors.DarkMode.background)
            normalColor = UIColor(AppTheme.Colors.DarkMode.textTertiary)
        } else {
            tabBarAppearance.backgroundColor = UIColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.cardBackground : AppTheme.Colors.LightMode.cardBackground)
            normalColor = UIColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textTertiary : AppTheme.Colors.LightMode.textTertiary)
        }

        // Normal state
        tabBarAppearance.stackedLayoutAppearance.normal.iconColor = normalColor
        tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: normalColor]
        tabBarAppearance.inlineLayoutAppearance.normal.iconColor = normalColor
        tabBarAppearance.inlineLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: normalColor]
        tabBarAppearance.compactInlineLayoutAppearance.normal.iconColor = normalColor
        tabBarAppearance.compactInlineLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: normalColor]

        // Selected state
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
                .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
                .environment(userSession)
                .environment(realtimeService)
                .environment(dataManager)
                .environmentObject(themeManager)
                .environmentObject(syncEngine)
                .environment(router)
                .modelContainer(PersistenceController.shared.container)
                .onChange(of: themeManager.currentTheme) { _, newTheme in
                    // Update UIKit appearances when theme changes
                    Self.configureAppearance(isDark: newTheme == .dark)
                }
                .onAppear {
                    // Start location services when app appears
                    LocationManager.shared.requestLocationPermission()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    handleAppBecameActive()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    handleAppEnteredBackground()
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

        // Handle Supabase auth callback (email verification, password reset, etc.)
        if url.scheme == "runaway" && url.host == "auth" {
            Task {
                #if DEBUG
                print("🔐 Handling Supabase auth callback...")
                print("🔗 Callback URL: \(url)")
                #endif
                do {
                    let session = try await supabase.auth.session(from: url)
                    #if DEBUG
                    print("✅ Supabase auth callback handled successfully")
                    print("👤 User: \(session.user.email ?? "unknown")")
                    #endif

                    // Explicitly notify that authentication succeeded
                    await MainActor.run {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("EmailVerificationCompleted"),
                            object: nil
                        )
                    }
                } catch {
                    #if DEBUG
                    print("❌ Supabase auth callback error: \(error)")
                    #endif

                    // Notify about the error so UI can show it
                    await MainActor.run {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("EmailVerificationFailed"),
                            object: nil,
                            userInfo: ["error": error.localizedDescription]
                        )
                    }
                }
            }
            return
        }

        // Handle Strava OAuth callback
        if url.scheme == "runaway" && url.host == "strava-connected" {
            Task {
                await stravaService.handleStravaCallback(url: url)
            }
        }

        // Handle Garmin OAuth callback
        if url.scheme == "runaway" && url.host == "garmin-connected" {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let success = components?.queryItems?.first(where: { $0.name == "success" })?.value == "true"

            #if DEBUG
            print("✅ Garmin OAuth callback - success: \(success)")
            #endif

            // Update GarminService state
            Task {
                await MainActor.run {
                    GarminService.shared.handleOAuthCallback(success: success)
                }
            }
        }
    }

    // MARK: - App Lifecycle Handlers

    private func handleAppBecameActive() {
        print("📱 App became active - resuming services")

        // Refresh commitment in case user set it via widget while app was backgrounded
        Task {
            await CommitmentManager.shared.refresh()
        }

        // Resume realtime services
        realtimeService.startRealtimeSubscription()
        realtimeService.resumeFromBackground()

        // Start SwiftData sync engine
        syncEngine.startBackgroundSync()
        Task {
            await syncEngine.syncPendingChanges()
        }

        // Resume location updates
        LocationManager.shared.requestLocationPermission()

        // Resume analytics timer
        AnalyticsService.shared.resumeFromBackground()

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

        // Detect and log rest days (days without activities)
        Task {
            if let athleteId = UserSession.shared.userId {
                await RestDayService.shared.runDetectionIfNeeded(athleteId: athleteId)
            }
        }

        // Track analytics session
        AnalyticsService.shared.startSession()
        AnalyticsService.shared.track(.appOpened, category: .engagement)
    }

    private func handleAppEnteredBackground() {
        print("📱 App entered background - pausing battery-intensive services")

        // Stop location updates if not actively tracking a workout
        // GPSTrackingService.isTracking indicates an active recording session
        if !activityRecordingService.gpsService.isTracking {
            LocationManager.shared.stopLocationUpdates()
        }

        // Pause realtime connection monitoring to save battery
        realtimeService.pauseForBackground()

        // Stop SwiftData sync engine
        syncEngine.stopBackgroundSync()

        // Pause analytics timer
        AnalyticsService.shared.pauseForBackground()

        // Track analytics before pausing
        AnalyticsService.shared.track(.appBackgrounded, category: .engagement)
        AnalyticsService.shared.endSession()
    }
}
