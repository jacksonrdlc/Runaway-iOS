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
                AppTheme.Colors.LightMode.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppTheme.Spacing.lg) {
                        profileSection
                        appSettingsSection
                        integrationsSection
                        supportSection
                        debugSection
                        accountSection
                        appInfoSection
                    }
                    .padding(AppTheme.Spacing.md)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.LightMode.accent)
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

    // MARK: - View Components

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("Profile")
                .font(AppTheme.Typography.headline)
                .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

            NavigationLink(destination: AccountInformationView()) {
                SettingsRow(
                    icon: "person.circle",
                    title: "Account Information",
                    subtitle: "Manage your profile details",
                    color: AppTheme.Colors.primary
                ) {
                    // Navigation handled by NavigationLink
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private var appSettingsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("App Settings")
                .font(AppTheme.Typography.headline)
                .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

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
    }

    private var integrationsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("Integrations")
                .font(AppTheme.Typography.headline)
                .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

            StravaIntegrationRow(
                stravaService: stravaService,
                onConnect: { showingStravaSheet = true },
                onDisconnect: { showingDisconnectAlert = true },
                onSync: {
                    Task {
                        guard let userId = dataManager.athlete?.id else {
                            stravaError = "No Strava athlete ID found"
                            return
                        }
                        do {
                            _ = try await stravaService.syncStravaData(userId: String(userId), syncType: .incremental)
                            stravaError = nil
                        } catch {
                            stravaError = error.localizedDescription
                        }
                    }
                }
            )

            if let error = stravaError {
                Text(error)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.error)
                    .padding(.horizontal, AppTheme.Spacing.md)
            }
        }
    }

    private var supportSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("Support")
                .font(AppTheme.Typography.headline)
                .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

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
    }

    @ViewBuilder
    private var debugSection: some View {
        #if DEBUG
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("Debug")
                .font(AppTheme.Typography.headline)
                .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

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
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("Account")
                .font(AppTheme.Typography.headline)
                .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

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
    }

    private var appInfoSection: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Text("Runaway iOS")
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.LightMode.textTertiary)

            Text("Version 1.0.0")
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.LightMode.textTertiary)
        }
        .padding(.top, AppTheme.Spacing.xl)
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
                        .foregroundColor(isDestructive ? AppTheme.Colors.error : AppTheme.Colors.LightMode.textPrimary)

                    Text(subtitle)
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
                }
                
                Spacer()
                
                // Chevron
                if !isDestructive {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.LightMode.textTertiary)
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
                AppTheme.Colors.LightMode.background.ignoresSafeArea()

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
                            .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

                        Text("Sync your Strava activities automatically. You can disconnect at any time.")
                            .font(AppTheme.Typography.body)
                            .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
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
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.LightMode.accent)
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
                .foregroundColor(AppTheme.Colors.LightMode.accent)
                .frame(width: 24)

            Text(text)
                .font(AppTheme.Typography.body)
                .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

            Spacer()
        }
    }
}

// MARK: - Strava Integration Row
struct StravaIntegrationRow: View {
    @ObservedObject var stravaService: StravaService
    let onConnect: () -> Void
    let onDisconnect: () -> Void
    let onSync: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            // Main connection row
            HStack(spacing: AppTheme.Spacing.md) {
                // Icon
                stravaIcon

                // Content
                stravaContent

                Spacer()

                // Action Button
                actionButton
            }

            // Sync section (only show if connected)
            if stravaService.isConnected {
                Divider()

                syncSection
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(Color(red: 0.96, green: 0.96, blue: 0.97))
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
                .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

            Text(stravaService.isConnected ? "Connected" : "Not connected")
                .font(AppTheme.Typography.caption)
                .foregroundColor(stravaService.isConnected ? AppTheme.Colors.success : AppTheme.Colors.LightMode.textSecondary)
        }
    }

    private var syncSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            // Sync status
            HStack {
                Image(systemName: stravaService.isSyncing ? "arrow.triangle.2.circlepath" : "checkmark.circle.fill")
                    .foregroundColor(stravaService.isSyncing ? AppTheme.Colors.warning : AppTheme.Colors.success)
                    .imageScale(.small)

                VStack(alignment: .leading, spacing: 2) {
                    Text(stravaService.isSyncing ? "Syncing..." : "Data Sync")
                        .font(AppTheme.Typography.caption.weight(.medium))
                        .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

                    if let progress = stravaService.syncProgress {
                        Text(progress)
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
                    } else if let lastSync = stravaService.lastSyncDate {
                        Text("Last synced: \(lastSync, style: .relative) ago")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
                    } else {
                        Text("Never synced")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
                    }
                }

                Spacer()

                // Sync button
                Button(action: onSync) {
                    if stravaService.isSyncing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                    } else {
                        Text("Sync Beta")
                            .font(AppTheme.Typography.caption.weight(.medium))
                            .foregroundColor(AppTheme.Colors.LightMode.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppTheme.Colors.LightMode.accent.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .disabled(stravaService.isSyncing)
            }
        }
    }

    private var actionButton: some View {
        Group {
            if stravaService.isConnected {
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
                .foregroundColor(AppTheme.Colors.LightMode.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppTheme.Colors.LightMode.accent.opacity(0.1))
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
