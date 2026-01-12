//
//  LoginView.swift
//  Runaway iOS
//
//  Main authentication entry point - wraps the new SignInView
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        SignInView()
            .environmentObject(userSession)
            .environmentObject(themeManager)
    }
}

#Preview {
    LoginView()
        .environmentObject(UserSession.shared)
        .environmentObject(ThemeManager.shared)
}
