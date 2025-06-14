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
    @State var selectedTab = 0
    @State var isSupabaseDataReady: Bool = false
    @State var activityDays: [ActivityDay] = []
    @State var activities: [Activity] = []
    @State var athlete: Athlete?
    @State var stats: AthleteStats?
    @State private var subscription: RealtimeSubscription?
    
    
    var body: some View {
        if isSupabaseDataReady {
            TabView(selection: $selectedTab) {
                ActivitiesView(activities: $activities)
                    .tabItem {
                        Label("Activities", systemImage: "sportscourt")
                    }
                    .tag(0)
                AthleteView(athlete: athlete!, stats: stats!)
                    .tabItem {
                        Label("Athlete", systemImage: "person.crop.circle")
                    }
                    .tag(1)
            }
            .onAppear {
                setupRealtimeSubscription()
                fetchSupabaseData()
            }
            .onDisappear {
                cleanupSubscription()
            }
        } else {
            LoaderView()
                .onAppear {
                    print("Auth manager user ID: \(String(describing: authManager.currentUser?.id))")
                    fetchSupabaseData()
                }
        }
    }
    
    private func setupRealtimeSubscription() {
        Task {
            // Create channel
            let channel = supabase.channel("public:activities")
            
            // Create the observations before subscribing
            let insertions = channel.postgresChange(
              AnyAction.self,
              table: "activities"
            )
            
            print("Subscribing to channel")
            await channel.subscribe()
            
            for await _ in insertions {
                fetchSupabaseData()
                print("Inserted:")
            }
        }
    }
    
    private func cleanupSubscription() {
        Task {
            let channel = supabase.channel("public:activities")
            
            await supabase.removeChannel(channel)
        }
    }
}

extension MainView {
    private func fetchSupabaseData() {
        clearUserDefaults()
        Task {
            print("Fetching data with user ID: \(String(describing: authManager.currentUser?.id))")
            guard let userId = authManager.currentUser?.id else {
                print("No user ID available")
                isSupabaseDataReady = true
                return
            }
            
            do {
                // Fetch athlete data using AthleteService
                let athlete = try await AthleteService.getAthleteByUserId(userId: userId)
                print("Successfully fetched athlete: \(athlete)")
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
                self.activities = try await ActivityService.getAllActivitiesByUser(userId: userId)
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
        var sunArray: Array<String> = [];
        var monArray: Array<String> = [];
        var tueArray: Array<String> = [];
        var wedArray: Array<String> = [];
        var thuArray: Array<String> = [];
        var friArray: Array<String> = [];
        var satArray: Array<String> = [];
        if let userDefaults = UserDefaults(suiteName: "group.com.jackrudelic.runawayios") {
            print("Creating activity record")
            
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
        }
        WidgetCenter.shared.reloadAllTimelines()
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
