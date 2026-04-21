//
//  MainView.swift
//  Runaway iOS
//

import SwiftUI
import WidgetKit
import Supabase

struct MainView: View {
    @Environment(UserSession.self) var userSession
    @Environment(RealtimeService.self) var realtimeService
    @Environment(DataManager.self) var dataManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(AppRouter.self) private var router
    @State var selectedTab = 0
    @State var isDataReady: Bool = false
    @State private var showingRunRecording = false

    private var backgroundColor: Color {
        themeManager.isDarkMode ? AppTheme.Colors.DarkMode.background : AppTheme.Colors.LightMode.background
    }

    var body: some View {
        if isDataReady {
            TabView(selection: $selectedTab) {
                Tab("Dashboard", systemImage: "chart.bar.fill", value: 0) {
                    NavigationStack(path: Bindable(router).path) {
                        TrainingView()
                            .navigationDestination(for: AppRouter.Route.self) { route in
                                router.destination(for: route)
                            }
                    }
                }

                Tab("Activities", systemImage: "figure.run", value: 1) {
                    NavigationStack(path: Bindable(router).path) {
                        ActivitiesView()
                            .navigationTitle("Activities")
                            .navigationBarTitleDisplayMode(.inline)
                            .navigationDestination(for: AppRouter.Route.self) { route in
                                router.destination(for: route)
                            }
                    }
                }

                Tab("Races", systemImage: "flag.checkered", value: 2) {
                    NavigationStack(path: Bindable(router).path) {
                        PlanView()
                            .navigationDestination(for: AppRouter.Route.self) { route in
                                router.destination(for: route)
                            }
                    }
                }

                Tab("Profile", systemImage: "person", value: 3) {
                    NavigationStack(path: Bindable(router).path) {
                        profileContent
                            .navigationDestination(for: AppRouter.Route.self) { route in
                                router.destination(for: route)
                            }
                    }
                }
            }
            .ignoresSafeArea(.keyboard)
            .overlay(alignment: .bottomTrailing) {
                if selectedTab == 0 {
                    StartRunFAB { showingRunRecording = true }
                        .padding(.trailing, AppTheme.Spacing.lg)
                        .padding(.bottom, 90) // Clear the tab bar + home indicator
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: selectedTab)
            .onChange(of: selectedTab) { oldTab, newTab in
                let tabNames = ["Dashboard", "Activities", "Races", "Profile"]
                let tabName = newTab < tabNames.count ? tabNames[newTab] : "Unknown"
                AnalyticsService.shared.track(.tabSelected, category: .navigation, properties: [
                    "tab_name": tabName,
                    "tab_index": newTab,
                    "previous_tab": oldTab
                ])
            }
            .fullScreenCover(isPresented: $showingRunRecording) {
                NavigationStack {
                    RunRecordingView()
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Close") {
                                    showingRunRecording = false
                                }
                                .foregroundColor(AppTheme.Colors.accent)
                            }
                        }
                }
            }
            .task {
                await loadInitialData()
                realtimeService.startRealtimeSubscription()
            }
        } else {
            ZStack {
                backgroundColor.ignoresSafeArea()

                VStack(spacing: AppTheme.Spacing.xl) {
                    VStack(spacing: AppTheme.Spacing.md) {
                        Image("LaunchLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                    }

                    VStack(spacing: AppTheme.Spacing.lg) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.accent))

                        VStack(spacing: AppTheme.Spacing.sm) {
                            Text("Loading your data...")
                                .font(AppTheme.Typography.headline)
                                .foregroundColor(themeManager.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary)

                            Text("Syncing activities and performance metrics")
                                .font(AppTheme.Typography.body)
                                .foregroundColor(themeManager.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .padding(AppTheme.Spacing.xl)
            }
            .task {
                await loadInitialData()
            }
        }
    }

    // MARK: - Profile Content

    @ViewBuilder
    private var profileContent: some View {
        Group {
            if let athlete = dataManager.athlete, let stats = dataManager.stats {
                AthleteView(athlete: athlete, stats: stats)
                    .navigationTitle("Profile")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: { router.navigate(to: .settings) }) {
                                Image(systemName: "gearshape.fill")
                                    .foregroundColor(AppTheme.Colors.accent)
                            }
                        }
                    }
            } else if dataManager.isLoadingAthlete {
                VStack(spacing: AppTheme.Spacing.md) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.accent))
                    Text("Loading profile...")
                        .font(AppTheme.Typography.body)
                        .foregroundColor(themeManager.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(backgroundColor)
                .navigationTitle("Profile")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { router.navigate(to: .settings) }) {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(AppTheme.Colors.accent)
                        }
                    }
                }
            } else {
                ProfileLoadingErrorView(onRetry: {
                    Task {
                        if let userId = userSession.userId {
                            await dataManager.loadAllData(for: userId)
                        }
                    }
                })
                .navigationTitle("Profile")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { router.navigate(to: .settings) }) {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(AppTheme.Colors.accent)
                        }
                    }
                }
            }
        }
    }
}

extension MainView {
    private func loadInitialData() async {
        guard let authId = userSession.currentUser?.id else {
            isDataReady = true
            return
        }

        do {
            let user = try await UserService.getUserByAuthId(authId: authId)
            await MainActor.run {
                userSession.setProfile(user)
                NotificationCenter.default.post(name: NSNotification.Name("UserDidLogin"), object: nil)
            }
            await dataManager.loadAllData(for: user.userId)
            await MainActor.run { isDataReady = true }
        } catch {
            await MainActor.run { isDataReady = true }
        }
    }
}

// MARK: - Start Run FAB

/// Floating action button for starting a run, overlaid on the Dashboard tab.
/// Tap opens `RunRecordingView` as a full-screen modal — full screen rather
/// than a sheet so a swipe-down can't accidentally end a run mid-stride.
private struct StartRunFAB: View {
    let action: () -> Void

    var body: some View {
        Button(action: {
            CelebrationService.shared.selectionChanged()
            action()
        }) {
            Image(systemName: "figure.run")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 64, height: 64)
                .background(AppTheme.Colors.accent)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 3)
        }
        .accessibilityLabel("Start a new run")
        .accessibilityHint("Begins recording a run with GPS and audio coaching")
    }
}

// MARK: - Profile Loading Error View

private struct ProfileLoadingErrorView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    let onRetry: () -> Void
    @State private var isRetrying = false

    var body: some View {
        ZStack {
            (themeManager.isDarkMode ? AppTheme.Colors.DarkMode.background : AppTheme.Colors.LightMode.background).ignoresSafeArea()

            VStack(spacing: AppTheme.Spacing.lg) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)

                Text("Couldn't load profile")
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(themeManager.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary)

                Text("Please check your connection and try again")
                    .font(AppTheme.Typography.body)
                    .foregroundColor(themeManager.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
                    .multilineTextAlignment(.center)

                Button(action: {
                    isRetrying = true
                    onRetry()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { isRetrying = false }
                }) {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        if isRetrying {
                            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(isRetrying ? "Loading..." : "Try Again")
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, AppTheme.Spacing.xl)
                    .padding(.vertical, AppTheme.Spacing.md)
                    .background(AppTheme.Colors.accent)
                    .cornerRadius(AppTheme.CornerRadius.medium)
                }
                .disabled(isRetrying)
            }
            .padding(AppTheme.Spacing.xl)
        }
    }
}
