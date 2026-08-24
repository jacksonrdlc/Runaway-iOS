//
//  ContentView.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 2/18/25.
//

import SwiftUI

struct ContentView: View {
    @Environment(UserSession.self) var userSession

    var body: some View {
        if userSession.isCheckingAuth || userSession.isCheckingOnboarding {
            LoaderView()
        } else if let setupError = userSession.setupError {
            SessionSetupErrorView(message: setupError) {
                Task { await userSession.retrySetup() }
            }
        } else if userSession.isReady {
            if userSession.hasCompletedOnboarding {
                MainView()
            } else {
                OnboardingContainerView()
            }
        } else if userSession.isAuthenticated {
            LoaderView()
        } else {
            LoginView()
        }
    }
}

private struct SessionSetupErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .foregroundStyle(AppTheme.Colors.warmAmber)
                .accessibilityHidden(true)
            Text("Account setup paused")
                .font(AppTheme.Typography.title)
            Text(message)
                .font(AppTheme.Typography.body)
                .multilineTextAlignment(.center)
            Button("Try Again", action: retry)
                .font(AppTheme.Typography.headline)
                .frame(minHeight: 44)
                .buttonStyle(.borderedProminent)
                .accessibilityHint("Retries secure account setup")
        }
        .padding(AppTheme.Spacing.xl)
        .accessibilityElement(children: .contain)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(UserSession.shared)
    }
}
