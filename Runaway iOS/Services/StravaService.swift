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
    private let clientID = "118220" // Must match STRAVA_CLIENT_ID in data sync service

    // Supabase Edge Functions - Always use production
    // (localhost doesn't work on physical devices)
    private let dataSyncServiceBaseURL = "https://nkxvjcdxiyjbndjvfmqy.supabase.co"

    @Published var isConnected = false
    @Published var isLoading = false
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncProgress: String?
    @Published var error: StravaError?

    // MARK: - Connection Management

    /// Generate Strava OAuth URL with auth_user_id in state parameter
    func getStravaConnectURL(authUserId: String) -> URL? {
        // Track analytics
        Task { @MainActor in
            AnalyticsService.shared.track(.stravaConnectStarted, category: .strava)
        }

        // Build URL components for proper encoding
        var components = URLComponents(string: "https://www.strava.com/oauth/authorize")!

        let redirectUri = "\(dataSyncServiceBaseURL)/functions/v1/oauth-callback"

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

        guard let url = URL(string: "\(dataSyncServiceBaseURL)/functions/v1/disconnect") else {
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

            // Track analytics
            AnalyticsService.shared.track(.stravaConnected, category: .strava, properties: [
                "has_athlete_id": athleteId != nil
            ])

            isConnected = true

            // Refresh athlete data to reflect new connection
            if let userId = UserSession.shared.userId {
                await DataManager.shared.loadAthlete(for: userId)
            }
        } else {
            #if DEBUG
            print("   ❌ Strava connection failed")
            #endif

            // Track analytics
            AnalyticsService.shared.track(.stravaSyncFailed, category: .strava, properties: [
                "error": "authorization_failed"
            ])

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

    // MARK: - Data Sync Management

    /// Trigger a sync of Strava data to Supabase
    @MainActor
    func syncStravaData(userId: String, syncType: StravaSyncType = .incremental) async throws -> String {
        isSyncing = true
        syncProgress = "Starting sync..."
        error = nil
        defer { isSyncing = false }

        // Track analytics
        AnalyticsService.shared.track(.stravaSyncStarted, category: .strava, properties: [
            "sync_type": syncType.rawValue
        ])

        guard let url = URL(string: "\(dataSyncServiceBaseURL)/functions/v1/sync-beta") else {
            throw StravaError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "user_id": userId,
            "sync_type": syncType.rawValue
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        #if DEBUG
        print("🔄 Triggering Strava data sync")
        print("   User ID: \(userId)")
        print("   Sync Type: \(syncType.rawValue)")
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

            // Parse job response
            let syncResponse = try JSONDecoder().decode(StravaSyncResponse.self, from: data)

            #if DEBUG
            print("   ✅ Sync job created")
            print("   Job ID: \(syncResponse.job_id)")
            print("   Status: \(syncResponse.status)")
            #endif

            syncProgress = "Sync job created: \(syncResponse.job_id)"

            // Poll for job completion
            try await pollSyncStatus(jobId: syncResponse.job_id)

            return syncResponse.job_id

        } catch let stravaError as StravaError {
            error = stravaError
            syncProgress = nil
            throw stravaError
        } catch {
            let wrappedError = StravaError.networkError(error)
            self.error = wrappedError
            syncProgress = nil
            throw wrappedError
        }
    }

    /// Poll sync job status until completion
    @MainActor
    private func pollSyncStatus(jobId: String) async throws {
        let maxAttempts = 60 // 5 minutes with 5 second intervals
        var attempts = 0

        while attempts < maxAttempts {
            guard let url = URL(string: "\(dataSyncServiceBaseURL)/functions/v1/job-status/\(jobId)") else {
                throw StravaError.invalidURL
            }

            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  200...299 ~= httpResponse.statusCode else {
                throw StravaError.invalidResponse
            }

            let jobStatus = try JSONDecoder().decode(StravaJobStatus.self, from: data)

            syncProgress = "Sync \(jobStatus.status): \(jobStatus.progress ?? 0)%"

            #if DEBUG
            print("🔄 Sync Status: \(jobStatus.status) - \(jobStatus.progress ?? 0)%")
            if let activitiesProcessed = jobStatus.activities_processed {
                print("   Activities processed: \(activitiesProcessed)")
            }
            #endif

            switch jobStatus.status.lowercased() {
            case "completed":
                syncProgress = "Sync completed successfully"
                lastSyncDate = Date()

                // Track analytics
                AnalyticsService.shared.trackStravaSync(
                    activitiesCount: jobStatus.activities_processed ?? 0,
                    success: true
                )

                // Reload athlete data to get synced activities
                if let userId = UserSession.shared.userId {
                    await DataManager.shared.loadAthlete(for: userId)
                    await DataManager.shared.loadActivities(for: userId)
                }

                return

            case "failed":
                syncProgress = nil

                // Track analytics
                AnalyticsService.shared.trackStravaSync(
                    activitiesCount: jobStatus.activities_processed ?? 0,
                    success: false,
                    error: jobStatus.error ?? "Unknown error"
                )

                throw StravaError.syncFailed(jobStatus.error ?? "Unknown error")

            case "pending", "running":
                // Continue polling
                try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                attempts += 1

            default:
                break
            }
        }

        throw StravaError.syncTimeout
    }

    /// Check the status of a sync job
    @MainActor
    func checkSyncStatus(jobId: String) async throws -> StravaJobStatus {
        guard let url = URL(string: "\(dataSyncServiceBaseURL)/functions/v1/job-status/\(jobId)") else {
            throw StravaError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw StravaError.invalidResponse
        }

        return try JSONDecoder().decode(StravaJobStatus.self, from: data)
    }
}

// MARK: - Sync Types

enum StravaSyncType: String {
    case incremental = "incremental"
    case full = "full"
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
    case syncFailed(String)
    case syncTimeout

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
        case .syncFailed(let message):
            return "Sync failed: \(message)"
        case .syncTimeout:
            return "Sync operation timed out"
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

struct StravaSyncResponse: Codable {
    let job_id: String
    let status: String
    let sync_type: String
    let created_at: String
    let user_id: String
}

struct StravaJobStatus: Codable {
    let id: String
    let user_id: String
    let status: String
    let sync_type: String
    let progress: Int?
    let activities_processed: Int?
    let error: String?
    let created_at: String
    let updated_at: String?
    let completed_at: String?
}
