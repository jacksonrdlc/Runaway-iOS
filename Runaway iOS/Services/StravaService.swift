//
//  StravaService.swift
//  Runaway iOS
//
//  Service for managing Strava OAuth connection and disconnection
//

import Foundation

class StravaService: ObservableObject {
    private let session = URLSession.shared

    // Strava OAuth configuration
    private let clientID = "118220" // Must match STRAVA_CLIENT_ID in webhook service

    // Toggle between production and local testing
    #if DEBUG
    private let webhookServiceBaseURL = "https://strava-webhooks-203308554831.us-central1.run.app" // Change to "http://localhost:8080" for local testing
    #else
    private let webhookServiceBaseURL = "https://strava-webhooks-203308554831.us-central1.run.app"
    #endif

    @Published var isConnected = false
    @Published var isLoading = false
    @Published var error: StravaError?

    // MARK: - Connection Management

    /// Generate Strava OAuth URL with auth_user_id in state parameter
    func getStravaConnectURL(authUserId: String) -> URL? {
        // Build URL components for proper encoding
        var components = URLComponents(string: "https://www.strava.com/oauth/authorize")!

        let redirectUri = "\(webhookServiceBaseURL)/callback"

        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "approval_prompt", value: "force"),
            URLQueryItem(name: "scope", value: "activity:read_all,profile:read_all"),
            URLQueryItem(name: "state", value: authUserId)
        ]

        #if DEBUG
        print("🔗 Generated Strava OAuth URL:")
        print("   Redirect URI: \(redirectUri)")
        print("   Full URL: \(components.url?.absoluteString ?? "nil")")
        #endif

        return components.url
    }

    /// Disconnect from Strava by revoking access tokens
    @MainActor
    func disconnectStrava(authUserId: String) async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }

        guard let url = URL(string: "\(webhookServiceBaseURL)/disconnect") else {
            throw StravaError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Send auth_user_id to disconnect endpoint
        let body = ["auth_user_id": authUserId]
        request.httpBody = try JSONEncoder().encode(body)

        #if DEBUG
        print("🔌 Disconnecting from Strava")
        print("   Auth User ID: \(authUserId)")
        print("   Endpoint: \(url)")
        #endif

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw StravaError.invalidResponse
            }

            #if DEBUG
            print("   Response Code: \(httpResponse.statusCode)")
            #endif

            guard 200...299 ~= httpResponse.statusCode else {
                if let errorResponse = try? JSONDecoder().decode(StravaErrorResponse.self, from: data) {
                    throw StravaError.serverError(errorResponse.error)
                }
                throw StravaError.httpError(httpResponse.statusCode)
            }

            // Parse success response
            if let successResponse = try? JSONDecoder().decode(StravaDisconnectResponse.self, from: data) {
                #if DEBUG
                print("   ✅ Disconnected successfully")
                print("   Athlete ID: \(successResponse.athlete_id ?? 0)")
                #endif

                isConnected = false

                // Refresh athlete data to reflect disconnection
                if let userId = UserSession.shared.userId {
                    await DataManager.shared.loadAthlete(for: userId)
                }
            }

        } catch let stravaError as StravaError {
            error = stravaError
            throw stravaError
        } catch {
            let wrappedError = StravaError.networkError(error)
            self.error = wrappedError
            throw wrappedError
        }
    }

    /// Handle deep link callback after OAuth flow completes
    @MainActor
    func handleStravaCallback(url: URL) async {
        #if DEBUG
        print("🔗 Handling Strava callback: \(url)")
        #endif

        // Parse query parameters
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let queryItems = components.queryItems else {
            error = StravaError.invalidCallback
            return
        }

        // Check for success parameter
        let success = queryItems.first(where: { $0.name == "success" })?.value == "true"
        let athleteId = queryItems.first(where: { $0.name == "athlete_id" })?.value

        if success {
            #if DEBUG
            print("   ✅ Strava connection successful")
            if let athleteId = athleteId {
                print("   Athlete ID: \(athleteId)")
            }
            #endif

            isConnected = true

            // Refresh athlete data to reflect new connection
            if let userId = UserSession.shared.userId {
                await DataManager.shared.loadAthlete(for: userId)
            }
        } else {
            #if DEBUG
            print("   ❌ Strava connection failed")
            #endif

            error = StravaError.authorizationFailed
        }
    }

    /// Check current connection status from athlete data
    @MainActor
    func checkConnectionStatus() async {
        // Check if athlete has strava_connected flag set
        if let athlete = DataManager.shared.athlete {
            let wasConnected = isConnected
            isConnected = athlete.stravaConnected ?? false

            #if DEBUG
            print("🔍 Checking Strava connection status")
            print("   Athlete ID: \(athlete.id ?? -1)")
            print("   Auth User ID: \(athlete.userId?.uuidString ?? "nil")")
            print("   stravaConnected field: \(athlete.stravaConnected?.description ?? "nil")")
            print("   Was Connected: \(wasConnected)")
            print("   Now Connected: \(isConnected)")
            if let connectedAt = athlete.stravaConnectedAt {
                print("   Connected at: \(connectedAt)")
            }
            if let disconnectedAt = athlete.stravaDisconnectedAt {
                print("   Last disconnected at: \(disconnectedAt)")
            }
            #endif
        } else {
            #if DEBUG
            print("🔍 Checking Strava connection status")
            print("   ❌ No athlete data available in DataManager")
            #endif
        }
    }
}

// MARK: - Error Types

enum StravaError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidCallback
    case networkError(Error)
    case httpError(Int)
    case serverError(String)
    case authorizationFailed
    case notConnected

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Strava service URL"
        case .invalidResponse:
            return "Invalid response from Strava service"
        case .invalidCallback:
            return "Invalid OAuth callback URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .httpError(let statusCode):
            return "HTTP error \(statusCode)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .authorizationFailed:
            return "Strava authorization failed"
        case .notConnected:
            return "Not connected to Strava"
        }
    }
}

// MARK: - Response Models

private struct StravaDisconnectResponse: Codable {
    let success: Bool
    let message: String
    let athlete_id: Int?
}

private struct StravaErrorResponse: Codable {
    let error: String
    let details: String?
}
