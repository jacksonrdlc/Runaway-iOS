import SwiftUI
import Foundation
import UIKit
import WidgetKit

struct ActivitiesView: View {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var realtimeService: RealtimeService
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedActivity: LocalActivity?

    private var colors: (background: Color, textPrimary: Color, textSecondary: Color) {
        if themeManager.isDarkMode {
            return (AppTheme.Colors.DarkMode.background, AppTheme.Colors.DarkMode.textPrimary, AppTheme.Colors.DarkMode.textSecondary)
        } else {
            return (AppTheme.Colors.LightMode.background, AppTheme.Colors.LightMode.textPrimary, AppTheme.Colors.LightMode.textSecondary)
        }
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

            VStack {
                if dataManager.activities.isEmpty {
                    if dataManager.isLoadingActivities {
                        VStack(spacing: AppTheme.Spacing.md) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.accent))
                            Text("Loading activities...")
                                .font(AppTheme.Typography.body)
                                .foregroundColor(colors.textSecondary)
                        }
                    } else {
                        ScrollView {
                            VStack(spacing: AppTheme.Spacing.lg) {
                                // Compact Commitment Card
                                CompactCommitmentCard()
                                    .padding(.horizontal, AppTheme.Spacing.md)

                                // Empty state
                                EmptyActivitiesView()
                            }
                            .padding(.top, AppTheme.Spacing.md)
                        }
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: AppTheme.Spacing.md) {
                            // Compact Commitment Card
                            CompactCommitmentCard()
                                .padding(.horizontal, AppTheme.Spacing.md)

                            // Activities List
                            ForEach(dataManager.activities.indices, id: \.self) { index in
                                let activity = dataManager.activities[index]
                                let previousActivities = dataManager.activities.dropFirst(index + 1)
                                    .map { convertToLocalActivity($0) }

                                CardView(
                                    activity: convertToLocalActivity(activity),
                                    previousActivities: previousActivities,
                                    onTap: {
                                        selectedActivity = convertToLocalActivity(activity)
                                    }
                                )
                                .padding(.horizontal, AppTheme.Spacing.md)
                            }
                        }
                        .padding(.top, AppTheme.Spacing.md)
                    }
                    .refreshable {
                        await refreshActivities()
                    }
                }
            }

            .sheet(item: $selectedActivity) { activity in
                NavigationView {
                    ActivityDetailView(activity: activity)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await refreshActivities()
                        }
                    }) {
                        Image(systemName: AppIcons.refresh)
                            .foregroundColor(AppTheme.Colors.accent)
                    }
                    .disabled(dataManager.isLoadingActivities)
                }
            }
        }
    }
}
    


// MARK: - Empty Activities View
struct EmptyActivitiesView: View {
    private var colors: (textPrimary: Color, textSecondary: Color) {
        if ThemeManager.shared.isDarkMode {
            return (AppTheme.Colors.DarkMode.textPrimary, AppTheme.Colors.DarkMode.textSecondary)
        } else {
            return (ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary, ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
        }
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
            .environmentObject(UserSession.shared)
            .environmentObject(DataManager.shared)
            .environmentObject(RealtimeService.shared)
    }
}
