//
//  RunawayWidget.swift
//  RunawayWidget
//
//  Created by Jack Rudelic on 2/18/25.
//

import WidgetKit
import SwiftUI
import Charts
import AppIntents

// MARK: - Widget Unit Helper (reads from shared UserDefaults)

struct WidgetUnitHelper {
    private static let userDefaults = UserDefaults(suiteName: "group.com.jackrudelic.runawayios")
    private static let unitKey = "preferred_distance_unit"

    /// Check if user prefers metric units
    static var isMetric: Bool {
        guard let savedValue = userDefaults?.string(forKey: unitKey) else {
            return false // Default to imperial (miles)
        }
        return savedValue == "kilometers"
    }

    /// Distance unit abbreviation
    static var unitAbbreviation: String {
        isMetric ? "km" : "mi"
    }

    /// Distance unit full name
    static var unitName: String {
        isMetric ? "Kilometers" : "Miles"
    }

    /// Convert miles to user's preferred unit
    static func convertFromMiles(_ miles: Double) -> Double {
        isMetric ? miles * 1.60934 : miles
    }

    /// Format distance value with unit
    static func formatDistance(_ miles: Double, decimals: Int = 1) -> String {
        let value = convertFromMiles(miles)
        return String(format: "%.\(decimals)f", value)
    }
}

struct Day: Identifiable {
    var name: String
    var type: String
    var minutes: Double = 0
    var miles: Double = 0 // Stored in miles, converted for display
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
    let selectedActivities: [ActivityTypeEntity]
    let weeklyGoal: Double
    let monthlyGoal: Double
    let todaysCommitmentType: String?
    let todaysCommitmentFulfilled: Bool
}

struct BarChart: View {
    var days: [Day]
    var selectedActivities: [ActivityTypeEntity]

    // Check if user has any activities this week
    private var hasActivitiesThisWeek: Bool {
        days.contains { $0.minutes > 0 }
    }

    // Array of encouraging empty state messages (non-judgmental)
    private var emptyStateMessages: [String] {
        [
            "Fresh week, fresh start",
            "Your next run awaits",
            "Rest is part of training too",
            "Ready when you are",
            "A new week of possibilities",
            "Every journey starts with one step",
            "Today is a great day for a run",
            "Your chart is ready for new adventures",
            "Take it one day at a time",
            "Good things come to those who move"
        ]
    }

    // Get a random message (but consistent for the current week)
    private var randomEmptyMessage: String {
        // Use week of year as seed for consistent message throughout the week
        let weekOfYear = Calendar.current.component(.weekOfYear, from: Date())
        let messageIndex = weekOfYear % emptyStateMessages.count
        return emptyStateMessages[messageIndex]
    }

    // Helper function to convert hex color to Color
    private func colorFromHex(_ hex: String) -> Color {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        r = (int >> 16) & 0xFF
        g = (int >> 8) & 0xFF
        b = int & 0xFF
        return Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }

    var body: some View {
        ZStack {
            let colorMapping: [(String, Color)] = selectedActivities.map { ($0.name, colorFromHex($0.color)) }

            Chart {
                ForEach(days) { day in
                    BarMark(
                        x: .value("Day", day.name),
                        y: .value("Minutes", day.minutes)
                    ).foregroundStyle(by: .value("Type", day.type))
                }
            }
            .chartForegroundStyleScale(domain: colorMapping.map { $0.0 }, range: colorMapping.map { $0.1 })
            
            // Empty State Overlay
            if !hasActivitiesThisWeek {
                VStack(spacing: 4) {
                    
                    Text(randomEmptyMessage)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(red: 0.961, green: 0.620, blue: 0.043).opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 8)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.031, green: 0.039, blue: 0.055))
//                        .overlay(
//                            RoundedRectangle(cornerRadius: 12)
//                                .stroke(.white.opacity(0.2), lineWidth: 1)
//                        )
                )
//                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            }
        }
    }
}



struct PieChartView: View {

    var current: Double // Value in miles (will be converted for display if metric)
    var goalRemaining: Double
    var color: Color

    /// Display value converted to user's preferred unit
    private var displayValue: Double {
        WidgetUnitHelper.convertFromMiles(current)
    }

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
                Text(String(format: "%.1f", displayValue)).font(.system( size: 10, weight: .heavy)).position(x: frame.midX, y: frame.midY)
            }
        }
    }
}

struct Provider: AppIntentTimelineProvider {
    typealias Entry = SimpleEntry
    typealias Intent = ConfigurationAppIntent

    // Default activities if none selected
    private var defaultActivities: [ActivityTypeEntity] {
        [
            ActivityTypeEntity(id: "run", name: "Run", color: "#F59E0B"),
            ActivityTypeEntity(id: "walk", name: "Walk", color: "#66CC66"),
            ActivityTypeEntity(id: "weight_training", name: "Weight Training", color: "#FFB300"),
            ActivityTypeEntity(id: "yoga", name: "Yoga", color: "#CC66CC")
        ]
    }

