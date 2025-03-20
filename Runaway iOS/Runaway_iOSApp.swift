//
//  Runaway_iOSApp.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 2/18/25.
//

import SwiftUI

// Import the AuthService class from ContentView.swift
import Foundation  // This is needed for the AuthService class

// @main attribute has to be in a separate file in SwiftUI projects
// that contain top-level code in other files
@main
struct Runaway_iOSApp: App {
    @StateObject private var authManager = AuthManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
        }
    }
} 
