//
//  RunawayWidget.swift
//  RunawayWidget
//
//  Created by Jack Rudelic on 2/18/25.
//

import WidgetKit
import SwiftUI
import Charts

struct Day: Identifiable {
    var name: String
    var type: String
    var minutes: Double = 0
    var miles: Double = 0
    var id = UUID()
}

struct Activity: Codable {
    var day: String
    var type: String
    var distance: Double
    var time: Double
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let miles: Double
    let monthlyMiles: Double
    let runs: Int
    let days: [Day]
}

struct BarChart: View {
    var days: [Day]
    var body: some View {
        Chart {
            ForEach(days) { day in
                BarMark(
                    x: .value("Day", day.name),
                    y: .value("Minutes", day.minutes)
                ).foregroundStyle(by: .value("Type", day.type))
            }
            
        }
        .chartForegroundStyleScale([
            "Run": .green, "Walk": .purple, "WeightTraining": .pink, "Yoga": .orange
        ])
    }
}



struct PieChartView: View {
    
    var current: Double
    var goalRemaining: Double
    var color: Color
    
    var data: [(type: String, amount: Double)] {
        [(type: "current", amount: current),
         (type: "goal", amount: goalRemaining)
        ]
    }
    
    var body: some View {
        Chart(data, id: \.type) { dataItem in
            SectorMark(angle: .value("Type", dataItem.amount),
                       innerRadius: .ratio(0.5),
                       angularInset: 1.5)
            .cornerRadius(5)
            .opacity(dataItem.type == "current" ? 1 : 0.5)
            .foregroundStyle(color)
        }
        .frame(height: 65)
        .chartBackground { chartProxy in
            GeometryReader { geometry in
                let frame = geometry[chartProxy.plotFrame!]
                Text(String(format: "%.1f", current)).font(.system( size: 10, weight: .heavy)).position(x: frame.midX, y: frame.midY)
            }
        }
    }
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), miles: 0.0, monthlyMiles: 0.0, runs: 0, days: [])
    }
    
    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        SimpleEntry(date: Date(), miles: 0.0, monthlyMiles: 0.0, runs: 0, days: [])
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        var entries: [SimpleEntry] = []
        let currentDate = Date()
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            var entry = SimpleEntry(date: entryDate, miles: 0.0, monthlyMiles: 0.0, runs: 0, days: [])
            if let userDefaults = UserDefaults(suiteName: "group.com.jackrudelic.runawayios") {
                
                let miles = userDefaults.double(forKey: "miles")
                let runs = userDefaults.integer(forKey: "runs")
                let monthlyMiles = userDefaults.double(forKey: "monthlyMiles")
                
                print("miles: \(miles)")
                print("runs: \(runs)")
                print("monthlyMiles: \(monthlyMiles)")
                
                let sunArray: Array<String> = userDefaults.stringArray(forKey: "sunArray") ?? []
                let monArray: Array<String> = userDefaults.stringArray(forKey: "monArray") ?? []
                let tuesArray: Array<String> = userDefaults.stringArray(forKey: "tueArray") ?? []
                let wednesArray: Array<String> = userDefaults.stringArray(forKey: "wedArray") ?? []
                let thursArray: Array<String> = userDefaults.stringArray(forKey: "thuArray") ?? []
                let friArray: Array<String> = userDefaults.stringArray(forKey: "friArray") ?? []
                let satArray: Array<String> = userDefaults.stringArray(forKey: "satArray") ?? []
                
                var sundayActivities: Array<Activity> = []
                for act in sunArray {
                    print(act)
                    if let jsonData = act.data(using: .utf8)
                    {
                        let decoder = JSONDecoder()
                        
                        do {
                            let activity = try decoder.decode(Activity.self, from: jsonData)
                            sundayActivities.append(activity)
                            
                        } catch {
                            print(error.localizedDescription)
                        }
                    }
                    
                }
                var mondayActivities: Array<Activity> = []
                for act in monArray {
                    print(act)
                    if let jsonData = act.data(using: .utf8)
                    {
                        let decoder = JSONDecoder()
                        
                        do {
                            let activity = try decoder.decode(Activity.self, from: jsonData)
                            mondayActivities.append(activity)
                        } catch {
                            print(error.localizedDescription)
                        }
                    }
                    
                }
                var tuesdayActivities: Array<Activity> = []
                for act in tuesArray {
                    print(act)
                    if let jsonData = act.data(using: .utf8)
                    {
                        let decoder = JSONDecoder()
                        
                        do {
                            let activity = try decoder.decode(Activity.self, from: jsonData)
                            tuesdayActivities.append(activity)
                        } catch {
                            print(error.localizedDescription)
                        }
                    }
                    
                }
                var wednesdayActivities: Array<Activity> = []
                for act in wednesArray {
                    print(act)
                    if let jsonData = act.data(using: .utf8)
                    {
                        let decoder = JSONDecoder()
                        
                        do {
                            let activity = try decoder.decode(Activity.self, from: jsonData)
                            wednesdayActivities.append(activity)
                        } catch {
                            print(error.localizedDescription)
                        }
                    }
                    
                }
                var thursdayActivities: Array<Activity> = []
                for act in thursArray {
                    print(act)
                    if let jsonData = act.data(using: .utf8)
                    {
                        let decoder = JSONDecoder()
                        
                        do {
                            let activity = try decoder.decode(Activity.self, from: jsonData)
                            thursdayActivities.append(activity)
                        } catch {
                            print(error.localizedDescription)
                        }
                    }
                    
                }
                var fridayActivities: Array<Activity> = []
                for act in friArray {
                    print(act)
                    if let jsonData = act.data(using: .utf8)
                    {
                        let decoder = JSONDecoder()
                        
                        do {
                            let activity = try decoder.decode(Activity.self, from: jsonData)
                            fridayActivities.append(activity)
                        } catch {
                            print(error.localizedDescription)
                        }
                    }
                    
                }
                var saturdayActivities: Array<Activity> = []
                for act in satArray {
                    if let jsonData = act.data(using: .utf8)
                    {
                        let decoder = JSONDecoder()
                        
                        do {
                            let activity = try decoder.decode(Activity.self, from: jsonData)
                            saturdayActivities.append(activity)
                        } catch {
                            print(error.localizedDescription)
                        }
                    }
                    
                }

                let weekActivitiesPt1: [Activity] = sundayActivities.sorted(by: { $0.type < $1.type }) + mondayActivities.sorted(by: { $0.type < $1.type }) + tuesdayActivities.sorted(by: { $0.type < $1.type })
                let weekActivitiesPt2: [Activity] = wednesdayActivities.sorted(by: { $0.type < $1.type }) + thursdayActivities.sorted(by: { $0.type < $1.type }) + fridayActivities.sorted(by: { $0.type < $1.type }) + saturdayActivities.sorted(by: { $0.type < $1.type })
                
                let weekActivities: [Activity] = weekActivitiesPt1 + weekActivitiesPt2
                
                var daysData: [Day] = [
                    
                    .init(name: "S", type: "Run", minutes: 0.0, miles: 0.0),
                    .init(name: "M", type: "Run", minutes: 0.0, miles: 0.0),
                    .init(name: "T", type: "Run", minutes: 0.0, miles: 0.0),
                    .init(name: "W", type: "Run", minutes: 0.0, miles: 0.0),
                    .init(name: "Th", type: "Run", minutes: 0.0, miles: 0.0),
                    .init(name: "F", type: "Run", minutes: 0.0, miles: 0.0),
                    .init(name: "Sat", type: "Run", minutes: 0.0, miles: 0.0)
                ]
                
                for act in weekActivities {
                    daysData.append(Day(name: act.day, type: act.type, minutes: act.time, miles: act.distance))
                }
                
                entry = SimpleEntry(date: entryDate, miles: miles, monthlyMiles: monthlyMiles, runs: runs, days: daysData)
            }
            entries.append(entry)
        }
        
        return Timeline(entries: entries, policy: .atEnd)
    }
}



