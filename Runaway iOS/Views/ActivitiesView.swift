import SwiftUI
import Foundation
import UIKit
import WidgetKit

struct ActivitiesView: View {
    @Environment(UserSession.self) var userSession
    @Environment(DataManager.self) var dataManager
    @Environment(RealtimeService.self) var realtimeService
    @State private var selectedActivity: LocalActivity?
    @State private var activeFilter: String = "All"

    private let filterOptions = ["All", "Run", "Bike", "Strength", "Trail", "Swim"]

    private var filteredActivities: [Activity] {
        guard activeFilter != "All" else { return dataManager.activities }
        return dataManager.activities.filter { activity in
            let type = (activity.type ?? "").lowercased()
            switch activeFilter {
            case "Run":      return type.contains("run") && !type.contains("trail")
            case "Bike":     return type.contains("bike") || type.contains("ride") || type.contains("cycling")
            case "Strength": return type.contains("weight") || type.contains("workout") || type.contains("crossfit") || type.contains("yoga")
            case "Trail":    return type.contains("trail") || type.contains("hike")
            case "Swim":     return type.contains("swim")
            default:         return true
            }
        }
    }

    private var colors: (background: Color, textPrimary: Color, textSecondary: Color) {
        (AppTheme.Colors.adaptiveBackground, AppTheme.Colors.adaptiveTextPrimary, AppTheme.Colors.adaptiveTextSecondary)
    }

    private func convertToLocalActivity(_ activity: Activity) -> LocalActivity {
        return LocalActivity(
            id: activity.id,
            name: activity.name ?? "Unknown Activity",
            type: activity.type ?? "Unknown Type",
            summary_polyline: activity.summary_polyline ?? "",
            distance: activity.distance ?? 0.0,
            start_date: activity.start_date != nil ? Date(timeIntervalSince1970: activity.start_date ?? 0) : nil,
            elapsed_time: activity.elapsed_time ?? 0.0
        )
    }
    
    private func refreshActivities() async {
        await dataManager.refreshActivities()
    }
    
    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header ─────────────────────────────────────────────────
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        EyebrowLabel(text: "Log")
                        Text("Activities")
                            .font(AppTheme.Typography.largeTitle)
                            .foregroundColor(colors.textPrimary)
                    }
                    Spacer()
                    Button(action: { Task { await refreshActivities() } }) {
                        Image(systemName: AppIcons.refresh)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(Color(red: 0.10, green: 0.05, blue: 0))
                            .frame(width: 40, height: 40)
                            .background(AppTheme.Colors.warmAmber)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
                            .shadow(color: AppTheme.Colors.warmAmber.opacity(0.3), radius: 8, x: 0, y: 3)
                    }
                    .disabled(dataManager.isLoadingActivities)
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.top, AppTheme.Spacing.md)
                .padding(.bottom, AppTheme.Spacing.sm)

                // ── Filter chips ───────────────────────────────────────────
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppTheme.Spacing.xs) {
                        ForEach(filterOptions, id: \.self) { option in
                            FilterChip(label: option, isActive: activeFilter == option) {
                                activeFilter = option
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .padding(.vertical, AppTheme.Spacing.xs)
                }

                // ── List ───────────────────────────────────────────────────
                if dataManager.isLoadingActivities && dataManager.activities.isEmpty {
                    Spacer()
                    VStack(spacing: AppTheme.Spacing.md) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.accent))
                        Text("Loading activities...")
                            .font(AppTheme.Typography.body)
                            .foregroundColor(colors.textSecondary)
                    }
                    Spacer()
                } else if filteredActivities.isEmpty {
                    ScrollView {
                        VStack(spacing: AppTheme.Spacing.lg) {
                            CompactCommitmentCard()
                                .padding(.horizontal, AppTheme.Spacing.md)
                            EmptyActivitiesView()
                        }
                        .padding(.top, AppTheme.Spacing.md)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: AppTheme.Spacing.md) {
                            CompactCommitmentCard()
                                .padding(.horizontal, AppTheme.Spacing.md)

                            ForEach(filteredActivities.indices, id: \.self) { index in
                                let activity = filteredActivities[index]
                                let previousActivities = filteredActivities.dropFirst(index + 1)
                                    .map { convertToLocalActivity($0) }
                                CardView(
                                    activity: convertToLocalActivity(activity),
                                    previousActivities: previousActivities,
                                    onTap: { selectedActivity = convertToLocalActivity(activity) }
                                )
                                .padding(.horizontal, AppTheme.Spacing.md)
                            }
                        }
                        .padding(.top, AppTheme.Spacing.md)
                    }
                    .refreshable { await refreshActivities() }
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(item: $selectedActivity) { activity in
            NavigationView {
                ActivityDetailView(activity: activity)
            }
        }
    }
}
    


// MARK: - Empty Activities View
struct EmptyActivitiesView: View {
    private var colors: (textPrimary: Color, textSecondary: Color) {
        (AppTheme.Colors.adaptiveTextPrimary, AppTheme.Colors.adaptiveTextSecondary)
    }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Image(systemName: "figure.run.circle")
                .font(.system(size: 80))
                .foregroundColor(AppTheme.Colors.accent)

            VStack(spacing: AppTheme.Spacing.sm) {
                Text("No Activities Yet")
                    .font(AppTheme.Typography.title)
                    .foregroundColor(colors.textPrimary)

                Text("Your running activities will appear here once you start tracking your workouts.")
                    .font(AppTheme.Typography.body)
                    .foregroundColor(colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(AppTheme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ActivitiesView_Previews: PreviewProvider {
    static var previews: some View {
        ActivitiesView()
            .environment(UserSession.shared)
            .environment(DataManager.shared)
            .environment(RealtimeService.shared)
    }
}