    // Default goals
    private let defaultWeeklyGoal: Double = 20.0
    private let defaultMonthlyGoal: Double = 80.0

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), miles: 0.0, monthlyMiles: 0.0, runs: 0, days: [], selectedActivities: defaultActivities, weeklyGoal: defaultWeeklyGoal, monthlyGoal: defaultMonthlyGoal, todaysCommitmentType: nil, todaysCommitmentFulfilled: false)
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        let activities = configuration.selectedActivities ?? defaultActivities
        return SimpleEntry(date: Date(), miles: 0.0, monthlyMiles: 0.0, runs: 0, days: [], selectedActivities: activities, weeklyGoal: defaultWeeklyGoal, monthlyGoal: defaultMonthlyGoal, todaysCommitmentType: nil, todaysCommitmentFulfilled: false)
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        var entries: [SimpleEntry] = []
        let currentDate = Date()
        let activities = configuration.selectedActivities ?? defaultActivities

        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.safeDate(byAdding: .hour, value: hourOffset, to: currentDate)
            var entry = SimpleEntry(date: entryDate, miles: 0.0, monthlyMiles: 0.0, runs: 0, days: [], selectedActivities: activities, weeklyGoal: defaultWeeklyGoal, monthlyGoal: defaultMonthlyGoal, todaysCommitmentType: nil, todaysCommitmentFulfilled: false)
            if let userDefaults = UserDefaults(suiteName: "group.com.jackrudelic.runawayios") {
                let commitmentType = userDefaults.string(forKey: "todays_commitment_type")
                let commitmentFulfilled = userDefaults.bool(forKey: "todays_commitment_fulfilled")
                let miles = userDefaults.double(forKey: "miles")
                let runs = userDefaults.integer(forKey: "runs")
                let monthlyMiles = userDefaults.double(forKey: "monthlyMiles")

                // Read customizable goals (with defaults)
                let weeklyGoal = userDefaults.double(forKey: "weekly_goal_miles")
                let monthlyGoal = userDefaults.double(forKey: "monthly_goal_miles")
                let finalWeeklyGoal = weeklyGoal > 0 ? weeklyGoal : defaultWeeklyGoal
                let finalMonthlyGoal = monthlyGoal > 0 ? monthlyGoal : defaultMonthlyGoal
                
                print("Miles: \(miles), Runs: \(runs), Monthly Miles: \(monthlyMiles)")
                
                let sunArray: Array<String> = userDefaults.stringArray(forKey: "sunArray") ?? []
                let monArray: Array<String> = userDefaults.stringArray(forKey: "monArray") ?? []
                let tuesArray: Array<String> = userDefaults.stringArray(forKey: "tueArray") ?? []
                let wednesArray: Array<String> = userDefaults.stringArray(forKey: "wedArray") ?? []
                let thursArray: Array<String> = userDefaults.stringArray(forKey: "thuArray") ?? []
                let friArray: Array<String> = userDefaults.stringArray(forKey: "friArray") ?? []
                let satArray: Array<String> = userDefaults.stringArray(forKey: "satArray") ?? []

                // Log received activity data from UserDefaults
                print("🔵 Widget: Received activity data from UserDefaults:")
                print("🔵   Sunday: \(sunArray.count) activities")
                print("🔵   Monday: \(monArray.count) activities")
                print("🔵   Tuesday: \(tuesArray.count) activities")
                print("🔵   Wednesday: \(wednesArray.count) activities")
                print("🔵   Thursday: \(thursArray.count) activities")
                print("🔵   Friday: \(friArray.count) activities")
                print("🔵   Saturday: \(satArray.count) activities")

                #if DEBUG
                // Log sample activity data for debugging
                if let sunSample = sunArray.first {
                    print("🔵   Sample Sunday activity: \(sunSample)")
                }
                if let monSample = monArray.first {
                    print("🔵   Sample Monday activity: \(monSample)")
                }
                #endif
                
                
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

                // Log processed activities
                print("🔵 Widget: Processed \(weekActivities.count) total activities for week")
                for (index, activity) in weekActivities.enumerated() {
                    print("🔵   Activity \(index + 1): \(activity.day) - \(activity.type) - \(activity.distance) mi - \(activity.time) min")
                }

                var daysData: [Day] = [
                    
                    .init(name: "Su", type: "Run", minutes: 0.0, miles: 0.0),
                    .init(name: "Mo", type: "Run", minutes: 0.0, miles: 0.0),
                    .init(name: "Tu", type: "Run", minutes: 0.0, miles: 0.0),
                    .init(name: "We", type: "Run", minutes: 0.0, miles: 0.0),
                    .init(name: "Th", type: "Run", minutes: 0.0, miles: 0.0),
                    .init(name: "Fr", type: "Run", minutes: 0.0, miles: 0.0),
                    .init(name: "Sa", type: "Run", minutes: 0.0, miles: 0.0)
                ]
                
                for act in weekActivities {
                    daysData.append(Day(name: act.day, type: act.type, minutes: act.time, miles: act.distance))
                }

                // Log final widget data that will be displayed
                print("🔵 Widget: Final daysData for display (\(daysData.count) items):")
                for day in daysData {
                    print("🔵   \(day.name): \(day.type) - \(day.minutes) min - \(day.miles) mi")
                }

                entry = SimpleEntry(date: entryDate, miles: miles, monthlyMiles: monthlyMiles, runs: runs, days: daysData, selectedActivities: activities, weeklyGoal: finalWeeklyGoal, monthlyGoal: finalMonthlyGoal, todaysCommitmentType: commitmentType, todaysCommitmentFulfilled: commitmentFulfilled)
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
    
    var locationName: String {
        if let userDefaults = UserDefaults(suiteName: "group.com.jackrudelic.runawayios") {
            return userDefaults.string(forKey: "currentLocation") ?? "Loading..."
        }
        return "Loading..."
    }
    
    /// Year total converted to preferred unit
    private var yearTotalDisplay: Double {
        WidgetUnitHelper.convertFromMiles(entry.miles)
    }

    var body: some View {
        VStack (alignment: .leading) {
            HStack(alignment: .bottom){
                Label(locationName, systemImage: "location.fill").font(.system(size: 13)).foregroundColor(.white)
                Spacer()
                Text("Runaway").font(.system(size: 16, weight: .heavy)).italic().foregroundColor(Color(red: 0.961, green: 0.620, blue: 0.043))
            }.padding(.bottom, 8)
            HStack(alignment: .top){
                BarChart(days: entry.days, selectedActivities: entry.selectedActivities)
            }
            HStack(alignment: .bottom){
                VStack(alignment: .leading){
                    Text("\(String(Calendar.current.component(.year, from: Date()))) \(WidgetUnitHelper.unitName):").font(.system(size: 14, weight: .semibold)).foregroundColor(.white).padding(.bottom,1)
                    Text(yearTotalDisplay.thousandsOfMiles).font(.custom("Futura-CondensedExtraBold", fixedSize: 40)).foregroundColor(Color(red: 0.961, green: 0.620, blue: 0.043)).tracking(-1)
                }.frame(minWidth: 140).padding(.bottom,8)
                Spacer()
                VStack{
                    PieChartView(current: weeklyMileage, goalRemaining: max(0, entry.weeklyGoal - weeklyMileage), color: Color(red: 0.961, green: 0.620, blue: 0.043)).padding(.bottom,2)
                    Text("Weekly \(WidgetUnitHelper.unitAbbreviation)").font(.system(size: 10, weight: .heavy)).foregroundColor(.white)
                }.padding(.bottom,8)
                VStack{
                    PieChartView(current: entry.monthlyMiles, goalRemaining: max(0, entry.monthlyGoal - entry.monthlyMiles), color: Color(red: 0.4, green: 0.8, blue: 0.4)).padding(.bottom,2)
                    Text("Monthly \(WidgetUnitHelper.unitAbbreviation)").font(.system(size: 10, weight: .heavy)).foregroundColor(.white)
                }.padding(.bottom,8)
            }.padding(.top, 16)
            HStack(alignment: .bottom){
                Spacer()
                Text("Last Updated:").font(.system(size: 9)).foregroundColor(.white.opacity(0.7))
                Text(entry.date, style: .date).font(.system(size: 9)).foregroundColor(.white.opacity(0.7))
                Text(entry.date, style: .time).font(.system(size: 9)).foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }
}

struct RunawayWidget: Widget {
    let kind: String = "RunawayWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                RunawayWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        LinearGradient(
                            colors: [
                                Color(red: 0.031, green: 0.039, blue: 0.055),
                                Color(red: 0.047, green: 0.059, blue: 0.078)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
            } else {
                RunawayWidgetEntryView(entry: entry)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.031, green: 0.039, blue: 0.055),
                                Color(red: 0.047, green: 0.059, blue: 0.078)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
        .configurationDisplayName("Runaway Widget")
        .description("Track your running progress with beautiful charts and stats.")
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
    let defaultActivities = [
        ActivityTypeEntity(id: "run", name: "Run", color: "#F59E0B"),
        ActivityTypeEntity(id: "walk", name: "Walk", color: "#66CC66"),
        ActivityTypeEntity(id: "weight_training", name: "Weight Training", color: "#FFB300"),
        ActivityTypeEntity(id: "yoga", name: "Yoga", color: "#CC66CC")
    ]
    SimpleEntry(date: .now, miles: 0.0, monthlyMiles: 0, runs: 0, days: [], selectedActivities: defaultActivities, weeklyGoal: 20.0, monthlyGoal: 80.0, todaysCommitmentType: nil, todaysCommitmentFulfilled: false)
    SimpleEntry(date: .now, miles: 0.0, monthlyMiles: 0, runs: 0, days: [], selectedActivities: defaultActivities, weeklyGoal: 20.0, monthlyGoal: 80.0, todaysCommitmentType: nil, todaysCommitmentFulfilled: false)
}
