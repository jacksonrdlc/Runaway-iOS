import SwiftUI
import Foundation

struct ActivitiesView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var userManager: UserManager
    @Binding var activities: [Activity]
    @State private var isRefreshing = false
    
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
    
    private func fetchActivities() async {
        guard let userId = userManager.userId else {
            print("No user ID available")
            return
        }
        
        do {
            let fetchedActivities = try await ActivityService.getAllActivitiesByUser(userId: userId)
            DispatchQueue.main.async {
                self.activities = fetchedActivities
                self.isRefreshing = false
            }
        } catch {
            print("Error fetching activities: \(error)")
            DispatchQueue.main.async {
                self.isRefreshing = false
            }
        }
    }
    
    var body: some View {
        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()
            
            VStack {
                if activities.isEmpty {
                    EmptyActivitiesView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: AppTheme.Spacing.md) {
                            ForEach(activities, id: \.id) { activity in
                                CardView(activity: convertToLocalActivity(activity))
                                    .padding(.horizontal, AppTheme.Spacing.md)
                            }
                        }
                        .padding(.top, AppTheme.Spacing.md)
                    }
                    .refreshable {
                        isRefreshing = true
                        await fetchActivities()
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            isRefreshing = true
                            await fetchActivities()
                        }
                    }) {
                        Image(systemName: AppIcons.refresh)
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                    .disabled(isRefreshing)
                }
            }
        }
    }
}
    


// MARK: - Empty Activities View
struct EmptyActivitiesView: View {
    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Image(systemName: "figure.run.circle")
                .font(.system(size: 80))
                .foregroundColor(AppTheme.Colors.primary)
            
            VStack(spacing: AppTheme.Spacing.sm) {
                Text("No Activities Yet")
                    .font(AppTheme.Typography.title)
                    .foregroundColor(AppTheme.Colors.primaryText)
                
                Text("Your running activities will appear here once you start tracking your workouts.")
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(AppTheme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ActivitiesView_Previews: PreviewProvider {
    static var previews: some View {
        ActivitiesView(activities: .constant([]))
            .environmentObject(AuthManager.shared)
            .environmentObject(UserManager.shared)
    }
}
