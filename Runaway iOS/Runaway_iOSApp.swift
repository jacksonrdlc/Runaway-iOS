//
//  Runaway_iOSApp.swift
//  Runaway iOS
//

import SwiftUI
import SwiftData
import Foundation
import AppIntents
import HealthKit

@main
struct Runaway_iOSApp: App {
    @State private var userSession = UserSession.shared
    @State private var realtimeService = RealtimeService.shared
    @State private var dataManager = DataManager.shared
    @StateObject private var stravaService = StravaService()
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var syncEngine = SyncEngine.shared
    @State private var router = AppRouter()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    init() {
        Self.configureAppearance(isDark: ThemeManager.shared.isDarkMode)
    }

    static func configureAppearance(isDark: Bool) {
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()

        // Always use dark nav bar (Copilot-style: dark regardless of system mode)
        navAppearance.backgroundColor = UIColor(AppTheme.Colors.DarkMode.background)
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]

        navAppearance.buttonAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(AppTheme.Colors.accent)
        ]

        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = UIColor(AppTheme.Colors.accent)

        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()

        let selectedColor = UIColor(AppTheme.Colors.warmAmber)
        // Always dark tab bar (Copilot-style)
        tabBarAppearance.backgroundColor = UIColor(AppTheme.Colors.DarkMode.background)
        let normalColor = UIColor(AppTheme.Colors.DarkMode.textTertiary)

        tabBarAppearance.stackedLayoutAppearance.normal.iconColor = normalColor
        tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: normalColor]
        tabBarAppearance.stackedLayoutAppearance.selected.iconColor = selectedColor
        tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selectedColor]
        tabBarAppearance.inlineLayoutAppearance.normal.iconColor = normalColor
        tabBarAppearance.inlineLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: normalColor]
        tabBarAppearance.inlineLayoutAppearance.selected.iconColor = selectedColor
        tabBarAppearance.inlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selectedColor]

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
                    Self.configureAppearance(isDark: newTheme == .dark)
                }
                .onAppear {
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
                    router.handleDeepLink(url)
                }
        }
    }

    // MARK: - Deep Link Handling

    private func handleDeepLink(_ url: URL) {
        // Supabase auth callback
        if url.scheme == "runaway" && url.host == "auth" {
            Task {
                do {
                    _ = try await supabase.auth.session(from: url)
                    await MainActor.run {
                        NotificationCenter.default.post(name: NSNotification.Name("EmailVerificationCompleted"), object: nil)
                    }
                } catch {
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

        // Strava OAuth callback
        if url.scheme == "runaway" && url.host == "strava-connected" {
            Task { await stravaService.handleStravaCallback(url: url) }
        }

        // Garmin OAuth callback
        if url.scheme == "runaway" && url.host == "garmin-connected" {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let success = components?.queryItems?.first(where: { $0.name == "success" })?.value == "true"
            Task { await MainActor.run { GarminService.shared.handleOAuthCallback(success: success) } }
        }
    }

    // MARK: - App Lifecycle

    private func handleAppBecameActive() {
        Task { await CommitmentManager.shared.refresh() }
        realtimeService.startRealtimeSubscription()
        realtimeService.resumeFromBackground()
        syncEngine.startBackgroundSync()
        Task { await syncEngine.syncPendingChanges() }
        LocationManager.shared.requestLocationPermission()
        AnalyticsService.shared.resumeFromBackground()

        if HealthKitManager.shared.isHealthKitAvailable {
            Task { await HealthKitManager.shared.requestAuthorization() }
            Task { await BiometricService.shared.syncHealthData() }
        }

        Task {
            if let athleteId = UserSession.shared.userId {
                await RestDayService.shared.runDetectionIfNeeded(athleteId: athleteId)
            }
        }

        AnalyticsService.shared.startSession()
        AnalyticsService.shared.track(.appOpened, category: .engagement)
    }

    private func handleAppEnteredBackground() {
        LocationManager.shared.stopLocationUpdates()
        realtimeService.pauseForBackground()
        syncEngine.stopBackgroundSync()
        AnalyticsService.shared.pauseForBackground()
        AnalyticsService.shared.track(.appBackgrounded, category: .engagement)
        AnalyticsService.shared.endSession()
    }
}
