import WidgetKit
import SwiftUI
import Charts
import AppIntents

struct WidgetTheme {
    static let background = Color(red: 0.031, green: 0.039, blue: 0.055)
    static let accent = Color(red: 0.961, green: 0.620, blue: 0.043)
    static let secondary = Color(white: 0.6)
}

struct Day: Identifiable {
    var name: String
    var type: String
    var minutes: Double = 0
    var miles: Double = 0
    var id = UUID()
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

    private var hasActivitiesThisWeek: Bool {
        days.contains { $0.minutes > 0 }
    }

    private func colorFromHex(_ hex: String) -> Color {
        let hexString = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }

    var body: some View {
        ZStack {
            let colorMapping: [(String, Color)] = selectedActivities.map { ($0.name, colorFromHex($0.color)) }

            Chart {
                ForEach(days) { day in
                    BarMark(
                        x: .value("Day", day.name),
                        y: .value("Minutes", day.minutes)
                    )
                    .foregroundStyle(by: .value("Type", day.type))
                    .cornerRadius(2)
                }
            }
            .chartForegroundStyleScale(domain: colorMapping.map { $0.0 }, range: colorMapping.map { $0.1 })
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisValueLabel().foregroundStyle(WidgetTheme.secondary)
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                }
            }
            .chartLegend(.hidden)
            
            if !hasActivitiesThisWeek {
                Text("Twin is waiting for data...")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(WidgetTheme.accent.opacity(0.8))
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 8).fill(WidgetTheme.background))
            }
        }
    }
}

struct MiniProgressView: View {
    var current: Double
    var goal: Double
    var label: String
    var color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.05), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: max(0.01, min(current / max(1.0, goal), 1.0)))
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 0) {
                    Text(String(format: "%.0f", current))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
            }
            .frame(width: 44, height: 44)
            
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(WidgetTheme.secondary)
                .tracking(0.5)
        }
    }
}

struct RunawayWidgetEntryView : View {
    var entry: SimpleEntry
    @Environment(\.widgetFamily) var family
    
    var weeklyMileage: Double {
        entry.days.reduce(0) { $0 + $1.miles }
    }

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium, .systemLarge:
            largeView
        default:
            smallView
        }
    }
    
    private var smallView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(WidgetTheme.accent)
                Spacer()
                Text("RUNAWAY").font(.system(size: 10, weight: .heavy)).italic().foregroundColor(WidgetTheme.accent)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "%.1f", weeklyMileage))
                    .font(.system(size: 32, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
                Text("MILES THIS WEEK")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(WidgetTheme.secondary)
            }
            
            Spacer()
            
            HStack {
                Capsule()
                    .fill(WidgetTheme.accent.opacity(0.1))
                    .frame(height: 4)
                    .overlay(
                        GeometryReader { geo in
                            Capsule()
                                .fill(WidgetTheme.accent)
                                .frame(width: geo.size.width * min(weeklyMileage / max(1.0, entry.weeklyGoal), 1.0))
                        }
                    )
            }
        }
        .padding(16)
    }

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ACTIVITY INTENSITY")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(WidgetTheme.secondary)
                        .tracking(1.0)
                    
                    BarChart(days: entry.days, selectedActivities: entry.selectedActivities)
                        .frame(height: 80)
                }
            }
            .padding(.bottom, 20)
            
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(Calendar.current.component(.year, from: Date())))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(WidgetTheme.secondary)
                    
                    Text(String(format: "%.0f", entry.miles))
                        .font(.system(size: 40, weight: .heavy, design: .monospaced))
                        .foregroundColor(WidgetTheme.accent)
                    
                    Text("TOTAL MILES")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(WidgetTheme.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    MiniProgressView(current: weeklyMileage, goal: entry.weeklyGoal, label: "WEEKLY", color: WidgetTheme.accent)
                    MiniProgressView(current: entry.monthlyMiles, goal: entry.monthlyGoal, label: "MONTHLY", color: .green)
                }
            }
        }
        .padding(16)
    }
}

struct Provider: AppIntentTimelineProvider {
    typealias Entry = SimpleEntry
    typealias Intent = ConfigurationAppIntent

    private var defaultActivities: [ActivityTypeEntity] {
        [
            ActivityTypeEntity(id: "run", name: "Run", color: "#F59E0B"),
            ActivityTypeEntity(id: "walk", name: "Walk", color: "#66CC66"),
            ActivityTypeEntity(id: "weight_training", name: "Weight Training", color: "#FFB300")
        ]
    }

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), miles: 1242.5, monthlyMiles: 42.8, runs: 12, days: [], selectedActivities: defaultActivities, weeklyGoal: 20.0, monthlyGoal: 100.0, todaysCommitmentType: nil, todaysCommitmentFulfilled: false)
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        let activities = configuration.selectedActivities ?? defaultActivities
        return SimpleEntry(date: Date(), miles: 1242.5, monthlyMiles: 42.8, runs: 12, days: [], selectedActivities: activities, weeklyGoal: 20.0, monthlyGoal: 100.0, todaysCommitmentType: nil, todaysCommitmentFulfilled: false)
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let activities = configuration.selectedActivities ?? defaultActivities
        let userDefaults = UserDefaults(suiteName: "group.com.jackrudelic.runawayios")
        
        let entry = SimpleEntry(
            date: Date(),
            miles: userDefaults?.double(forKey: "miles") ?? 0,
            monthlyMiles: userDefaults?.double(forKey: "monthlyMiles") ?? 0,
            runs: userDefaults?.integer(forKey: "runs") ?? 0,
            days: [], 
            selectedActivities: activities,
            weeklyGoal: userDefaults?.double(forKey: "weekly_goal_miles") ?? 20,
            monthlyGoal: userDefaults?.double(forKey: "monthly_goal_miles") ?? 100,
            todaysCommitmentType: userDefaults?.string(forKey: "todays_commitment_type"),
            todaysCommitmentFulfilled: userDefaults?.bool(forKey: "todays_commitment_fulfilled") ?? false
        )
        
        return Timeline(entries: [entry], policy: .atEnd)
    }
}

struct RunawayWidget: Widget {
    let kind: String = "RunawayWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            RunawayWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetTheme.background
                }
        }
        .configurationDisplayName("Runaway Intelligence")
        .description("Tactical training insights on your home screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
