//
//  LoaderView.swift
//  RunawayUI
//
//  Created by Jack Rudelic on 7/22/24.
//

import Foundation
import SwiftUI

public struct LoaderView: View {
    public var body: some View {
        NavigationView {
            VStack {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.accent))
                    .scaleEffect(2)
                Text("Loading...")
                    .font(AppTheme.Typography.title)
                    .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary)
                    .padding(.top, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background((ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.background : AppTheme.Colors.LightMode.background).ignoresSafeArea())
            .navigationTitle("Loading")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
