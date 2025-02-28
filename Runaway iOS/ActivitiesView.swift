//
//  Activities.swift
//  RunawayUI
//
//  Created by Jack Rudelic on 7/17/24.
//

import SwiftUI
import SwiftyJSON
import Polyline
import MapKit

struct RAActivity: Codable {
    var day : String?
    var type : String?
    var distance : Double?
    var time : Double?
}

struct ActivitiesView: View {
    let activities: [Activity]
//    @State private var isActivitiesDataReady = false

    var body: some View {
        
        NavigationView {
            List {
                ForEach(activities, id: \.id) { activity in
                    
//                    CardView(stravaMap: activity.map, name: activity.name, description: activity.detail, startDate: activity.startDate, type: activity.type)
//                        .listRowSeparator(.hidden)
//                        .listRowBackground(
//                            RoundedRectangle(cornerRadius: 5)
//                                .background(.clear)
//                                .foregroundColor(.black)
//                                .padding(
//                                    EdgeInsets(
//                                        top: 24,
//                                        leading: 24,
//                                        bottom: 8,
//                                        trailing: 24
//                                    )
//                                )
//                        )
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

extension Calendar {
    static let gregorian = Calendar(identifier: .gregorian)
}

extension Date {
    var startOfDay: Date {
        return Calendar.current.startOfDay(for: self)
    }
    
    func startOfWeek(using calendar: Calendar = .gregorian) -> Date {
        calendar.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: self).date!
    }
    
    var startOfMonth: Date {
        
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month], from: self)
        
        return  calendar.date(from: components)!
    }
    
    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay)!
    }
    
    var endOfMonth: Date {
        var components = DateComponents()
        components.month = 1
        components.second = -1
        return Calendar(identifier: .gregorian).date(byAdding: components, to: startOfMonth)!
    }
    
    func isMonday() -> Bool {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.weekday], from: self)
        return components.weekday == 2
    }
    
    var dayOfTheWeek: String {
        let dayNumber = Calendar.current.component(.weekday, from: self)
        // day number starts from 1 but array count from 0
        return daysOfTheWeek[dayNumber - 1]
    }
    
    private var daysOfTheWeek: [String] {
        return  ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    }
}
