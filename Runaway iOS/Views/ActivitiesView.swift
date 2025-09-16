import SwiftUI
import Foundation
import UIKit
import WidgetKit

struct ActivitiesView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var realtimeService: RealtimeService
    @State private var selectedActivity: LocalActivity?
    @State private var showingDetail = false
    @State private var showingRecording = false
    
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
            AppTheme.Colors.background.ignoresSafeArea()
            
            VStack {
                if dataManager.activities.isEmpty {
                    if dataManager.isLoadingActivities {
                        VStack(spacing: AppTheme.Spacing.md) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                            Text("Loading activities...")
                                .font(AppTheme.Typography.body)
                                .foregroundColor(AppTheme.Colors.secondaryText)
                        }
                    } else {
                        EmptyActivitiesView()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: AppTheme.Spacing.md) {
                            ForEach(dataManager.activities, id: \.id) { activity in
                                CardView(activity: convertToLocalActivity(activity)) {
                                    selectedActivity = convertToLocalActivity(activity)
                                    showingDetail = true
                                }
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
            
            // Floating Action Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        showingRecording = true
                    }) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(
                                LinearGradient(
                                    colors: [AppTheme.Colors.primary, AppTheme.Colors.primaryDark],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
            
            .sheet(isPresented: $showingDetail) {
                if let activity = selectedActivity {
                    NavigationView {
                        ActivityDetailView(activity: activity)
                    }
                }
            }
            .fullScreenCover(isPresented: $showingRecording) {
                PreRecordingView()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await refreshActivities()
                        }
                    }) {
                        Image(systemName: AppIcons.refresh)
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                    .disabled(dataManager.isLoadingActivities)
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
        ActivitiesView()
            .environmentObject(AuthManager.shared)
            .environmentObject(UserManager.shared)
            .environmentObject(DataManager.shared)
            .environmentObject(RealtimeService.shared)
    }
}
