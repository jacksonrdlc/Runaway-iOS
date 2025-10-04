//
//  APIConfiguration.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 6/28/25.
//

import Foundation
import Supabase

struct APIConfiguration {
    // MARK: - API Keys
    
    /// NewsAPI.org API key - Get free key at https://newsapi.org/
    static var newsAPIKey: String {
        return Bundle.main.infoDictionary?["NEWS_API_KEY"] as? String ?? ""
    }
    
    /// Eventbrite API key - Get free key at https://www.eventbrite.com/platform/api/
    static var eventbriteAPIKey: String {
        return Bundle.main.infoDictionary?["EVENTBRITE_API_KEY"] as? String ?? ""
    }
    
    // MARK: - API Endpoints
    
    struct NewsAPI {
        static let baseURL = "https://newsapi.org/v2"
        static let everything = "\(baseURL)/everything"
        static let topHeadlines = "\(baseURL)/top-headlines"
    }
    
    struct Eventbrite {
        static let baseURL = "https://www.eventbriteapi.com/v3"
        static let eventsSearch = "\(baseURL)/events/search/"
    }
    
    struct RunawayCoach {
        static let baseURL = "https://runaway-coach-api-203308554831.us-central1.run.app"
        static let devBaseURL = "http://localhost:8000"
        
        static var currentBaseURL: String {
            // Check for environment variable override
            if let envURL = ProcessInfo.processInfo.environment["RUNAWAY_API_URL"] {
                return envURL
            }
            
            #if DEBUG
            return baseURL  // Use production URL in debug mode too
            #else
            return baseURL
            #endif
        }
        
        // Endpoints
        static let health = "/health"
        static let root = "/"
        static let analyzeRunner = "/analysis/runner"
        static let quickInsights = "/analysis/quick-insights"
        static let workoutFeedback = "/feedback/workout"
        static let paceRecommendation = "/feedback/pace-recommendation"
        static let assessGoals = "/goals/assess"
        static let trainingPlan = "/goals/training-plan"

        // Quick Wins Endpoints
        static let comprehensiveAnalysis = "/quick-wins/comprehensive-analysis"
        static let weatherImpact = "/quick-wins/weather-impact"
        static let vo2maxEstimate = "/quick-wins/vo2max-estimate"
        static let trainingLoad = "/quick-wins/training-load"
        
        // Configuration
        static let requestTimeout: TimeInterval = 30.0
        static let retryCount = 3
        static let retryDelay: TimeInterval = 1.0
        static let cacheTimeout: TimeInterval = 5 * 60 // 5 minutes
        static let enableResponseCaching = true
        static let useAPIFallback = true
        static let enableLocalAnalysisFallback = true
        static let enableResponseValidation = true
        
        static func getAuthHeaders() async -> [String: String] {
            var headers = [
                "Content-Type": "application/json",
                "Accept": "application/json"
            ]

            // Try JWT token first (from Supabase Auth) with improved refresh handling
            if let jwtToken = await getJWTToken() {
                headers["Authorization"] = "Bearer \(jwtToken)"
                print("🔐 APIConfiguration: Using JWT token for authentication")
                return headers
            }

            // Fallback to API key for backwards compatibility
            if let authToken = getAuthToken() {
                headers["Authorization"] = "Bearer \(authToken)"
                print("🔐 APIConfiguration: Using API key for authentication (fallback)")
            } else {
                print("❌ APIConfiguration: No authentication token available (neither JWT nor API key)")
            }

            return headers
        }

        static func getAuthHeadersSync() -> [String: String] {
            var headers = [
                "Content-Type": "application/json",
                "Accept": "application/json"
            ]

            // Fallback to API key only for sync calls
            if let authToken = getAuthToken() {
                headers["Authorization"] = "Bearer \(authToken)"
            }

            return headers
        }

        private static func getJWTToken() async -> String? {
            do {
                // This automatically refreshes the token if needed
                let session = try await supabase.auth.session
                let token = session.accessToken

                // Check if token is about to expire (within 5 minutes)
                let expiresAt = session.expiresAt
                let timeUntilExpiry = expiresAt - Date().timeIntervalSince1970

                if timeUntilExpiry < 300 { // Less than 5 minutes
                    print("⏰ APIConfiguration: JWT token expires soon (in \(Int(timeUntilExpiry))s), but Supabase will auto-refresh")
                }

                print("🔐 APIConfiguration: Successfully got JWT token (length: \(token.count), expires in \(Int(timeUntilExpiry))s)")
                return token
            } catch {
                print("⚠️ APIConfiguration: Failed to get JWT token: \(error)")
                return nil
            }
        }

        static func getCurrentAuthUserId() async -> String? {
            do {
                let session = try await supabase.auth.session
                let userId = session.user.id.uuidString
                print("👤 APIConfiguration: Current auth user ID: \(userId)")
                return userId
            } catch {
                print("⚠️ APIConfiguration: Failed to get auth user ID: \(error)")
                return nil
            }
        }

