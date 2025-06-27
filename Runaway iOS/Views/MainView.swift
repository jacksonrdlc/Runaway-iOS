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
    @State var selectedTab = 0
    @State var isSupabaseDataReady: Bool = false
    @State var activityDays: [ActivityDay] = []
    @State var activities: [Activity] = []
    @State var athlete: Athlete?
    @State var stats: AthleteStats?
    
    
    var body: some View {
        if isSupabaseDataReady {
            NavigationView {
                TabView(selection: $selectedTab) {
                    ActivitiesView(activities: $activities)
                        .tabItem {
                            Label("Activities", systemImage: "sportscourt")
                        }
                        .tag(0)
                    
                    AnalysisView(activities: activities)
                        .tabItem {
                            Label("Analysis", systemImage: "chart.line.uptrend.xyaxis")
                        }
                        .tag(1)
                    AthleteView(athlete: athlete!, stats: stats!)
                        .tabItem {
                            Label("Athlete", systemImage: "person.crop.circle")
                        }
                        .tag(2)
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Sign Out") {
                            Task {
                                try? await authManager.signOut()
                                userManager.clearUser()
                            }
                        }
                        .foregroundColor(.red)
                    }
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
            }
        } else {
            LoaderView()
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
                let stats = try await AthleteService.getAthleteStats()
                self.stats = stats
                print("Successfully fetched athlete stats: \(stats)")
                
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
        
        let monthlyMiles = activities.reduce(0) { $0 + $1.distance! }
        userDefaults.set((monthlyMiles * 0.00062137), forKey: "monthlyMiles")
        
        let weeklyActivities = activities.filter { act in
            if act.start_date! > Date().startOfWeek() {
                return true
            } else {
                return false
            }
        }
        
        for activity in weeklyActivities {
            if (Date(timeIntervalSince1970: activity.start_date!).dayOfTheWeek == "Sunday") {
                let sundayAct = RAActivity(
                    day: "S",
                    type: activity.type,
                    distance: activity.distance! * 0.00062137,
                    time: activity.elapsed_time! / 60);
                let jsonData = try! JSONEncoder().encode(sundayAct)
                let jsonString = String(data: jsonData, encoding: .utf8)!
                sunArray.append(jsonString);
                userDefaults.set(sunArray, forKey: "sunArray");
            }
            if (Date(timeIntervalSince1970: activity.start_date!).dayOfTheWeek == "Monday") {
                let mondayAct = RAActivity(
                    day: "M",
                    type: activity.type,
                    distance: activity.distance! * 0.00062137,
                    time: activity.elapsed_time! / 60);
                
                let jsonData = try! JSONEncoder().encode(mondayAct)
                let jsonString = String(data: jsonData, encoding: .utf8)!
                monArray.append(jsonString);
                print("Monday activity added: \(jsonString)")
                userDefaults.set(monArray, forKey: "monArray");
            }
            if (Date(timeIntervalSince1970: activity.start_date!).dayOfTheWeek == "Tuesday") {
                let tuesdayAct = RAActivity(
                    day: "T",
                    type: activity.type,
                    distance: activity.distance! * 0.00062137,
                    time: activity.elapsed_time! / 60);
                
                let jsonData = try! JSONEncoder().encode(tuesdayAct)
                let jsonString = String(data: jsonData, encoding: .utf8)!
                tueArray.append(jsonString);
                userDefaults.set(tueArray, forKey: "tueArray");
            }
            if (Date(timeIntervalSince1970: activity.start_date!).dayOfTheWeek == "Wednesday") {
                let wednesdayAct = RAActivity(
                    day: "W",
                    type: activity.type,
                    distance: activity.distance! * 0.00062137,
                    time: activity.elapsed_time! / 60);
                
                let jsonData = try! JSONEncoder().encode(wednesdayAct)
                let jsonString = String(data: jsonData, encoding: .utf8)!
                wedArray.append(jsonString);
                userDefaults.set(wedArray, forKey: "wedArray");
            }
            if (Date(timeIntervalSince1970: activity.start_date!).dayOfTheWeek == "Thursday") {
                let thursdayAct = RAActivity(
                    day: "Th",
                    type: activity.type,
                    distance: activity.distance! * 0.00062137,
                    time: activity.elapsed_time! / 60);
                let jsonData = try! JSONEncoder().encode(thursdayAct)
                let jsonString = String(data: jsonData, encoding: .utf8)!
                thuArray.append(jsonString);
                userDefaults.set(thuArray, forKey: "thuArray");
            }
            if (Date(timeIntervalSince1970: activity.start_date!).dayOfTheWeek == "Friday") {
                let fridayAct = RAActivity(
                    day: "F",
                    type: activity.type,
                    distance: activity.distance! * 0.00062137,
                    time: activity.elapsed_time! / 60);
                
                let jsonData = try! JSONEncoder().encode(fridayAct)
                let jsonString = String(data: jsonData, encoding: .utf8)!
                friArray.append(jsonString);
                userDefaults.set(friArray, forKey: "friArray");
            }
            if (Date(timeIntervalSince1970: activity.start_date!).dayOfTheWeek == "Saturday") {
                let saturdayAct = RAActivity(
                    day: "Sat",
                    type: activity.type,
                    distance: activity.distance! * 0.00062137,
                    time: activity.elapsed_time! / 60);
                
                let jsonData = try! JSONEncoder().encode(saturdayAct)
                let jsonString = String(data: jsonData, encoding: .utf8)!
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
