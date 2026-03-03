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
        } else if userSession.isAuthenticated {
            if userSession.hasCompletedOnboarding {
                MainView()
            } else {
                OnboardingContainerView()
            }
        } else {
            LoginView()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(UserSession.shared)
    }
}