struct RunawayWidgetEntryView : View {
    var entry: Provider.Entry
    
    var weeklyMileage: Double {
        entry.days.reduce(0) { $0 + $1.miles }
    }
    
    var body: some View {
        VStack (alignment: .leading) {
            HStack(alignment: .bottom){
                Label("Kirkwood, MO", systemImage: "location.fill").font(.system(size: 13))
                Spacer()
                Text("Runaway").font(.system(size: 16, weight: .heavy)).italic()
            }.padding(.bottom, 8)
            HStack(alignment: .top){
                BarChart(days: entry.days)
            }
            HStack(alignment: .bottom){
                VStack(alignment: .leading){
                    Text("Total Miles:").font(.system(size: 14, weight: .semibold)).padding(.bottom,1)
                    Text(String((entry.miles * Double(0.00062137)).thousandsOfMiles)).font(.custom("Futura-CondensedExtraBold", fixedSize: 40)).tracking(-1)
                }.frame(minWidth: 140).padding(.bottom,8)
                Spacer()
                VStack{
                    PieChartView(current: weeklyMileage, goalRemaining: 20.0 - weeklyMileage, color: .blue).padding(.bottom,2)
                    Text("Weekly").font(.system(size: 8, weight: .heavy))
                }.padding(.bottom,8)
                VStack{
                    PieChartView(current: entry.monthlyMiles, goalRemaining: 100.0 - entry.monthlyMiles, color: .green).padding(.bottom,2)
                    Text("Monthly").font(.system(size: 8, weight: .heavy))
                }.padding(.bottom,8)
            }.padding(.top, 16)
            HStack(alignment: .bottom){
                Spacer()
                Text("Last Updated:").font(.system(size: 9))
                Text(entry.date, style: .date).font(.system(size: 9))
                Text(entry.date, style: .time).font(.system(size: 9))
            }
        }.background(
            Image ("kwood")
                .overlay(
                    Color(red: 0 / 255, green: 6 / 255, blue: 53 / 255)
                        .opacity(0.8))
                .frame(width: 800, height: 800))
    }
}

struct RunawayWidget: Widget {
    let kind: String = "RunawayWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                RunawayWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        Color(red: 33 / 255, green: 33 / 255, blue: 33 / 255)
                    }
            } else {
                RunawayWidgetEntryView(entry: entry)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .configurationDisplayName("My Widget")
        .description("This is an example widget.")
    }
}

extension ConfigurationAppIntent {
    fileprivate static var smiley: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.favoriteEmoji = "😀"
        return intent
    }
    
    fileprivate static var starEyes: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.favoriteEmoji = "🤩"
        return intent
    }
}

extension Double {
    var thousandsOfMiles: String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.minimumFractionDigits = 1
        numberFormatter.maximumFractionDigits = 1
        return numberFormatter.string(from: NSNumber(value:self)) ?? String(self)
    }
}

#Preview(as: .systemLarge) {
    RunawayWidget()
} timeline: {
    SimpleEntry(date: .now, miles: 0.0, monthlyMiles: 0, runs: 0, days: [])
    SimpleEntry(date: .now, miles: 0.0, monthlyMiles: 0, runs: 0, days: [])
}
