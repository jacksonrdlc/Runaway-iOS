//
//  CustomTabBar.swift
//  Runaway iOS
//
//  Custom tab bar with prominent center Record button
//

import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @Binding var showRecording: Bool

    @ObservedObject private var themeManager = ThemeManager.shared

    private var backgroundColor: Color {
        themeManager.isDarkMode
            ? AppTheme.Colors.DarkMode.cardBackground
            : AppTheme.Colors.LightMode.cardBackground
    }

    private var borderColor: Color {
        themeManager.isDarkMode
            ? Color.white.opacity(0.1)
            : Color.black.opacity(0.08)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Tab 0: Activities
            TabBarButton(icon: "figure.run", label: "Activities", isSelected: selectedTab == 0)
                .onTapGesture { selectedTab = 0 }

            // Tab 1: Progress
            TabBarButton(icon: "chart.bar.fill", label: "Progress", isSelected: selectedTab == 1)
                .onTapGesture { selectedTab = 1 }

            // Center: Record button (larger, prominent)
            recordButton
                .frame(maxWidth: .infinity)

            // Tab 3: Plan
            TabBarButton(icon: "calendar.badge.clock", label: "Plan", isSelected: selectedTab == 3)
                .onTapGesture { selectedTab = 3 }

            // Tab 4: Profile
            TabBarButton(icon: "person.fill", label: "Profile", isSelected: selectedTab == 4)
                .onTapGesture { selectedTab = 4 }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.top, AppTheme.Spacing.sm)
        .padding(.bottom, 28) // Account for home indicator
        .background(
            Rectangle()
                .fill(backgroundColor)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: -4)
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundColor(borderColor),
                    alignment: .top
                )
        )
    }

    private var recordButton: some View {
        Button(action: { showRecording = true }) {
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.accentGradient)
                    .frame(width: 56, height: 56)
                    .shadow(color: AppTheme.Colors.accent.opacity(0.4), radius: 8, x: 0, y: 4)

                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.black)
            }
        }
        .offset(y: -12) // Lift above tab bar
    }
}

#Preview {
    VStack {
        Spacer()
        CustomTabBar(selectedTab: .constant(0), showRecording: .constant(false))
    }
    .background(Color.gray.opacity(0.2))
}
