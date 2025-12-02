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
    @State var selectedTab = 0
    @State var isDataReady: Bool = false
    @State private var showingSettings = false
    
    
    var body: some View {
        if isDataReady {
            TabView(selection: $selectedTab) {
                NavigationView {
                    ActivitiesView()
                        .navigationTitle("Log Book")
                        .navigationBarTitleDisplayMode(.large)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button(action: {
                                    showingSettings = true
                                }) {
                                    Image(systemName: "gearshape.fill")
                                        .foregroundColor(AppTheme.Colors.accent)
                                }
                            }
                        }
                }
                .tabItem {
                    Label("Feed", systemImage: "newspaper")
                }
                .tag(0)

                NavigationView {
                    UnifiedInsightsView()
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button(action: {
                                    showingSettings = true
                                }) {
                                    Image(systemName: "gearshape.fill")
                                        .foregroundColor(AppTheme.Colors.accent)
                                }
                            }
                        }
                }
                .tabItem {
                    Label("Training", systemImage: "chart.bar.fill")
                }
                .tag(1)

                NavigationView {
                    ChatView()
                        .environmentObject(dataManager)
                }
                .tabItem {
                    Label("Coach", systemImage: "apple.intelligence")
                }
                .tag(2)

                NavigationView {
                    ResearchView()
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button(action: {
                                    showingSettings = true
                                }) {
                                    Image(systemName: "gearshape.fill")
                                        .foregroundColor(AppTheme.Colors.accent)
                                }
                            }
                        }
                }
                .tabItem {
                    Label("Research", systemImage: "flask")
                }
                .tag(3)

                NavigationView {
                    if let athlete = dataManager.athlete, let stats = dataManager.stats {
                        AthleteView(athlete: athlete, stats: stats)
                            .navigationTitle("Profile")
                            .navigationBarTitleDisplayMode(.large)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button(action: {
                                        showingSettings = true
                                    }) {
                                        Image(systemName: "gearshape.fill")
                                            .foregroundColor(AppTheme.Colors.accent)
                                    }
                                }
                            }
                    } else {
                        VStack(spacing: AppTheme.Spacing.md) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.accent))
                            Text("Loading profile...")
                                .font(AppTheme.Typography.body)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(AppTheme.Colors.background)
                        .navigationTitle("Profile")
                        .navigationBarTitleDisplayMode(.large)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button(action: {
                                    showingSettings = true
                                }) {
                                    Image(systemName: "gearshape.fill")
                                        .foregroundColor(AppTheme.Colors.accent)
                                }
                            }
                        }
                    }
                }
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(4)
            }
            .accentColor(AppTheme.Colors.accent)
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(userSession)
            }
            .task {
                await loadInitialData()
                realtimeService.startRealtimeSubscription()
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
        } else {
            ZStack {
                AppTheme.Colors.background
                    .ignoresSafeArea()

                VStack(spacing: AppTheme.Spacing.xl) {
                    // App Logo/Title
                    VStack(spacing: AppTheme.Spacing.md) {
                        Image(systemName: "figure.run")
                            .font(.system(size: 80, weight: .light))
                            .foregroundColor(AppTheme.Colors.accent)
                            .shadow(color: AppTheme.Colors.accent.opacity(0.3), radius: 10, x: 0, y: 5)

                        Text("Runaway")
                            .font(.system(size: 48, weight: .heavy, design: .rounded))
                            .foregroundColor(AppTheme.Colors.accent)
                            .italic()
                    }

                    // Loading indicator and text
                    VStack(spacing: AppTheme.Spacing.lg) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.accent))

                        VStack(spacing: AppTheme.Spacing.sm) {
                            Text("Loading your data...")
                                .font(AppTheme.Typography.headline)
                                .foregroundColor(AppTheme.Colors.textPrimary)

                            Text("Syncing activities and performance metrics")
                                .font(AppTheme.Typography.body)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .padding(AppTheme.Spacing.xl)
            }
            .preferredColorScheme(.dark)
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
