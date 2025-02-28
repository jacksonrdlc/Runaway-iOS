//
//  Profile.swift
//  RunawayUI
//
//  Created by Jack Rudelic on 7/16/24.
//
import SwiftUI
import WidgetKit

struct StravaMainView: View {
    @State var selectedTab = 0
    @State var isDataReady: Bool = false
    @State var activityDays: [ActivityDay] = []
    @State var activities: [Activity] = []
    @State var athlete: Athlete?
    @State var stats: AthleteStats?
    
    var body: some View {
        if isDataReady{
            TabView(selection: $selectedTab) {
                ActivitiesView(activities: activities)
                    .tabItem {
                        Label("Activities", systemImage: "figure.run")
                    }
                    .tag(0)
                UploadView()
                    .tabItem {
                        Label("Upload", systemImage: "square.and.arrow.up")
                    }
                    .tag(2)
                AthleteView(athlete: athlete!, stats: stats!, activityDays: activityDays)
                    .tabItem {
                        Label("Athlete", systemImage: "chart.bar.doc.horizontal")
                    }
                    .tag(1)
            }
        } else {
            LoaderView()
                .onAppear{
                    fetchStravaData()
                }
        }
    }
}


extension StravaMainView {
    
    func addOrSubtractDay(day:Int)->Date{
        return Calendar.current.date(byAdding: .day, value: day, to: Date())!
    }
    
    private func fetchStravaData() {
        StravaClient.sharedInstance.request(Router.athlete, result: {(athlete: Athlete?) in
            self.athlete = athlete!
            StravaClient.sharedInstance.request(Router.athletesStats(id: (athlete?.userId)!, params: nil), result: {(stats: AthleteStats?) in
                self.stats = stats!
                
            }, failure: { (error: NSError) in
                print(error)
                debugPrint(error)
            })
            let now = Int(Date().timeIntervalSince1970)
            let firstDayOfMonthMinusSevenDays = Int(Date().startOfMonth.timeIntervalSince1970) - 86400*7
            
            StravaClient.sharedInstance.request(Router.athleteActivities(params: ["before": now, "after": firstDayOfMonthMinusSevenDays]), result: { (activities: [Activity]?) in
                setUpUserDefaults()
                self.activities = activities!
                createDailyActivityRecord(activities: activities!)
                let activities = activities!
                print("00000000000000")
                for act in activities {
                    print(act.name)
                    print(act.type)
                    print(act.map?.summaryPolyline)
                }
                print("00000000000000")
                if let userDefaults = UserDefaults(suiteName: "group.com.jackrudelic.runawayios") {
                    let monthlyActivities = activities.filter { act in
                        if act.startDate! >=  Date().startOfMonth {
                            return true

                        } else {
                            return false

                        }
                    }
                    let monthlyMiles = monthlyActivities.reduce(0) { $0 + $1.distance! }
                    userDefaults.set((monthlyMiles * 0.00062137), forKey: "monthlyMiles")
                }
                var actDays: [ActivityDay] = []
                for day in dates() {
                    let sameDate = activities.first{DateFormatter.localizedString(from: $0.startDate!, dateStyle: .short, timeStyle: .none) == day}
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "M/d/yy"
                    let date = dateFormatter.date(from:day)!
                    let aDay = ActivityDay(date: date, minutes: sameDate != nil ? (sameDate?.elapsedTime!)! : 0)
                    actDays.append(aDay)
                }
                self.activityDays = actDays
                self.isDataReady = true
            }, failure: { (error: NSError) in
                debugPrint(error)
            })
            
        }, failure: { (error: NSError) in
            print(error)
            debugPrint(error)
        })
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
