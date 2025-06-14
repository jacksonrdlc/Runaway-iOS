import SwiftUI
import Foundation



struct ActivitiesView: View {
    @EnvironmentObject var authManager: AuthManager
    var activities: [Activity]
    
    private func convertToLocalActivity(_ activity: Activity) -> LocalActivity {
        return LocalActivity(
            id: activity.id,
            name: activity.name ?? "Unknown Activity",
            type: activity.type ?? "Unknown Type",
            summary_polyline: activity.summary_polyline ?? "",
            distance: activity.distance ?? 0.0,
            start_date: activity.start_date != nil ? Date(timeIntervalSince1970: activity.start_date!) : nil,
            elapsed_time: activity.elapsed_time ?? 0.0
        )
    }
    
    var body: some View {
        VStack{ 
            NavigationView {
                List {
                    ForEach(activities, id: \.id) { activity in
                        CardView(activity: convertToLocalActivity(activity))
                            .listRowBackground(
                                RoundedRectangle(cornerRadius: 5)
                                    .background(.clear)
                                    .foregroundColor(.black)
                                    .padding(
                                        EdgeInsets(
                                            top: 24,
                                            leading: 24,
                                            bottom: 8,
                                            trailing: 24
                                        )
                                    )
                            )
                    }
                }
                .refreshable {
                    print("Do your refresh work here")
                }
                .listStyle(.plain)
                .navigationTitle("Activities")
            }
        }
    }
}

struct EmptyView_Previews: PreviewProvider {
    static var previews: some View {
        ActivitiesView(activities: [])
            .environmentObject(AuthManager.shared)
    }
}
