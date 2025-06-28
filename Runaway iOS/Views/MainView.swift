//
//  Profile.swift
//  RunawayUI
//
//  Created by Jack Rudelic on 7/16/24.
//
import SwiftUI
import WidgetKit
import Supabase


struct MainView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var realtimeService: RealtimeService
    @EnvironmentObject var userManager: UserManager
    @State var selectedTab = 1
    @State var isSupabaseDataReady: Bool = false
    @State var activityDays: [ActivityDay] = []
    @State var activities: [Activity] = []
    @State var athlete: Athlete?
    @State var stats: AthleteStats?
    @State private var showingSettings = false
    
    
    var body: some View {
        if isSupabaseDataReady {
            TabView(selection: $selectedTab) {
                NavigationView {
                    ActivitiesView(activities: $activities)
                        .navigationTitle("Activities")
                        .navigationBarTitleDisplayMode(.large)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button(action: {
                                    showingSettings = true
                                }) {
                                    Image(systemName: "gearshape.fill")
                                        .foregroundColor(AppTheme.Colors.primary)
                                }
                            }
                        }
                }
                .tabItem {
                    Label("Activities", systemImage: AppIcons.activities)
                }
                .tag(0)
                
                NavigationView {
                    AnalysisView(activities: activities)
                        .navigationTitle("Analysis")
                        .navigationBarTitleDisplayMode(.large)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button(action: {
                                    showingSettings = true
                                }) {
                                    Image(systemName: "gearshape.fill")
                                        .foregroundColor(AppTheme.Colors.primary)
                                }
                            }
                        }
                }
                .tabItem {
                    Label("Analysis", systemImage: AppIcons.analysis)
                }
                .tag(1)
                
                NavigationView {
                    ResearchView()
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button(action: {
                                    showingSettings = true
                                }) {
                                    Image(systemName: "gearshape.fill")
                                        .foregroundColor(AppTheme.Colors.primary)
                                }
                            }
                        }
                }
                .tabItem {
                    Label("Research", systemImage: "newspaper")
                }
                .tag(2)
                
                NavigationView {
                    if let athlete = athlete, let stats = stats {
                        AthleteView(athlete: athlete, stats: stats)
                            .navigationTitle("Profile")
                            .navigationBarTitleDisplayMode(.large)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button(action: {
                                        showingSettings = true
                                    }) {
                                        Image(systemName: "gearshape.fill")
                                            .foregroundColor(AppTheme.Colors.primary)
                                    }
                                }
                            }
                    } else {
                        VStack(spacing: AppTheme.Spacing.md) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                            Text("Loading profile...")
                                .font(AppTheme.Typography.body)
                                .foregroundColor(AppTheme.Colors.secondaryText)
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
                                        .foregroundColor(AppTheme.Colors.primary)
                                }
                            }
                        }
                    }
                }
                .tabItem {
                    Label("Profile", systemImage: "person.circle.fill")
                }
                .tag(3)
            }
            .accentColor(AppTheme.Colors.primary)
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(authManager)
                    .environmentObject(userManager)
            }
            .onAppear {
                fetchSupabaseData()
                realtimeService.startRealtimeSubscription()
            }
            .onReceive(NotificationCenter.default.publisher(for: .activitiesUpdated)) { notification in
                if let updatedActivities = notification.object as? [Activity] {
                    self.activities = updatedActivities
                }
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
        } else {
            ZStack {
                // Much darker gradient background
                LinearGradient(
                    colors: [
                        Color.black,
                        Color(red: 0.02, green: 0.02, blue: 0.05),
                        Color(red: 0.05, green: 0.05, blue: 0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: AppTheme.Spacing.xl) {
                    // App Logo/Title
                    VStack(spacing: AppTheme.Spacing.md) {
                        Image(systemName: "figure.run")
                            .font(.system(size: 80, weight: .light))
                            .foregroundColor(.white)
                            .shadow(color: .white.opacity(0.3), radius: 10, x: 0, y: 5)
                        
                        Text("Runaway")
                            .font(.system(size: 48, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .italic()
                    }
                    
                    // Loading indicator and text
                    VStack(spacing: AppTheme.Spacing.lg) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        
                        VStack(spacing: AppTheme.Spacing.sm) {
                            Text("Loading your data...")
                                .font(AppTheme.Typography.headline)
                                .foregroundColor(.white)
                            
                            Text("Syncing activities and performance metrics")
                                .font(AppTheme.Typography.body)
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .padding(AppTheme.Spacing.xl)
            }
            .onAppear {
                print("Auth manager user ID: \(String(describing: authManager.currentUser?.id))")
                fetchSupabaseData()
            }
        }
    }
}

extension MainView {
    private func fetchSupabaseData() {
        clearUserDefaults()
        Task {
            //            try await authManager.signOut()
            print("Fetching data with user ID: \(String(describing: authManager.currentUser?.id))")
            guard let authId = authManager.currentUser?.id else {
                print("No user ID available")
                isSupabaseDataReady = true
                return
            }
            
            let user: User
            do {
                // Fetch userId data using userService
                user = try await UserService.getUserByAuthId(authId: authId)
                print("Successfully fetched user: \(user)")
            } catch {
                print("Error fetching User data: \(error)")
                isSupabaseDataReady = true
                return
            }
            
            print("Fetched user: \(user)")
            print("User ID: \(user.userId)")
            
            // Store user in UserManager for global access
            await MainActor.run {
                userManager.setUser(user)
            }
            
            do {
                // Fetch athlete data using AthleteService
                print("Fetching athlete data for user ID: \(user.userId)")
                let athlete = try await AthleteService.getAthleteByUserId(userId: user.userId)
                print("Successfully fetched athlete: \(athlete.firstname) \(athlete.lastname)")
                self.athlete = athlete
            } catch {
                print("Error fetching Athlete data: \(error)")
            }
            
            do {
                // Fetch athlete stats if needed
                let stats = try await AthleteService.getAthleteStats(userId: user.userId)
                self.stats = stats
                print("Successfully fetched athlete stats:")
                print("  - Raw object: \(stats)")
                
                // Print detailed stats using Mirror for reflection
                let mirror = Mirror(reflecting: stats)
                print("Athlete Stats Properties:")
                for (label, value) in mirror.children {
                    if let propertyName = label {
                        print("  - \(propertyName): \(value)")
                    }
                }
                
            } catch {
                print("Error fetching Athlete data: \(error)")
            }
            
            do {
                self.activities = try await ActivityService.getAllActivitiesByUser(userId: user.userId)
                createActivityRecord(activities: self.activities)
                isSupabaseDataReady = true
            } catch {
                print("Error fetching Activity data: \(error)")
                self.activities = []
                isSupabaseDataReady = true
            }
        }
    }
    
    private func createActivityRecord(activities : [Activity]) {
        print("Creating activity record with \(activities.count) activities")
        var sunArray: Array<String> = [];
        var monArray: Array<String> = [];
        var tueArray: Array<String> = [];
        var wedArray: Array<String> = [];
        var thuArray: Array<String> = [];
        var friArray: Array<String> = [];
        var satArray: Array<String> = [];
        
        guard let userDefaults = UserDefaults(suiteName: "group.com.jackrudelic.runawayios") else {
            print("Failed to access shared UserDefaults")
            return
        }
        
        print("Creating activity record")
        
        // Clear existing arrays
        userDefaults.removeObject(forKey: "sunArray")
        userDefaults.removeObject(forKey: "monArray")
        userDefaults.removeObject(forKey: "tueArray")
        userDefaults.removeObject(forKey: "wedArray")
        userDefaults.removeObject(forKey: "thuArray")
        userDefaults.removeObject(forKey: "friArray")
        userDefaults.removeObject(forKey: "satArray")
        
        let monthlyMiles = activities.reduce(0) { $0 + ($1.distance ?? 0.0) }
        userDefaults.set((monthlyMiles * 0.000621371), forKey: "monthlyMiles")
        
        let weeklyActivities = activities.filter { act in
            guard let startDate = act.start_date else { return false }
            return startDate > Date().startOfWeek()
        }
        
        for activity in weeklyActivities {
            guard let startDate = activity.start_date,
                  let distance = activity.distance,
                  let elapsedTime = activity.elapsed_time else { continue }
            
            if (Date(timeIntervalSince1970: startDate).dayOfTheWeek == "Sunday") {
                let sundayAct = RAActivity(
                    day: "S",
                    type: activity.type,
                    distance: distance * 0.000621371,
                    time: elapsedTime / 60)
                
                guard let jsonData = try? JSONEncoder().encode(sundayAct),
                      let jsonString = String(data: jsonData, encoding: .utf8) else { continue }
                sunArray.append(jsonString);
                userDefaults.set(sunArray, forKey: "sunArray");
            }
            if (Date(timeIntervalSince1970: startDate).dayOfTheWeek == "Monday") {
                let mondayAct = RAActivity(
                    day: "M",
                    type: activity.type,
                    distance: distance * 0.000621371,
                    time: elapsedTime / 60)
                
                guard let jsonData = try? JSONEncoder().encode(mondayAct),
                      let jsonString = String(data: jsonData, encoding: .utf8) else { continue }
                monArray.append(jsonString);
                print("Monday activity added: \(jsonString)")
                userDefaults.set(monArray, forKey: "monArray");
            }
            if let startDate = activity.start_date,
               let distance = activity.distance,
               let elapsedTime = activity.elapsed_time,
               Date(timeIntervalSince1970: startDate).dayOfTheWeek == "Tuesday" {
                let tuesdayAct = RAActivity(
                    day: "T",
                    type: activity.type,
                    distance: distance * 0.000621371,
                    time: elapsedTime / 60);
                
                guard let jsonData = try? JSONEncoder().encode(tuesdayAct),
                      let jsonString = String(data: jsonData, encoding: .utf8) else { continue }
                tueArray.append(jsonString);
                userDefaults.set(tueArray, forKey: "tueArray");
            }
            if let startDate = activity.start_date,
               let distance = activity.distance,
               let elapsedTime = activity.elapsed_time,
               Date(timeIntervalSince1970: startDate).dayOfTheWeek == "Wednesday" {
                let wednesdayAct = RAActivity(
                    day: "W",
                    type: activity.type,
                    distance: distance * 0.000621371,
                    time: elapsedTime / 60);
                
                guard let jsonData = try? JSONEncoder().encode(wednesdayAct),
                      let jsonString = String(data: jsonData, encoding: .utf8) else { continue }
                wedArray.append(jsonString);
                userDefaults.set(wedArray, forKey: "wedArray");
            }
            if let startDate = activity.start_date,
               let distance = activity.distance,
               let elapsedTime = activity.elapsed_time,
               Date(timeIntervalSince1970: startDate).dayOfTheWeek == "Thursday" {
                let thursdayAct = RAActivity(
                    day: "Th",
                    type: activity.type,
                    distance: distance * 0.000621371,
                    time: elapsedTime / 60);
                guard let jsonData = try? JSONEncoder().encode(thursdayAct),
                      let jsonString = String(data: jsonData, encoding: .utf8) else { continue }
                thuArray.append(jsonString);
                userDefaults.set(thuArray, forKey: "thuArray");
            }
            if let startDate = activity.start_date,
               let distance = activity.distance,
               let elapsedTime = activity.elapsed_time,
               Date(timeIntervalSince1970: startDate).dayOfTheWeek == "Friday" {
                let fridayAct = RAActivity(
                    day: "F",
                    type: activity.type,
                    distance: distance * 0.000621371,
                    time: elapsedTime / 60);
                
                guard let jsonData = try? JSONEncoder().encode(fridayAct),
                      let jsonString = String(data: jsonData, encoding: .utf8) else { continue }
                friArray.append(jsonString);
                userDefaults.set(friArray, forKey: "friArray");
            }
            if let startDate = activity.start_date,
               let distance = activity.distance,
               let elapsedTime = activity.elapsed_time,
               Date(timeIntervalSince1970: startDate).dayOfTheWeek == "Saturday" {
                let saturdayAct = RAActivity(
                    day: "Sat",
                    type: activity.type,
                    distance: distance * 0.000621371,
                    time: elapsedTime / 60);
                
                guard let jsonData = try? JSONEncoder().encode(saturdayAct),
                      let jsonString = String(data: jsonData, encoding: .utf8) else { continue }
                satArray.append(jsonString);
                userDefaults.set(satArray, forKey: "satArray");
            }
        }
        
        // Force synchronization and reload widget
        userDefaults.synchronize()
        WidgetCenter.shared.reloadAllTimelines()
        print("UserDefaults synchronized and widget timeline reloaded")
    }
    
    func clearUserDefaults() {
        if let userDefaults = UserDefaults(suiteName: "group.com.jackrudelic.runawayios") {
            userDefaults.removeObject(forKey: "sunArray");
            userDefaults.removeObject(forKey: "monArray");
            userDefaults.removeObject(forKey: "tueArray");
            userDefaults.removeObject(forKey: "wedArray");
            userDefaults.removeObject(forKey: "thuArray");
            userDefaults.removeObject(forKey: "friArray");
            userDefaults.removeObject(forKey: "satArray");
            userDefaults.removeObject(forKey: "weeklyMiles");
            userDefaults.removeObject(forKey: "monthlyMiles");
        }
    }
}
