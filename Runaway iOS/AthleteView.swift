//
//  Profile.swift
//  RunawayUI
//
//  Created by Jack Rudelic on 7/17/24.
//

import Foundation
import SwiftUI
import Charts

struct ActivityDay: Identifiable {
    var id = UUID()
    var date: Date = Date()
    var minutes: Double = 0
}

struct AthleteView: View {
    let athlete: Athlete
    let stats: AthleteStats
    let activityDays: [ActivityDay]
    
    
    @State var userImage: String?
    @State var name: String?
    @State var runs: String? = ""
    @State var miles: String? = ""
    @State var minutes: String? = ""
    //    @State private var activities: [Activity] = []
    
    @State private var isAthleteDataReady = false
    @State private var isActivitiesDataReady = false
    
    
    
    var body: some View {
        VStack {
            HeaderBanner(backgroundImage: athlete.profile?.absoluteString)
                .padding(.init(top: 0, leading: 0, bottom: 16, trailing: 0))
            VStack {
                Text(athlete.firstname! + " " + athlete.lastname!)
                    .font(.title).bold()
                    .padding()
                
                Chart(activityDays, id: \.id) {
                    BarMark(
                        x: .value("Day", $0.date),
                        y: .value("Minutes", $0.minutes / 60)
                    )
                    .foregroundStyle(.green)
                }
                
                Text(runs!)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                Text(miles!)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                Text(minutes!)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .onAppear{
            setStats()
        }
    }
}

extension AthleteView {
    func setStats() {
        if let userDefaults = UserDefaults(suiteName: "group.com.jackrudelic.runawayui") {
            if let runsInt = stats.allRunTotals?.count {
                self.runs = String(runsInt)
                userDefaults.set(runsInt, forKey: "runs")
            }
            if let milesInt = stats.allRunTotals?.distance {
                self.miles = String(milesInt * Double(0.00062137))
                userDefaults.set(milesInt, forKey: "miles")
            }
            if let minutesInt = stats.allRunTotals?.elapsedTime {
                self.minutes = String(minutesInt)
                userDefaults.set(minutesInt, forKey: "minutes")
            }
        }
        
    }
}
