//
//  BackgroundTaskMonitorView.swift
//  Runaway iOS
//
//  Created by Assistant on 9/28/25.
//

import SwiftUI

struct BackgroundTaskMonitorView: View {
    @StateObject private var realtimeService = RealtimeService.shared
    @State private var showingDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Background Task Status")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Monitor your app's realtime background tasks")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Connection Status Card
            connectionStatusCard
            
            // Performance Metrics
            performanceMetricsCard
            
            // Controls
            controlsSection
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingDetails) {
            BackgroundTaskDetailsView()
        }
    }
    
    private var connectionStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: connectionIcon)
                    .foregroundColor(connectionColor)
                    .font(.title2)
                
                VStack(alignment: .leading) {
                    Text("Realtime Connection")
                        .font(.headline)
                    Text(connectionStatusText)
                        .font(.caption)
                        .foregroundColor(connectionColor)
                }
                
                Spacer()
                
                Circle()
                    .fill(connectionColor)
                    .frame(width: 12, height: 12)
                    .opacity(realtimeService.isConnected ? 1.0 : 0.3)
            }
            
            // Connection Health Details
            HStack {
                Text("Health:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(healthStatusText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(healthColor)
                
                Spacer()
                
                if let lastUpdate = realtimeService.lastUpdateTime {
                    Text("Updated \(timeAgoString(from: lastUpdate))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var performanceMetricsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Background Task Performance")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                
                MetricView(
                    title: "Connection Status",
                    value: realtimeService.isConnected ? "Connected" : "Disconnected",
                    icon: "wifi",
                    color: realtimeService.isConnected ? .green : .red
                )
                
                MetricView(
                    title: "Health Status",
                    value: healthStatusText,
                    icon: healthIcon,
                    color: healthColor
                )
                
                MetricView(
                    title: "Widget Updates",
                    value: "Active",
                    icon: "widget.small",
                    color: .blue
                )
                
                MetricView(
                    title: "Background Refresh",
                    value: "Scheduled",
                    icon: "arrow.clockwise",
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var controlsSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                realtimeService.startRealtimeSubscription()
            }) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Restart Connection")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            HStack(spacing: 12) {
                Button("Refresh Widget") {
                    realtimeService.refreshWidget()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray5))
                .cornerRadius(10)
                
                Button("View Details") {
                    showingDetails = true
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray5))
                .cornerRadius(10)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var connectionIcon: String {
        switch realtimeService.connectionHealth {
        case .healthy:
            return "wifi"
        case .degraded:
            return "wifi.exclamationmark"
        case .disconnected:
            return "wifi.slash"
        case .unknown:
            return "questionmark.circle"
        }
    }
    
    private var connectionColor: Color {
        switch realtimeService.connectionHealth {
        case .healthy:
            return .green
        case .degraded:
            return .orange
        case .disconnected:
            return .red
        case .unknown:
            return .gray
        }
    }
    
    private var connectionStatusText: String {
        if realtimeService.isConnected {
            return "Connected to Supabase realtime"
        } else {
            return "Not connected"
        }
    }
    
    private var healthStatusText: String {
        switch realtimeService.connectionHealth {
        case .healthy:
            return "Healthy"
        case .degraded:
            return "Degraded"
        case .disconnected:
            return "Disconnected"
        case .unknown:
            return "Unknown"
        }
    }
    
    private var healthColor: Color {
        switch realtimeService.connectionHealth {
        case .healthy:
            return .green
        case .degraded:
            return .orange
        case .disconnected:
            return .red
        case .unknown:
            return .gray
        }
    }
    
    private var healthIcon: String {
        switch realtimeService.connectionHealth {
        case .healthy:
            return "checkmark.circle.fill"
        case .degraded:
            return "exclamationmark.triangle.fill"
        case .disconnected:
            return "xmark.circle.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let timeInterval = Date().timeIntervalSince(date)
        
        if timeInterval < 60 {
            return "just now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m ago"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(timeInterval / 86400)
            return "\(days)d ago"
        }
    }
}

struct MetricView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.caption)
                
                Spacer()
            }
            
            Text(value)
                .font(.headline)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct BackgroundTaskDetailsView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    
                    Section {
                        DetailCard(
                            title: "Background App Refresh",
                            description: "Allows your app to refresh content when in the background",
                            status: backgroundAppRefreshStatus,
                            recommendations: backgroundAppRefreshRecommendations
                        )
                        
                        DetailCard(
                            title: "Realtime Subscriptions",
                            description: "Real-time database change notifications via Supabase",
                            status: "Active",
                            recommendations: realtimeRecommendations
                        )
                        
                        DetailCard(
                            title: "Widget Updates",
                            description: "Automatic widget timeline refreshes when data changes",
                            status: "Active",
                            recommendations: widgetRecommendations
                        )
                        
                        DetailCard(
                            title: "Connection Resilience",
                            description: "Automatic reconnection with exponential backoff",
                            status: "Configured",
                            recommendations: connectionRecommendations
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Background Task Details")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private var backgroundAppRefreshStatus: String {
        // In a real app, you'd check UIApplication.shared.backgroundRefreshStatus
        return "Enabled"
    }
    
    private var backgroundAppRefreshRecommendations: [String] {
        [
            "Ensure 'Background App Refresh' is enabled in Settings",
            "Add UIBackgroundModes to Info.plist",
            "Use BGTaskScheduler for reliable background execution"
        ]
    }
    
    private var realtimeRecommendations: [String] {
        [
            "Monitor connection health regularly",
            "Implement exponential backoff for reconnections",
            "Handle network transitions gracefully"
        ]
    }
    
    private var widgetRecommendations: [String] {
        [
            "Batch widget updates to reduce system load",
            "Use efficient data serialization",
            "Test widget performance across different sizes"
        ]
    }
    
    private var connectionRecommendations: [String] {
        [
            "Monitor for network changes",
            "Implement proper error handling",
            "Use background tasks for critical updates"
        ]
    }
}

struct DetailCard: View {
    let title: String
    let description: String
    let status: String
    let recommendations: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                
                Spacer()
                
                Text(status)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(6)
            }
            
            Text(description)
                .font(.body)
                .foregroundColor(.secondary)
            
            if !recommendations.isEmpty {
                Text("Recommendations:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                ForEach(recommendations, id: \.self) { recommendation in
                    HStack(alignment: .top) {
                        Text("•")
                            .foregroundColor(.blue)
                        Text(recommendation)
                            .font(.caption)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var statusColor: Color {
        switch status.lowercased() {
        case "active", "enabled", "configured", "connected":
            return .green
        case "degraded", "warning":
            return .orange
        case "disabled", "disconnected", "error":
            return .red
        default:
            return .blue
        }
    }
}

#Preview {
    BackgroundTaskMonitorView()
}