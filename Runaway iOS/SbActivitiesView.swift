import SwiftUI

struct SbActivitiesView: View {
    var activities: [SbActivity]
    
    var body: some View {
        
        NavigationView {
            List {
                ForEach(activities, id: \.id) { activity in
                    
                    CardView(activity: activity)
                        .listRowSeparator(.hidden)
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

struct EmptyView_Previews: PreviewProvider {
    static var previews: some View {
        SbActivitiesView(activities: [])
    }
}
