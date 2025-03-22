import SwiftUI
import Foundation

// Create simplified card view
struct LocalCardView: View {
    let activity: LocalActivity
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(activity.name ?? "Unknown Activity")
                .font(.headline)
            
            HStack {
                Text(activity.type ?? "Unknown Type")
                    .font(.subheadline)
                
                Spacer()
                
                if let distance = activity.distance {
                    Text(String(format: "%.2f km", distance * 0.001))
                        .font(.subheadline)
                }
                
                if let time = activity.elapsed_time {
                    Text(formatTime(seconds: time))
                        .font(.subheadline)
                }
            }
        }
        .padding()
    }
    
    private func formatTime(seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct ActivitiesView: View {
    @EnvironmentObject var authManager: AuthManager
    var activities: [Activity]
    
    private func convertToLocalActivity(_ activity: Activity) -> LocalActivity {
        return LocalActivity(
            id: activity.id,
            name: activity.name,
            type: activity.type,
            distance: activity.distance,
            start_date: activity.start_date.map { Int($0) },
            elapsed_time: activity.elapsed_time
        )
    }
    
    var body: some View {
        VStack{ 
            NavigationView {
                List {
                    ForEach(activities, id: \.id) { activity in
                        LocalCardView(activity: convertToLocalActivity(activity))
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
