//
//  TabBarButton.swift
//  Runaway iOS
//
//  Reusable tab bar button component for custom tab bar
//

import SwiftUI

struct TabBarButton: View {
    let icon: String
    let selectedIcon: String
    let label: String
    let isSelected: Bool

    init(icon: String, selectedIcon: String? = nil, label: String, isSelected: Bool) {
        self.icon = icon
        self.selectedIcon = selectedIcon ?? icon
        self.label = label
        self.isSelected = isSelected
    }

    @ObservedObject private var themeManager = ThemeManager.shared

    private var foregroundColor: Color {
        if isSelected {
            return AppTheme.Colors.accent
        } else {
            return themeManager.isDarkMode
                ? AppTheme.Colors.DarkMode.textTertiary
                : AppTheme.Colors.LightMode.textTertiary
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                // Selected pill indicator (like Teams)
                if isSelected {
                    Capsule()
                        .fill(AppTheme.Colors.accent.opacity(0.15))
                        .frame(width: 48, height: 26)
                }

                Image(systemName: isSelected ? selectedIcon : icon)
                    .font(.system(size: 18))
                    .fontWeight(isSelected ? .medium : .regular)
            }
            .frame(height: 26)

            Text(label)
                .font(.system(size: 10, weight: isSelected ? .medium : .regular))
        }
        .foregroundColor(foregroundColor)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

#Preview {
    HStack {
        TabBarButton(icon: "figure.run", selectedIcon: "figure.run", label: "Activities", isSelected: true)
        TabBarButton(icon: "chart.bar", selectedIcon: "chart.bar.fill", label: "Progress", isSelected: false)
        TabBarButton(icon: "calendar", selectedIcon: "calendar", label: "Plan", isSelected: false)
        TabBarButton(icon: "person", selectedIcon: "person.fill", label: "Profile", isSelected: false)
    }
    .padding()
    .background(Color.black)
}
