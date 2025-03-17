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
    
    
    var body: some View {
        if isSupabaseDataReady {
            TabView(selection: $selectedTab) {
                ActivitiesView(activities: activities)
                    .tabItem {
                        Label("Activities", systemImage: "square.and.arrow.up")
                    }
                    .tag(0)
                //                UploadView()
                //                    .tabItem {
                //                        Label("Upload", systemImage: "square.and.arrow.up")
                //                    }
                //                    .tag(2)
                AthleteView(athlete: athlete!, stats: stats!)
                    .tabItem {
                        Label("Athlete", systemImage: "chart.bar.doc.horizontal")
                    }
                    .tag(1)
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
    func addOrSubtractDay(day:Int)->Date{
        return Calendar.current.date(byAdding: .day, value: day, to: Date())!
    }
    
    private func fetchSupabaseData() {
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
            let weeklyActivities = activities.filter { act in
                print("Start date: \(act.start_date!)")
                print("Start of week: \(Date().startOfWeek())")
                if act.start_date! > Date().startOfWeek() {
                    print(act.start_date!)
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
                    print("Friday makes me holla!")
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
}
