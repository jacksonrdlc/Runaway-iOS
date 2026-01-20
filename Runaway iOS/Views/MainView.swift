//
//  MainView.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 7/16/24.
//
import SwiftUI
import WidgetKit
import Supabase

struct MainView: View {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var realtimeService: RealtimeService
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(AppRouter.self) private var router
    @State var selectedTab = 0
    @State var isDataReady: Bool = false
    @State private var showRecording = false

    private var toolbarScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    private var backgroundColor: Color {
        themeManager.isDarkMode ? AppTheme.Colors.DarkMode.background : AppTheme.Colors.LightMode.background
    }

    var body: some View {
        if isDataReady {
            ZStack(alignment: .bottom) {
                // Tab Content
                Group {
                    switch selectedTab {
                    case 0:
                        NavigationStack(path: Bindable(router).path) {
                            ActivitiesView()
                                .navigationTitle("Activities")
                                .navigationBarTitleDisplayMode(.inline)
                                .toolbarColorScheme(toolbarScheme, for: .navigationBar)
                                .toolbarBackground(.visible, for: .navigationBar)
                                .navigationDestination(for: AppRouter.Route.self) { route in
                                    router.destination(for: route)
                                }
                        }
                    case 1:
                        NavigationStack(path: Bindable(router).path) {
                            TrainingView()
                                .toolbarColorScheme(toolbarScheme, for: .navigationBar)
                                .toolbarBackground(.visible, for: .navigationBar)
                                .navigationDestination(for: AppRouter.Route.self) { route in
                                    router.destination(for: route)
                                }
                        }
                    case 3:
                        NavigationStack(path: Bindable(router).path) {
                            PlanView()
                                .environmentObject(dataManager)
                                .toolbarColorScheme(toolbarScheme, for: .navigationBar)
                                .toolbarBackground(.visible, for: .navigationBar)
                                .navigationDestination(for: AppRouter.Route.self) { route in
                                    router.destination(for: route)
                                }
                        }
                    case 4:
                        NavigationStack(path: Bindable(router).path) {
                            profileContent
                                .toolbarColorScheme(toolbarScheme, for: .navigationBar)
                                .toolbarBackground(.visible, for: .navigationBar)
                                .navigationDestination(for: AppRouter.Route.self) { route in
                                    router.destination(for: route)
                                }
                        }
                    default:
                        // Tab 2 is Record - handled by showRecording
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, 65) // Space for custom tab bar

                // Custom Tab Bar
                CustomTabBar(selectedTab: $selectedTab, showRecording: $showRecording)
            }
            .ignoresSafeArea(.keyboard)
            .background(backgroundColor)
            .onChange(of: selectedTab) { oldTab, newTab in
                // Track tab selection analytics
                let tabNames = ["Activities", "Progress", "Record", "Plan", "Profile"]
                let tabName = newTab < tabNames.count ? tabNames[newTab] : "Unknown"
                AnalyticsService.shared.track(.tabSelected, category: .navigation, properties: [
                    "tab_name": tabName,
                    "tab_index": newTab,
                    "previous_tab": oldTab
                ])
            }
            .fullScreenCover(isPresented: $showRecording) {
                PreRecordingView()
            }
            .onChange(of: showRecording) { wasShowing, isShowing in
                // Return to Activities tab after recording is dismissed
                if wasShowing && !isShowing {
                    selectedTab = 0
                }
            }
            .task {
                await loadInitialData()
                realtimeService.startRealtimeSubscription()
            }
        } else {
            ZStack {
                (themeManager.isDarkMode ? AppTheme.Colors.DarkMode.background : ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.background : AppTheme.Colors.LightMode.background)
                    .ignoresSafeArea()

                VStack(spacing: AppTheme.Spacing.xl) {
                    // App Logo/Title
                    VStack(spacing: AppTheme.Spacing.md) {
                        Image("LaunchLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                    }

                    // Loading indicator and text
                    VStack(spacing: AppTheme.Spacing.lg) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.accent))

                        VStack(spacing: AppTheme.Spacing.sm) {
                            Text("Loading your data...")
                                .font(AppTheme.Typography.headline)
                                .foregroundColor(themeManager.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary)

                            Text("Syncing activities and performance metrics")
                                .font(AppTheme.Typography.body)
                                .foregroundColor(themeManager.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
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
                            Button(action: {
                                router.navigate(to: .settings)
                            }) {
                                Image(systemName: "gearshape.fill")
                                    .foregroundColor(AppTheme.Colors.accent)
                            }
                        }
                    }
            } else if dataManager.isLoadingAthlete {
                // Still loading - show spinner
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
                        Button(action: {
                            router.navigate(to: .settings)
                        }) {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(AppTheme.Colors.accent)
                        }
                    }
                }
            } else {
                // Done loading but no profile - attempt reload
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
                        Button(action: {
                            router.navigate(to: .settings)
                        }) {
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
    /// Load initial user data through DataManager
    private func loadInitialData() async {
        guard let authId = userSession.currentUser?.id else {
            print("❌ MainView: No auth ID available")
            isDataReady = true
            return
        }

        do {
            // Fetch and set user profile
            let user = try await UserService.getUserByAuthId(authId: authId)
            await MainActor.run {
                userSession.setProfile(user)
                // Notify that user is logged in (for FCM token save)
                NotificationCenter.default.post(name: NSNotification.Name("UserDidLogin"), object: nil)
            }

            // Load all data through DataManager
            await dataManager.loadAllData(for: user.userId)

            await MainActor.run {
                isDataReady = true
            }

        } catch {
            print("❌ MainView: Error loading initial data: \(error)")
            await MainActor.run {
                isDataReady = true
            }
        }
    }
}

// MARK: - Profile Loading Error View

private struct ProfileLoadingErrorView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    let onRetry: () -> Void

    @State private var isRetrying = false

    private var background: Color {
        themeManager.isDarkMode ? AppTheme.Colors.DarkMode.background : AppTheme.Colors.LightMode.background
    }

    private var textPrimary: Color {
        themeManager.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary
    }

    private var textSecondary: Color {
        themeManager.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            VStack(spacing: AppTheme.Spacing.lg) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)

                Text("Couldn't load profile")
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(textPrimary)

                Text("Please check your connection and try again")
                    .font(AppTheme.Typography.body)
                    .foregroundColor(textSecondary)
                    .multilineTextAlignment(.center)

                Button(action: {
                    isRetrying = true
                    onRetry()
                    // Reset after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isRetrying = false
                    }
                }) {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        if isRetrying {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
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
