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
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CommitmentEntry>) -> Void) {
        let current = entry()
        // Refresh at top of next hour so fulfilled state stays current
        let nextHour = Calendar.current.safeDate(byAdding: .hour, value: 1, to: Date())
        completion(Timeline(entries: [current], policy: .after(nextHour)))
    }

    private func entry() -> CommitmentEntry {
        let defaults = UserDefaults(suiteName: "group.com.jackrudelic.runawayios")
        let type = defaults?.string(forKey: "todays_commitment_type")
        let fulfilled = defaults?.bool(forKey: "todays_commitment_fulfilled") ?? false
        return CommitmentEntry(date: Date(), commitmentType: type, isFulfilled: fulfilled)
    }
}

// MARK: - Entry View

struct CommitmentWidgetEntryView: View {
    let entry: CommitmentEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.02, blue: 0.08),
                    Color(red: 0.05, green: 0.05, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Text("Today's Commitment")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "figure.run.circle")
                        .font(.system(size: 16))
                        .foregroundColor(.green.opacity(0.8))
                }

                if let type = entry.commitmentType {
                    // Commitment is set — show status
                    CommitmentStatusView(type: type, isFulfilled: entry.isFulfilled)
                } else {
                    // No commitment — show activity picker
                    CommitmentPickerView(family: family)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
        }
    }
}

// MARK: - Status View (commitment already set)

private struct CommitmentStatusView: View {
    let type: String
    let isFulfilled: Bool

    private var icon: String {
        switch type.lowercased() {
        case "run": return "figure.run"
        case "walk": return "figure.walk"
        case "workout": return "dumbbell"
        case "yoga": return "figure.yoga"
        default: return "checkmark.circle"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(isFulfilled ? .green : .white.opacity(0.9))

                VStack(alignment: .leading, spacing: 2) {
                    Text(type.capitalized)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    Text(isFulfilled ? "Completed!" : "Not yet done")
                        .font(.system(size: 12))
                        .foregroundColor(isFulfilled ? .green : .white.opacity(0.5))
                }

                Spacer()

                Image(systemName: isFulfilled ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isFulfilled ? .green : .white.opacity(0.3))
            }
        }
    }
}

// MARK: - Picker View (no commitment set)

private struct CommitmentPickerView: View {
    let family: WidgetFamily

    private let activities: [CommitmentActivityAppEnum] = [.run, .walk, .workout, .yoga]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What's your move today?")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))

            if family == .systemSmall {
                // 2x2 grid for small widget
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(activities, id: \.rawValue) { activity in
                        CommitmentButton(activity: activity)
                    }
                }
            } else {
                // Single row for medium widget
                HStack(spacing: 10) {
                    ForEach(activities, id: \.rawValue) { activity in
                        CommitmentButton(activity: activity)
                    }
                }
            }
        }
    }
}

// MARK: - Individual Commitment Button

private struct CommitmentButton: View {
    let activity: CommitmentActivityAppEnum

    var body: some View {
        Button(intent: SetDailyCommitmentIntent(activityType: activity)) {
            VStack(spacing: 4) {
                Image(systemName: activity.iconName)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
                Text(activity.displayName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.08))
            .cornerRadius(10)
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
                                Color(red: 0.05, green: 0.05, blue: 0.12)
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

#Preview(as: .systemSmall) {
    CommitmentWidget()
} timeline: {
    CommitmentEntry(date: .now, commitmentType: nil, isFulfilled: false)
    CommitmentEntry(date: .now, commitmentType: "run", isFulfilled: false)
    CommitmentEntry(date: .now, commitmentType: "run", isFulfilled: true)
}
