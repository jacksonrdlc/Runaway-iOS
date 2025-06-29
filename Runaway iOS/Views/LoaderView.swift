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
                    .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                    .scaleEffect(2)
                Text("Loading...")
                    .font(AppTheme.Typography.title)
                    .foregroundColor(AppTheme.Colors.primaryText)
                    .padding(.top, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Loading")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
