//
//  CommitmentWidget.swift
//  RunawayWidget
//
//  Standalone widget for viewing and setting today's daily commitment.
//  Supports small and medium sizes.
//

import WidgetKit
import SwiftUI

// MARK: - Entry

struct CommitmentEntry: TimelineEntry {
    let date: Date
    let commitmentType: String?
    let isFulfilled: Bool
}

// MARK: - Provider

struct CommitmentProvider: TimelineProvider {
    func placeholder(in context: Context) -> CommitmentEntry {
        CommitmentEntry(date: Date(), commitmentType: nil, isFulfilled: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (CommitmentEntry) -> Void) {
        completion(readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CommitmentEntry>) -> Void) {
        let entry = readEntry()
        let nextHour = Calendar.current.safeDate(byAdding: .hour, value: 1, to: Date())
        completion(Timeline(entries: [entry], policy: .after(nextHour)))
    }

    private func readEntry() -> CommitmentEntry {
        let defaults = UserDefaults(suiteName: "group.com.jackrudelic.runawayios")
        let type = defaults?.string(forKey: "todays_commitment_type")
        let fulfilled = defaults?.bool(forKey: "todays_commitment_fulfilled") ?? false
        return CommitmentEntry(date: Date(), commitmentType: type, isFulfilled: fulfilled)
    }
}

// MARK: - Activity Color

private extension CommitmentActivityAppEnum {
    var color: Color {
        switch self {
        case .run:     return Color(red: 0.2, green: 0.6, blue: 1.0)
        case .walk:    return Color(red: 0.35, green: 0.8, blue: 0.45)
        case .workout: return Color(red: 1.0, green: 0.6, blue: 0.2)
        case .yoga:    return Color(red: 0.75, green: 0.5, blue: 1.0)
        }
    }

    static func from(_ rawValue: String) -> CommitmentActivityAppEnum? {
        CommitmentActivityAppEnum.allCases.first { $0.rawValue.lowercased() == rawValue.lowercased() }
    }
}

extension CommitmentActivityAppEnum: CaseIterable {
    public static var allCases: [CommitmentActivityAppEnum] { [.run, .walk, .workout, .yoga] }
}

// MARK: - Entry View

struct CommitmentWidgetEntryView: View {
    let entry: CommitmentEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("COMMIT TODAY")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.35))
                    .tracking(0.8)
                Spacer()
                Text("Runaway")
                    .font(.system(size: 16, weight: .heavy))
                    .italic()
                    .foregroundColor(.white)
            }
            .padding(.bottom, 10)

            if let type = entry.commitmentType {
                CommitmentStatusView(type: type, isFulfilled: entry.isFulfilled)
            } else {
                CommitmentPickerView(family: family)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
    }
}

// MARK: - Status View (commitment already set)

private struct CommitmentStatusView: View {
    let type: String
    let isFulfilled: Bool

    private var matched: CommitmentActivityAppEnum? {
        CommitmentActivityAppEnum.from(type)
    }

    private var accentColor: Color {
        matched?.color ?? .white
    }

    private var iconName: String {
        matched?.iconName ?? "checkmark.circle"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundColor(isFulfilled ? .green : accentColor)

                VStack(alignment: .leading, spacing: 3) {
                    Text(type)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(isFulfilled ? "Done for today" : "Not yet — go get it")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isFulfilled ? .green : .white.opacity(0.45))
                }

                Spacer()

                Image(systemName: isFulfilled ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.system(size: 22))
                    .foregroundColor(isFulfilled ? .green : .white.opacity(0.2))
            }
        }
    }
}

// MARK: - Picker View (no commitment set)

private struct CommitmentPickerView: View {
    let family: WidgetFamily

    var body: some View {
        if family == .systemSmall {
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 4
            ) {
                ForEach(CommitmentActivityAppEnum.allCases, id: \.rawValue) { activity in
                    CommitmentButton(activity: activity, compact: true)
                }
            }
        } else {
            HStack(spacing: 0) {
                ForEach(CommitmentActivityAppEnum.allCases, id: \.rawValue) { activity in
                    CommitmentButton(activity: activity, compact: false)
                }
            }
        }
    }
}

// MARK: - Individual Commitment Button

private struct CommitmentButton: View {
    let activity: CommitmentActivityAppEnum
    let compact: Bool

    var body: some View {
        Button(intent: SetDailyCommitmentIntent(activityType: activity)) {
            VStack(spacing: compact ? 4 : 6) {
                Image(systemName: activity.iconName)
                    .font(.system(size: compact ? 24 : 28, weight: .medium))
                    .foregroundColor(activity.color)
                Text(activity.displayName)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
            }
            .frame(maxWidth: .infinity, minHeight: compact ? 52 : 60)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Widget

struct CommitmentWidget: Widget {
    let kind: String = "CommitmentWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CommitmentProvider()) { entry in
            if #available(iOS 17.0, *) {
                CommitmentWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        LinearGradient(
                            colors: [
                                Color(red: 0.02, green: 0.02, blue: 0.08),
                                Color(red: 0.06, green: 0.06, blue: 0.14)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
            } else {
                CommitmentWidgetEntryView(entry: entry)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(red: 0.02, green: 0.02, blue: 0.08))
            }
        }
        .configurationDisplayName("Daily Commitment")
        .description("Set and track your daily movement commitment.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview

#Preview(as: .systemMedium) {
    CommitmentWidget()
} timeline: {
    CommitmentEntry(date: .now, commitmentType: nil, isFulfilled: false)
    CommitmentEntry(date: .now, commitmentType: "Run", isFulfilled: false)
    CommitmentEntry(date: .now, commitmentType: "Run", isFulfilled: true)
}
