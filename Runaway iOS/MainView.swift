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
    private let supabase = SupabaseHelper.shared.client
    @State var selectedTab = 0
    @State var isSupabaseDataReady: Bool = false
    @State var activityDays: [ActivityDay] = []
    @State var activities: [SbActivity] = []
    @State var athlete: Athlete?
    @State var stats: AthleteStats?
    
    var body: some View {
        if isSupabaseDataReady{
            TabView(selection: $selectedTab) {
                SbActivitiesView(activities: activities)
                    .tabItem {
                        Label("Activities", systemImage: "square.and.arrow.up")
                    }
                    .tag(0)
                StravaIntegrateView()
                    .tabItem {
                        Label("Strava", systemImage: "chart.bar.doc.horizontal")
                    }
                    .tag(1)
            }
        } else {
            LoaderView()
                .onAppear{
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
            do {
                let activities: [SbActivity] = try await supabase
                    .from("activities")
                    .select()
                    .execute()
                    .value
                
                print("Response: \(activities)")
                print(activities[0].name)
                print(activities[0].start_date)
                print(activities[0].distance)
//                let decoder = JSONDecoder()
//                self.activities = try decoder.decode([SbActivity].self, from: response.data)
                self.activities = activities
                isSupabaseDataReady = true
            } catch {
                print("Error fetching activities: \(error)")
                isSupabaseDataReady = true
            }
        }
    }
    
    func dates() -> [String] {
        // For calendrical calculations you should use noon time
        // So lets get endDate's noon time
        let firstDayOfMonth = Date().startOfMonth
        let lastDayOfMonth = Date().endOfMonth
        //        guard let endDate = Formatter.date.date(from: lastDayOfMonth)?.noon else { return [] }
        // then lets get today's noon time
        var date = firstDayOfMonth.noon
        var dates: [String] = []
        // while date is less than or equal to endDate
        while date <= lastDayOfMonth {
            // add the formatted date to the array
            let formattedDate = DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none)
            dates.append(formattedDate)
            // increment the date by one day
            date = Calendar.current.date(byAdding: .day, value: 1, to: date)!
        }
        return dates
    }
    
    func setUpUserDefaults() {
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
    
    private func createDailyActivityRecord(activities : [Activity]) {
        var sunArray: Array<String> = [];
        var monArray: Array<String> = [];
        var tueArray: Array<String> = [];
        var wedArray: Array<String> = [];
        var thuArray: Array<String> = [];
        var friArray: Array<String> = [];
        var satArray: Array<String> = [];
        if let userDefaults = UserDefaults(suiteName: "group.com.jackrudelic.runawayios") {
            let weeklyActivities = activities.filter { act in
                if act.startDate! > Date().startOfWeek() {
                    return true
                } else {
                    return false
                    
                }
            }
            for activity in weeklyActivities {
                if (activity.startDate!.dayOfTheWeek ==
                    "Sunday") {
                    let sundayAct = RAActivity(
                        day: "S",
                        type: activity.type?.rawValue,
                        distance: activity.distance! * 0.00062137,
                        time: activity.elapsedTime! / 60);
                    let jsonData = try! JSONEncoder().encode(sundayAct)
                    let jsonString = String(data: jsonData, encoding: .utf8)!
                    sunArray.append(jsonString);
                    userDefaults.set(sunArray, forKey: "sunArray");
                }
                if (activity.startDate!.dayOfTheWeek ==
                    "Monday") {
                    let mondayAct = RAActivity(
                        day: "M",
                        type: activity.type?.rawValue,
                        distance: activity.distance! * 0.00062137,
                        time: activity.elapsedTime! / 60);
                    
                    let jsonData = try! JSONEncoder().encode(mondayAct)
                    let jsonString = String(data: jsonData, encoding: .utf8)!
                    monArray.append(jsonString);
                    userDefaults.set(monArray, forKey: "monArray");
                }
                if (activity.startDate!.dayOfTheWeek ==
                    "Tuesday") {
                    let tuesdayAct = RAActivity(
                        day: "T",
                        type: activity.type?.rawValue,
                        distance: activity.distance! * 0.00062137,
                        time: activity.elapsedTime! / 60);
                    
                    let jsonData = try! JSONEncoder().encode(tuesdayAct)
                    let jsonString = String(data: jsonData, encoding: .utf8)!
                    tueArray.append(jsonString);
                    userDefaults.set(tueArray, forKey: "tueArray");
                }
                if (activity.startDate!.dayOfTheWeek ==
                    "Wednesday") {
                    let wednesdayAct = RAActivity(
                        day: "W",
                        type: activity.type?.rawValue,
                        distance: activity.distance! * 0.00062137,
                        time: activity.elapsedTime! / 60);
                    
                    let jsonData = try! JSONEncoder().encode(wednesdayAct)
                    let jsonString = String(data: jsonData, encoding: .utf8)!
                    wedArray.append(jsonString);
                    userDefaults.set(wedArray, forKey: "wedArray");
                }
                if (activity.startDate!.dayOfTheWeek ==
                    "Thursday") {
                    let thursdayAct = RAActivity(
                        day: "Th",
                        type: activity.type?.rawValue,
                        distance: activity.distance! * 0.00062137,
                        time: activity.elapsedTime! / 60);
                    let jsonData = try! JSONEncoder().encode(thursdayAct)
                    let jsonString = String(data: jsonData, encoding: .utf8)!
                    thuArray.append(jsonString);
                    userDefaults.set(thuArray, forKey: "thuArray");
                }
                if (activity.startDate!.dayOfTheWeek ==
                    "Friday") {
                    let fridayAct = RAActivity(
                        day: "F",
                        type: activity.type?.rawValue,
                        distance: activity.distance! * 0.00062137,
                        time: activity.elapsedTime! / 60);
                    
                    let jsonData = try! JSONEncoder().encode(fridayAct)
                    let jsonString = String(data: jsonData, encoding: .utf8)!
                    friArray.append(jsonString);
                    userDefaults.set(friArray, forKey: "friArray");
                }
                if (activity.startDate!.dayOfTheWeek ==
                    "Saturday") {
                    let saturdayAct = RAActivity(
                        day: "Sat",
                        type: activity.type?.rawValue,
                        distance: activity.distance! * 0.00062137,
                        time: activity.elapsedTime! / 60);
                    
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

