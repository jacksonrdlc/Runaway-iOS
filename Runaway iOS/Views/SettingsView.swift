//
//  SettingsView.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 6/27/25.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var stravaService = StravaService()
    @State private var showingStravaSheet = false
    @State private var showingDisconnectAlert = false
    @State private var stravaError: String?

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: AppTheme.Spacing.lg) {
                        // Profile Section
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                            Text("Profile")
                                .font(AppTheme.Typography.headline)
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            
                            SettingsRow(
                                icon: "person.circle",
                                title: "Account Information",
                                subtitle: "Manage your profile details",
                                color: AppTheme.Colors.primary
                            ) {
                                // TODO: Navigate to account settings
                            }
                        }
                        
                        // App Settings
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                            Text("App Settings")
                                .font(AppTheme.Typography.headline)
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            
                            SettingsRow(
                                icon: "bell",
                                title: "Notifications",
                                subtitle: "Manage push notifications",
                                color: AppTheme.Colors.accent
                            ) {
                                // TODO: Navigate to notification settings
                            }
                            
                            SettingsRow(
                                icon: "location",
                                title: "Location Services",
                                subtitle: "Privacy and location settings",
                                color: AppTheme.Colors.warning
                            ) {
                                // TODO: Navigate to location settings
                            }
                            
                            SettingsRow(
                                icon: "cloud",
                                title: "Data Sync",
                                subtitle: "Sync activities and preferences",
                                color: AppTheme.Colors.success
                            ) {
                                // TODO: Navigate to sync settings
                            }
                        }

                        // Integrations Section
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                            Text("Integrations")
                                .font(AppTheme.Typography.headline)
                                .foregroundColor(AppTheme.Colors.textPrimary)

                            // Strava Integration Row
                            StravaIntegrationRow(
                                isConnected: stravaService.isConnected,
                                onConnect: { showingStravaSheet = true },
                                onDisconnect: { showingDisconnectAlert = true }
                            )

                            // Show error if any
                            if let error = stravaError {
                                Text(error)
                                    .font(AppTheme.Typography.caption)
                                    .foregroundColor(AppTheme.Colors.error)
                                    .padding(.horizontal, AppTheme.Spacing.md)
                            }
                        }

                        // Support Section
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                            Text("Support")
                                .font(AppTheme.Typography.headline)
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            
                            SettingsRow(
                                icon: "questionmark.circle",
                                title: "Help & FAQ",
                                subtitle: "Get help and find answers",
                                color: AppTheme.Colors.primary
                            ) {
                                // TODO: Navigate to help
                            }
                            
                            SettingsRow(
                                icon: "envelope",
                                title: "Contact Support",
                                subtitle: "Get in touch with our team",
                                color: AppTheme.Colors.accent
                            ) {
                                // TODO: Open email or contact form
                            }
                        }
                        
                        // Debug Section (only show in debug builds)
                        #if DEBUG
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                            Text("Debug")
                                .font(AppTheme.Typography.headline)
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            
                            NavigationLink(destination: DebugMenuView()) {
                                SettingsRow(
                                    icon: "wrench.and.screwdriver",
                                    title: "Background Task Monitor",
                                    subtitle: "Monitor realtime connections and background tasks",
                                    color: .purple
                                ) {
                                    // Navigation handled by NavigationLink
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        #endif
                        
                        // Danger Zone
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                            Text("Account")
                                .font(AppTheme.Typography.headline)
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            
                            SettingsRow(
                                icon: "rectangle.portrait.and.arrow.right",
                                title: "Sign Out",
                                subtitle: "Sign out of your account",
                                color: AppTheme.Colors.error,
                                isDestructive: true
                            ) {
                                Task {
                                    try? await userSession.signOut()
                                    dismiss()
                                }
                            }
                        }
                        
                        // App Info
                        VStack(spacing: AppTheme.Spacing.sm) {
                            Text("Runaway iOS")
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(AppTheme.Colors.textTertiary)
                            
                            Text("Version 1.0.0")
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(AppTheme.Colors.textTertiary)
                        }
                        .padding(.top, AppTheme.Spacing.xl)
                    }
                    .padding(AppTheme.Spacing.md)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.primary)
                }
            }
            .sheet(isPresented: $showingStravaSheet) {
                StravaConnectSheet(stravaService: stravaService)
            }
            .alert("Disconnect from Strava", isPresented: $showingDisconnectAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Disconnect", role: .destructive) {
                    Task {
                        await disconnectFromStrava()
                    }
                }
            } message: {
                Text("Are you sure you want to disconnect from Strava? Your activities will no longer sync automatically.")
            }
            .task {
                await stravaService.checkConnectionStatus()
            }
            .onChange(of: dataManager.athlete) { _ in
                Task {
                    await stravaService.checkConnectionStatus()
                }
            }
            .task {
                await stravaService.checkConnectionStatus()
            }
        }
    }

    // MARK: - Helper Methods

    private func disconnectFromStrava() async {
        guard let authUserId = await APIConfiguration.RunawayCoach.getCurrentAuthUserId() else {
            stravaError = "Unable to get user ID"
            return
        }

        do {
            try await stravaService.disconnectStrava(authUserId: authUserId)
            stravaError = nil
        } catch {
            stravaError = error.localizedDescription
        }
    }
}

