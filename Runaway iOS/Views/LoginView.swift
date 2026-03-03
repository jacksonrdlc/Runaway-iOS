//
//  LoginView.swift
//  Runaway iOS
//
//  Main authentication entry point - wraps the new SignInView
//

import SwiftUI

struct LoginView: View {
    @Environment(UserSession.self) var userSession
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        SignInView()
            .environment(userSession)
            .environmentObject(themeManager)
    }
}

#Preview {
    LoginView()
        .environment(UserSession.shared)
        .environmentObject(ThemeManager.shared)
}
