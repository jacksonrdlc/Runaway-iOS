//
//  APIConfiguration.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 6/28/25.
//

import Foundation

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