// MARK: - Settings Row
struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    var isDestructive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(color)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTheme.Typography.body.weight(.medium))
                        .foregroundColor(isDestructive ? AppTheme.Colors.error : AppTheme.Colors.textPrimary)

                    Text(subtitle)
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                // Chevron
                if !isDestructive {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .buttonStyle(PlainButtonStyle())
        .surfaceCard()
    }
}

// MARK: - Strava Connect Sheet
struct StravaConnectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var stravaService: StravaService
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.Colors.background.ignoresSafeArea()

                VStack(spacing: AppTheme.Spacing.xl) {
                    // Strava Logo/Icon
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.2))
                            .frame(width: 100, height: 100)

                        Image(systemName: "bolt.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                    }
                    .padding(.top, AppTheme.Spacing.xl)

                    // Title and Description
                    VStack(spacing: AppTheme.Spacing.md) {
                        Text("Connect to Strava")
                            .font(AppTheme.Typography.title)
                            .foregroundColor(AppTheme.Colors.textPrimary)

                        Text("Sync your Strava activities automatically. You can disconnect at any time.")
                            .font(AppTheme.Typography.body)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppTheme.Spacing.lg)
                    }

                    // Benefits List
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                        BenefitRow(icon: "arrow.triangle.2.circlepath", text: "Automatic activity sync")
                        BenefitRow(icon: "chart.line.uptrend.xyaxis", text: "Enhanced analytics")
                        BenefitRow(icon: "lock.shield", text: "Secure OAuth connection")
                    }
                    .padding(.horizontal, AppTheme.Spacing.xl)

                    Spacer()

                    // Connect Button
                    Button(action: {
                        Task {
                            await connectToStrava()
                        }
                    }) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "bolt.fill")
                                Text("Connect with Strava")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(AppTheme.Spacing.md)
                    }
                    .disabled(isLoading)
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .padding(.bottom, AppTheme.Spacing.lg)
                }
            }
            .navigationTitle("Strava Integration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.primary)
                }
            }
        }
    }

    private func connectToStrava() async {
        isLoading = true
        defer { isLoading = false }

        guard let authUserId = await APIConfiguration.RunawayCoach.getCurrentAuthUserId() else {
            #if DEBUG
            print("❌ Unable to get auth user ID for Strava connection")
            #endif
            return
        }

        guard let stravaURL = stravaService.getStravaConnectURL(authUserId: authUserId) else {
            #if DEBUG
            print("❌ Unable to generate Strava OAuth URL")
            #endif
            return
        }

        #if DEBUG
        print("🔗 Opening Strava OAuth URL: \(stravaURL)")
        #endif

        // Open Strava OAuth URL in Safari
        await UIApplication.shared.open(stravaURL)

        // Dismiss sheet - user will return via deep link
        dismiss()
    }
}

// MARK: - Benefit Row Helper
struct BenefitRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: icon)
                .foregroundColor(AppTheme.Colors.primary)
                .frame(width: 24)

            Text(text)
                .font(AppTheme.Typography.body)
                .foregroundColor(AppTheme.Colors.textPrimary)

            Spacer()
        }
    }
}

// MARK: - Strava Integration Row
struct StravaIntegrationRow: View {
    let isConnected: Bool
    let onConnect: () -> Void
    let onDisconnect: () -> Void

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            // Icon
            stravaIcon

            // Content
            stravaContent

            Spacer()

            // Action Button
            actionButton
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.surfaceBackground)
        .cornerRadius(AppTheme.CornerRadius.large)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
    }

    private var stravaIcon: some View {
        ZStack {
            Circle()
                .fill(AppTheme.Colors.success.opacity(0.2))
                .frame(width: 40, height: 40)

            Image(systemName: "bolt.fill")
                .font(.title3)
                .foregroundColor(AppTheme.Colors.success)
        }
    }

    private var stravaContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Strava")
                .font(AppTheme.Typography.body.weight(.medium))
                .foregroundColor(AppTheme.Colors.textPrimary)

            Text(isConnected ? "Connected" : "Not connected")
                .font(AppTheme.Typography.caption)
                .foregroundColor(isConnected ? AppTheme.Colors.success : AppTheme.Colors.textSecondary)
        }
    }

    private var actionButton: some View {
        Group {
            if isConnected {
                disconnectButton
            } else {
                connectButton
            }
        }
    }

    private var connectButton: some View {
        Button(action: onConnect) {
            Text("Connect")
                .font(AppTheme.Typography.caption.weight(.medium))
                .foregroundColor(AppTheme.Colors.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppTheme.Colors.accent.opacity(0.1))
                .cornerRadius(8)
        }
    }

    private var disconnectButton: some View {
        Button(action: onDisconnect) {
            Text("Disconnect")
                .font(AppTheme.Typography.caption.weight(.medium))
                .foregroundColor(AppTheme.Colors.error)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppTheme.Colors.error.opacity(0.1))
                .cornerRadius(8)
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(UserSession.shared)
            .environmentObject(DataManager.shared)
    }
}
