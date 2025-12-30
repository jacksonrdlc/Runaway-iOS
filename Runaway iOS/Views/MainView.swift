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
    @Environment(AppRouter.self) private var router
    @State var selectedTab = 0
    @State var isDataReady: Bool = false
    @State private var showingSettings = false
    
    
    var body: some View {
        if isDataReady {
            TabView(selection: $selectedTab) {
                NavigationStack(path: Bindable(router).path) {
                    ActivitiesView()
                        .navigationTitle("Log Book")
                        .navigationBarTitleDisplayMode(.large)
                        .toolbarColorScheme(.light, for: .navigationBar)
                        .toolbarBackground(.visible, for: .navigationBar)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button(action: {
                                    router.navigate(to: .settings)
                                }) {
                                    Image(systemName: "gearshape.fill")
                                        .foregroundColor(AppTheme.Colors.LightMode.accent)
                                }
                            }
                        }
                        .navigationDestination(for: AppRouter.Route.self) { route in
                            router.destination(for: route)
                        }
                }
                .tabItem {
                    Label("Feed", systemImage: "newspaper")
                }
                .tag(0)

                NavigationStack(path: Bindable(router).path) {
                    TrainingView()
                        .toolbarColorScheme(.light, for: .navigationBar)
                        .toolbarBackground(.visible, for: .navigationBar)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button(action: {
                                    router.navigate(to: .settings)
                                }) {
                                    Image(systemName: "gearshape.fill")
                                        .foregroundColor(AppTheme.Colors.LightMode.accent)
                                }
                            }
                        }
                        .navigationDestination(for: AppRouter.Route.self) { route in
                            router.destination(for: route)
                        }
                }
                .tabItem {
                    Label("Training", systemImage: "chart.bar.fill")
                }
                .tag(1)

                NavigationStack(path: Bindable(router).path) {
                    ChatView()
                        .environmentObject(dataManager)
                        .toolbarColorScheme(.light, for: .navigationBar)
                        .toolbarBackground(.visible, for: .navigationBar)
                        .navigationDestination(for: AppRouter.Route.self) { route in
                            router.destination(for: route)
                        }
                }
                .tabItem {
                    Label("Coach", systemImage: "apple.intelligence")
                }
                .tag(2)

                NavigationStack(path: Bindable(router).path) {
                    ResearchView()
                        .toolbarColorScheme(.light, for: .navigationBar)
                        .toolbarBackground(.visible, for: .navigationBar)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button(action: {
                                    router.navigate(to: .settings)
                                }) {
                                    Image(systemName: "gearshape.fill")
                                        .foregroundColor(AppTheme.Colors.LightMode.accent)
                                }
                            }
                        }
                        .navigationDestination(for: AppRouter.Route.self) { route in
                            router.destination(for: route)
                        }
                }
                .tabItem {
                    Label("Research", systemImage: "flask")
                }
                .tag(3)

                NavigationStack(path: Bindable(router).path) {
                    Group {
                        if let athlete = dataManager.athlete, let stats = dataManager.stats {
                            AthleteView(athlete: athlete, stats: stats)
                                .navigationTitle("Profile")
                                .navigationBarTitleDisplayMode(.large)
                                .toolbar {
                                    ToolbarItem(placement: .navigationBarTrailing) {
                                        Button(action: {
                                            router.navigate(to: .settings)
                                        }) {
                                            Image(systemName: "gearshape.fill")
                                                .foregroundColor(AppTheme.Colors.LightMode.accent)
                                        }
                                    }
                                }
                        } else {
                            VStack(spacing: AppTheme.Spacing.md) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                    .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.LightMode.accent))
                                Text("Loading profile...")
                                    .font(AppTheme.Typography.body)
                                    .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(AppTheme.Colors.LightMode.background)
                            .navigationTitle("Profile")
                            .navigationBarTitleDisplayMode(.large)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button(action: {
                                        router.navigate(to: .settings)
                                    }) {
                                        Image(systemName: "gearshape.fill")
                                            .foregroundColor(AppTheme.Colors.LightMode.accent)
                                    }
                                }
                            }
                        }
                    }
                    .toolbarColorScheme(.light, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .navigationDestination(for: AppRouter.Route.self) { route in
                        router.destination(for: route)
                    }
                }
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(4)
            }
            .accentColor(AppTheme.Colors.LightMode.accent)
            .onChange(of: selectedTab) { oldTab, newTab in
                // Track tab selection analytics
                let tabNames = ["Feed", "Training", "Coach", "Research", "Profile"]
                let tabName = newTab < tabNames.count ? tabNames[newTab] : "Unknown"
                AnalyticsService.shared.track(.tabSelected, category: .navigation, properties: [
                    "tab_name": tabName,
                    "tab_index": newTab,
                    "previous_tab": oldTab
                ])
            }
            .task {
                await loadInitialData()
                realtimeService.startRealtimeSubscription()
            }
            .background(AppTheme.Colors.LightMode.background.ignoresSafeArea())
        } else {
            ZStack {
                AppTheme.Colors.LightMode.background
                    .ignoresSafeArea()

                VStack(spacing: AppTheme.Spacing.xl) {
                    // App Logo/Title
                    VStack(spacing: AppTheme.Spacing.md) {
                        Image(systemName: "figure.run")
                            .font(.system(size: 80, weight: .light))
                            .foregroundColor(AppTheme.Colors.LightMode.accent)
                            .shadow(color: AppTheme.Colors.LightMode.accent.opacity(0.3), radius: 10, x: 0, y: 5)

                        Text("Runaway")
                            .font(.system(size: 48, weight: .heavy, design: .rounded))
                            .foregroundColor(AppTheme.Colors.LightMode.accent)
                            .italic()
                    }

                    // Loading indicator and text
                    VStack(spacing: AppTheme.Spacing.lg) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.LightMode.accent))

                        VStack(spacing: AppTheme.Spacing.sm) {
                            Text("Loading your data...")
                                .font(AppTheme.Typography.headline)
                                .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

                            Text("Syncing activities and performance metrics")
                                .font(AppTheme.Typography.body)
                                .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
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
