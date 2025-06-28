//
//  ResearchModels.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 6/28/25.
//

import Foundation
import CoreLocation

// MARK: - Article Categories
enum ArticleCategory: String, CaseIterable, Codable {
    case health = "health"
    case nutrition = "nutrition"
    case gear = "gear"
    case events = "events"
    case training = "training"
    case general = "general"
    
    var displayName: String {
        switch self {
        case .health: return "Health & Wellness"
        case .nutrition: return "Nutrition & Diet"
        case .gear: return "Gear & Equipment"
        case .events: return "Events & Races"
        case .training: return "Training & Tips"
        case .general: return "General Running"
        }
    }
    
    var iconName: String {
        switch self {
        case .health: return "heart.fill"
        case .nutrition: return "leaf.fill"
        case .gear: return "shoe.fill"
        case .events: return "calendar"
        case .training: return "figure.run"
        case .general: return "newspaper"
        }
    }
    
    var searchKeywords: [String] {
        switch self {
        case .health:
            return ["running health", "runner wellness", "running injury prevention", "running recovery", "running medicine"]
        case .nutrition:
            return ["running nutrition", "runner diet", "running snacks", "pre-run food", "post-run nutrition", "hydration running"]
        case .gear:
            return ["running shoes", "running gear", "running equipment", "running apparel", "GPS watch", "running accessories"]
        case .events:
            return ["running races", "marathon", "5K", "10K", "half marathon", "running events", "trail running races"]
        case .training:
            return ["running training", "marathon training", "running tips", "running technique", "running workouts", "speed training"]
        case .general:
            return ["running", "jogging", "runners", "running community", "running motivation"]
        }
    }
}

// MARK: - Research Article
struct ResearchArticle: Identifiable, Codable {
    let id: UUID
    let title: String
    let summary: String
    let content: String?
    let url: String
    let imageUrl: String?
    let author: String?
    let publishedDate: Date
    let source: String
    let category: ArticleCategory
    let tags: [String]
    let location: ArticleLocation?
    let relevanceScore: Double
    let createdAt: Date
    
    init(title: String, summary: String, content: String? = nil, url: String, 
         imageUrl: String? = nil, author: String? = nil, publishedDate: Date, 
         source: String, category: ArticleCategory, tags: [String] = [], 
         location: ArticleLocation? = nil, relevanceScore: Double = 1.0) {
        self.id = UUID()
        self.title = title
        self.summary = summary
        self.content = content
        self.url = url
        self.imageUrl = imageUrl
        self.author = author
        self.publishedDate = publishedDate
        self.source = source
        self.category = category
        self.tags = tags
        self.location = location
        self.relevanceScore = relevanceScore
        self.createdAt = Date()
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: publishedDate, relativeTo: Date())
    }
    
    var isLocalEvent: Bool {
        return category == .events && location != nil
    }
}

// MARK: - Article Location
struct ArticleLocation: Codable {
    let city: String?
    let state: String?
    let country: String?
    let latitude: Double?
    let longitude: Double?
    
    var displayLocation: String {
        var components: [String] = []
        if let city = city { components.append(city) }
        if let state = state { components.append(state) }
        return components.joined(separator: ", ")
    }
    
    func distanceFrom(userLocation: CLLocation) -> Double? {
        guard let lat = latitude, let lon = longitude else { return nil }
        let articleLocation = CLLocation(latitude: lat, longitude: lon)
        return userLocation.distance(from: articleLocation) * 0.000621371 // Convert to miles
    }
}

// MARK: - Research Feed
struct ResearchFeed {
    let articles: [ResearchArticle]
    let lastUpdated: Date
    let categories: [ArticleCategory]
    
    var groupedByCategory: [ArticleCategory: [ResearchArticle]] {
        Dictionary(grouping: articles) { $0.category }
    }
    
    var recentArticles: [ResearchArticle] {
        let oneDayAgo = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return articles.filter { $0.publishedDate >= oneDayAgo }
            .sorted { $0.publishedDate > $1.publishedDate }
    }
    
    var localEvents: [ResearchArticle] {
        return articles.filter { $0.isLocalEvent }
            .sorted { $0.publishedDate > $1.publishedDate }
    }
}

// MARK: - Search Parameters
struct ResearchSearchParams {
    let categories: [ArticleCategory]
    let userLocation: CLLocation?
    let radiusMiles: Double
    let maxArticles: Int
    let daysBack: Int
    
    init(categories: [ArticleCategory] = ArticleCategory.allCases,
         userLocation: CLLocation? = nil,
         radiusMiles: Double = 50.0,
         maxArticles: Int = 50,
         daysBack: Int = 7) {
        self.categories = categories
        self.userLocation = userLocation
        self.radiusMiles = radiusMiles
        self.maxArticles = maxArticles
        self.daysBack = daysBack
    }
}

// MARK: - Research Service Result
struct ResearchServiceResult {
    let articles: [ResearchArticle]
    let totalFound: Int
    let searchDuration: TimeInterval
    let lastUpdated: Date
    let errors: [ResearchServiceError]
}

// MARK: - Research Service Errors
enum ResearchServiceError: LocalizedError {
    case networkError(String)
    case parsingError(String)
    case rateLimit
    case invalidLocation
    case noArticlesFound
    
    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network error: \(message)"
        case .parsingError(let message):
            return "Parsing error: \(message)"
        case .rateLimit:
            return "Rate limit exceeded. Please try again later."
        case .invalidLocation:
            return "Invalid location provided"
        case .noArticlesFound:
            return "No articles found matching your criteria"
        }
    }
}

// MARK: - News Sources
enum NewsSource: String, CaseIterable {
    case runnerworld = "runnersworld"
    case outsidemagazine = "outside"
    case runnersconnect = "runnersconnect"
    case general = "general"
    
    var displayName: String {
        switch self {
        case .runnerworld: return "Runner's World"
        case .outsidemagazine: return "Outside Magazine"
        case .runnersconnect: return "Runners Connect"
        case .general: return "General News"
        }
    }
    
    var baseUrl: String {
        switch self {
        case .runnerworld: return "https://www.runnersworld.com"
        case .outsidemagazine: return "https://www.outsideonline.com"
        case .runnersconnect: return "https://runnersconnect.net"
        case .general: return ""
        }
    }
}