//
//  TabBarButton.swift
//  Runaway iOS
//
//  Reusable tab bar button component for custom tab bar
//

import SwiftUI

struct TabBarButton: View {
    let icon: String
    let label: String
    let isSelected: Bool

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
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .fontWeight(isSelected ? .semibold : .regular)

            Text(label)
                .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
        }
        .foregroundColor(foregroundColor)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

#Preview {
    HStack {
        TabBarButton(icon: "figure.run", label: "Activities", isSelected: true)
        TabBarButton(icon: "chart.bar.fill", label: "Progress", isSelected: false)
        TabBarButton(icon: "calendar.badge.clock", label: "Plan", isSelected: false)
        TabBarButton(icon: "person.fill", label: "Profile", isSelected: false)
    }
    .padding()
    .background(Color.black)
}
