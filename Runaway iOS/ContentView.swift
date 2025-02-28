//
//  ContentView.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 2/18/25.
//

import SwiftUI

import SwiftUI

struct ContentView: View {
    @StateObject private var authService = AuthService.shared
    @State var isStravaAuthenticated: Bool = false
    
    var body: some View {
        if authService.isAuthenticated {
            if isStravaAuthenticated {
                StravaMainView()
            } else {
                MainView()
            }
        } else {
            LoginView()
        }
    }

}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
