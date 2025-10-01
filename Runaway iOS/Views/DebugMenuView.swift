//
//  DebugMenuView.swift
//  Runaway iOS
//
//  Created by Assistant on 9/28/25.
//

import SwiftUI

struct DebugMenuView: View {
    @StateObject private var realtimeService = RealtimeService.shared
    @State private var showingBackgroundMonitor = false
    
    var body: some View {
        List {
            Section("Realtime Services") {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Connection Status")
                            .font(.headline)
                        Text(realtimeService.isConnected ? "Connected" : "Disconnected")
                            .foregroundColor(realtimeService.isConnected ? .green : .red)
                    }
                    Spacer()
                    Circle()
                        .fill(realtimeService.isConnected ? .green : .red)
                        .frame(width: 12, height: 12)
                }
                
                HStack {
                    Text("Health Status")
                        .font(.headline)
                    Spacer()
                    Text(healthStatusText)
                        .foregroundColor(healthColor)
                }
                
                if let lastUpdate = realtimeService.lastUpdateTime {
                    HStack {
                        Text("Last Update")
                            .font(.headline)
                        Spacer()
                        Text(lastUpdate.formatted(.dateTime.hour().minute().second()))
                            .foregroundColor(.secondary)
                    }
                }
                
                Button("View Background Task Monitor") {
                    showingBackgroundMonitor = true
                }
                .foregroundColor(.blue)
            }
            
            Section("Quick Actions") {
                Button("Restart Realtime Connection") {
                    realtimeService.startRealtimeSubscription()
                }
                
                Button("Refresh Widget") {
                    realtimeService.refreshWidget()
                }
                
                Button("Force Data Refresh") {
                    Task {
                        await DataManager.shared.refreshAllData()
                    }
                }
            }
        }
        .navigationTitle("Debug Menu")
        .sheet(isPresented: $showingBackgroundMonitor) {
            BackgroundTaskMonitorView()
        }
    }
    
    private var healthStatusText: String {
        switch realtimeService.connectionHealth {
        case .healthy: return "Healthy"
        case .degraded: return "Degraded"
        case .disconnected: return "Disconnected"
        case .unknown: return "Unknown"
        }
    }
    
    private var healthColor: Color {
        switch realtimeService.connectionHealth {
        case .healthy: return .green
        case .degraded: return .orange
        case .disconnected: return .red
        case .unknown: return .gray
        }
    }
}

#Preview {
    NavigationView {
        DebugMenuView()
    }
}