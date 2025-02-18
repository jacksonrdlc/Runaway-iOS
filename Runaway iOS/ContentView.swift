//
//  ContentView.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 2/18/25.
//

import SwiftUI

struct ContentView: View {
    @State private var token: OAuthToken?
    @State private var isAuthenticated: Bool = false
    var body: some View {
        
        if isAuthenticated {
            MainView()
        } else {
            VStack {
                Button{
                    login()
                } label: {
                    Image("Strava")
                }
            }
        }
    }
}

extension ContentView {
    
    func login() {
        StravaClient.sharedInstance.authorize() { (result: Result<OAuthToken, Error>) in
            switch result {
            case .success:
                self.didAuthenticate(result: result)
            case .failure(let error):
                print("Failed with: \(error)")
            }
        }
    }
    
    //  func logout() {
    //    Auth0
    //      .webAuth()
    //      .clearSession { result in
    //        switch result {
    //          case .success:
    //            self.isAuthenticated = false
    //            self.userProfile = Profile.empty
    //
    //          case .failure(let error):
    //            print("Failed with: \(error)")
    //        }
    //      }
    //  }
    
    private func didAuthenticate(result: Result<OAuthToken, Error>) {
        switch result {
        case .success(let token):
            self.token = token
            print(token)
            self.isAuthenticated = true
        case .failure(let error):
            debugPrint(error)
        }
    }

}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
