//
//  SettingsView.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 6/27/25.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var userSession: UserSession
    @Environment(\.dismiss) private var dismiss
    
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
                                .foregroundColor(AppTheme.Colors.primaryText)
                            
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
                                .foregroundColor(AppTheme.Colors.primaryText)
                            
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
                        
                        // Support Section
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                            Text("Support")
                                .font(AppTheme.Typography.headline)
                                .foregroundColor(AppTheme.Colors.primaryText)
                            
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
                                .foregroundColor(AppTheme.Colors.primaryText)
                            
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
                                .foregroundColor(AppTheme.Colors.primaryText)
                            
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
                                .foregroundColor(AppTheme.Colors.mutedText)
                            
                            Text("Version 1.0.0")
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(AppTheme.Colors.mutedText)
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
                        .foregroundColor(isDestructive ? AppTheme.Colors.error : AppTheme.Colors.primaryText)
                    
                    Text(subtitle)
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.secondaryText)
                }
                
                Spacer()
                
                // Chevron
                if !isDestructive {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.mutedText)
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .buttonStyle(PlainButtonStyle())
        .surfaceCard()
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(UserSession.shared)
    }
}