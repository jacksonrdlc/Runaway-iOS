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
                    .font(AppTheme.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

                Text("Monitor your app's realtime background tasks")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
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
                        .font(AppTheme.Typography.headline)
                        .foregroundColor(AppTheme.Colors.LightMode.textPrimary)
                    Text(connectionStatusText)
                        .font(AppTheme.Typography.caption)
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
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.LightMode.textSecondary)

                Text(healthStatusText)
                    .font(AppTheme.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(healthColor)

                Spacer()

                if let lastUpdate = realtimeService.lastUpdateTime {
                    Text("Updated \(timeAgoString(from: lastUpdate))")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
                }
            }
        }
        .padding()
        .background(AppTheme.Colors.LightMode.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.large)
        .shadow(
            color: AppTheme.Shadows.light.color,
            radius: AppTheme.Shadows.light.radius,
            x: AppTheme.Shadows.light.x,
            y: AppTheme.Shadows.light.y
        )
    }
    
    private var performanceMetricsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Background Task Performance")
                .font(AppTheme.Typography.headline)
                .foregroundColor(AppTheme.Colors.LightMode.textPrimary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                
                MetricView(
                    title: "Connection Status",
                    value: realtimeService.isConnected ? "Connected" : "Disconnected",
                    icon: "wifi",
                    color: realtimeService.isConnected ? AppTheme.Colors.success : AppTheme.Colors.error
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
                    color: AppTheme.Colors.accent
                )

                MetricView(
                    title: "Background Refresh",
                    value: "Scheduled",
                    icon: "arrow.clockwise",
                    color: AppTheme.Colors.warning
                )
            }
        }
        .padding()
        .background(AppTheme.Colors.LightMode.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.large)
        .shadow(
            color: AppTheme.Shadows.light.color,
            radius: AppTheme.Shadows.light.radius,
            x: AppTheme.Shadows.light.x,
            y: AppTheme.Shadows.light.y
        )
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
                .background(AppTheme.Colors.accent)
                .foregroundColor(.black)
                .cornerRadius(AppTheme.CornerRadius.medium)
            }

            HStack(spacing: 12) {
                Button("Refresh Widget") {
                    realtimeService.refreshWidget()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppTheme.Colors.LightMode.cardBackground)
                .foregroundColor(AppTheme.Colors.LightMode.textPrimary)
                .cornerRadius(AppTheme.CornerRadius.medium)

                Button("View Details") {
                    showingDetails = true
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppTheme.Colors.LightMode.cardBackground)
                .foregroundColor(AppTheme.Colors.LightMode.textPrimary)
                .cornerRadius(AppTheme.CornerRadius.medium)
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
            return AppTheme.Colors.success
        case .degraded:
            return AppTheme.Colors.warning
        case .disconnected:
            return AppTheme.Colors.error
        case .unknown:
            return AppTheme.Colors.textTertiary
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
            return AppTheme.Colors.success
        case .degraded:
            return AppTheme.Colors.warning
        case .disconnected:
            return AppTheme.Colors.error
        case .unknown:
            return AppTheme.Colors.textTertiary
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
                    .font(AppTheme.Typography.caption)

                Spacer()
            }

            Text(value)
                .font(AppTheme.Typography.headline)
                .foregroundColor(color)

            Text(title)
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
        }
        .padding(12)
        .background(AppTheme.Colors.LightMode.background)
        .cornerRadius(AppTheme.CornerRadius.small)
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
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.LightMode.accent)
                }
            }
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
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

                Spacer()

                Text(status)
                    .font(AppTheme.Typography.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(AppTheme.Opacity.medium))
                    .foregroundColor(statusColor)
                    .cornerRadius(AppTheme.CornerRadius.tiny)
            }

            Text(description)
                .font(AppTheme.Typography.body)
                .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
            
            if !recommendations.isEmpty {
                Text("Recommendations:")
                    .font(AppTheme.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

                ForEach(recommendations, id: \.self) { recommendation in
                    HStack(alignment: .top) {
                        Text("•")
                            .foregroundColor(AppTheme.Colors.accent)
                        Text(recommendation)
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.Colors.LightMode.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.large)
        .shadow(
            color: AppTheme.Shadows.light.color,
            radius: AppTheme.Shadows.light.radius,
            x: AppTheme.Shadows.light.x,
            y: AppTheme.Shadows.light.y
        )
    }
    
    private var statusColor: Color {
        switch status.lowercased() {
        case "active", "enabled", "configured", "connected":
            return AppTheme.Colors.success
        case "degraded", "warning":
            return AppTheme.Colors.warning
        case "disabled", "disconnected", "error":
            return AppTheme.Colors.error
        default:
            return AppTheme.Colors.accent
        }
    }
}

#Preview {
    BackgroundTaskMonitorView()
}