        private static func getAuthToken() -> String? {
            // Check for environment variable first (recommended for security)
            if let envToken = ProcessInfo.processInfo.environment["RUNAWAY_API_KEY"] {
                return envToken
            }
            
            // Check for Info.plist configuration
            if let plistToken = Bundle.main.infoDictionary?["RUNAWAY_API_KEY"] as? String,
               !plistToken.isEmpty {
                return plistToken
            }
            
            // Fallback to hardcoded value (not recommended for production)
            return hardcodedAPIKey
        }
        
        // MARK: - API Key Configuration
        // SECURITY: Never commit API keys to source control!
        // Use environment variables or Info.plist instead
        private static let hardcodedAPIKey: String? = nil
        
        // SETUP: Add your API key via environment variable or Info.plist
        // Environment: RUNAWAY_API_KEY=your-key-here
        // Info.plist: Add RUNAWAY_API_KEY key with your API key value
        
        static func validateResponse<T: Codable>(_ data: Data, responseType: T.Type) -> Bool {
            guard enableResponseValidation else { return true }
            
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                _ = try decoder.decode(responseType, from: data)
                return true
            } catch {
                print("Response validation failed: \(error)")
                return false
            }
        }
        
        // Helper function to check current configuration
        static func printCurrentConfiguration() async {
            let hasAPIKey = getAuthToken() != nil
            let hasJWT = await getJWTToken() != nil
            let authSource = getAuthTokenSource()
            let authUserId = await getCurrentAuthUserId()

            print("🔧 Runaway Coach API Configuration:")
            print("   Current URL: \(currentBaseURL)")
            print("   Production URL: \(baseURL)")
            print("   Development URL: \(devBaseURL)")
            print("   Environment Override: \(ProcessInfo.processInfo.environment["RUNAWAY_API_URL"] ?? "None")")
            print("   🔐 JWT Authentication: \(hasJWT ? "✅ Available" : "❌ Not Available")")
            print("   🔐 API Key Fallback: \(hasAPIKey ? "✅ Configured" : "❌ Not Configured")")
            print("   🔐 Auth Source: \(authSource)")
            print("   👤 Current Auth User ID: \(authUserId ?? "None")")
            #if DEBUG
            print("   Build Mode: DEBUG")
            #else
            print("   Build Mode: RELEASE")
            #endif
        }

        // Synchronous version for backwards compatibility
        static func printCurrentConfigurationSync() {
            let hasAuth = getAuthToken() != nil
            let authSource = getAuthTokenSource()

            print("🔧 Runaway Coach API Configuration (Sync):")
            print("   Current URL: \(currentBaseURL)")
            print("   🔐 API Key Authentication: \(hasAuth ? "✅ Configured" : "❌ Not Configured")")
            print("   🔐 Auth Source: \(authSource)")
        }
        
        private static func getAuthTokenSource() -> String {
            if ProcessInfo.processInfo.environment["RUNAWAY_API_KEY"] != nil {
                return "Environment Variable"
            } else if Bundle.main.infoDictionary?["RUNAWAY_API_KEY"] as? String != nil {
                return "Info.plist"
            } else if hardcodedAPIKey != nil {
                return "Hardcoded (Not Recommended)"
            } else {
                return "None"
            }
        }
    }
    
    // MARK: - RSS Feeds
    
    struct RSSFeeds {
        static let runnersWorld = "https://www.runnersworld.com/rss/"
        static let runningMagazine = "https://runningmagazine.ca/feed/"
        static let outsideRunning = "https://www.outsideonline.com/rss/running/"
        static let competitorMagazine = "https://www.competitor.com/feed/"
        static let runnersTribe = "https://runnerstribe.com/feed/"
    }
    
    // MARK: - Configuration Validation
    
    static var hasNewsAPIKey: Bool {
        return !newsAPIKey.isEmpty
    }
    
    static var hasEventbriteAPIKey: Bool {
        return !eventbriteAPIKey.isEmpty
    }
    
    static var availableAPIs: [String] {
        var apis: [String] = ["RSS Feeds"] // Always available
        
        if hasNewsAPIKey {
            apis.append("NewsAPI")
        }
        
        if hasEventbriteAPIKey {
            apis.append("Eventbrite")
        }
        
        return apis
    }
}

// MARK: - Setup Instructions
extension APIConfiguration {
    static var setupInstructions: String {
        return """
        To enable real API integration, add the following keys to your Info.plist:
        
        1. NEWS_API_KEY (Free at newsapi.org):
           - Sign up at https://newsapi.org/
           - Get your free API key
           - Add to Info.plist as "NEWS_API_KEY"
        
        2. EVENTBRITE_API_KEY (Free at eventbrite.com):
           - Sign up at https://www.eventbrite.com/platform/api/
           - Create an app and get your API key
           - Add to Info.plist as "EVENTBRITE_API_KEY"
        
        Without these keys, the app will fall back to RSS feeds and mock data.
        """
    }
}