//
//  StravaAuthService.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 2/23/25.
//

import Foundation

class StravaAuthService: ObservableObject {
    @Published private var token: OAuthToken?
    @Published var isStravaAuthenticated = false
    
    static let shared = StravaAuthService()
    
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

    private func didAuthenticate(result: Result<OAuthToken, Error>) {
        switch result {
        case .success(let token):
            print(token)
            self.token = token
            self.isStravaAuthenticated = true
        case .failure(let error):
            debugPrint(error)
        }
    }
}



