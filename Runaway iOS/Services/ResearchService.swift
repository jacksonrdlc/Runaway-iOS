//
//  ResearchService.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 6/28/25.
//

import Foundation
import CoreLocation

class ResearchService: ObservableObject {
    @Published var isLoading = false
    @Published var articles: [ResearchArticle] = []
    @Published var lastUpdated: Date?
    @Published var errorMessage: String?
    
    private let webSearchService = WebSearchService()
    private let contentScraper = ContentScraper()
    private let cache: NSCache<NSString, NSData> = {
        let cache = NSCache<NSString, NSData>()
        cache.countLimit = 100 // Maximum 100 cached items
        cache.totalCostLimit = 50_000_000 // 50MB memory limit
        return cache
    }()
    private let cacheTimeout: TimeInterval = 3600 // 1 hour
    
    // MARK: - Public Methods
    
    func fetchResearchArticles(params: ResearchSearchParams) async -> ResearchServiceResult {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        let startTime = Date()
        var allArticles: [ResearchArticle] = []
        var errors: [ResearchServiceError] = []
        
        // Try to load from cache first
        if let cachedArticles = loadFromCache(params: params) {
            await MainActor.run {
                self.articles = cachedArticles
                self.isLoading = false
                self.lastUpdated = Date()
            }
            return ResearchServiceResult(
                articles: cachedArticles,
                totalFound: cachedArticles.count,
                searchDuration: Date().timeIntervalSince(startTime),
                lastUpdated: Date(),
                errors: []
            )
        }
        
        // Fetch from web search and RSS feeds (no API keys required)
        do {
            for category in params.categories {
                let location = params.userLocation != nil ? extractLocationString(from: params.userLocation!) : nil
                let searchArticles = await webSearchService.searchArticles(for: category, location: location)
                allArticles.append(contentsOf: searchArticles)
                
                // Also get RSS feed articles for additional content
                let rssArticles = await fetchFromRSSFeeds(category: category, params: params)
                allArticles.append(contentsOf: rssArticles)
            }
        } catch {
            errors.append(.networkError(error.localizedDescription))
        }
        
        // Remove duplicates and sort by relevance and date
        allArticles = removeDuplicates(allArticles)
        allArticles = sortByRelevance(allArticles, params: params)
        allArticles = Array(allArticles.prefix(params.maxArticles))
        
        // Cache the results
        cacheArticles(allArticles, params: params)
        
        await MainActor.run {
            self.articles = allArticles
            self.isLoading = false
            self.lastUpdated = Date()
            if !errors.isEmpty {
                self.errorMessage = errors.first?.errorDescription
            }
        }
        
        return ResearchServiceResult(
            articles: allArticles,
            totalFound: allArticles.count,
            searchDuration: Date().timeIntervalSince(startTime),
            lastUpdated: Date(),
            errors: errors
        )
    }
    
    // MARK: - RSS Feed Integration (No API Keys Required)
    
    private func fetchFromRSSFeeds(category: ArticleCategory, params: ResearchSearchParams) async -> [ResearchArticle] {
        let rssFeeds = getRSSFeedsForCategory(category)
        var articles: [ResearchArticle] = []
        
        for feed in rssFeeds {
            do {
                let feedArticles = try await parseRSSFeed(url: feed.url, source: feed.name, category: category)
                articles.append(contentsOf: feedArticles.prefix(3)) // Limit per feed
            } catch {
                print("RSS feed error for \(feed.name): \(error)")
            }
        }
        
        return articles
    }
    
    private func extractLocationString(from location: CLLocation) -> String {
        // Simple location string for search queries
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        return "\(lat),\(lon)"
    }
    
    // Enhanced content scraping for better article details
    private func enhanceArticleWithScrapedContent(_ article: ResearchArticle) async -> ResearchArticle {
        guard let scrapedContent = await contentScraper.scrapeArticleContent(from: article.url) else {
            return article
        }
        
        // Return enhanced article with scraped content
        return ResearchArticle(
            title: scrapedContent.title.isEmpty ? article.title : scrapedContent.title,
            summary: scrapedContent.summary.isEmpty ? article.summary : scrapedContent.summary,
            content: scrapedContent.content,
            url: article.url,
            imageUrl: scrapedContent.imageUrl ?? article.imageUrl,
            author: scrapedContent.author ?? article.author,
            publishedDate: scrapedContent.publishDate ?? article.publishedDate,
            source: article.source,
            category: article.category,
            tags: article.tags,
            location: article.location,
            relevanceScore: article.relevanceScore
        )
    }
    
    private func parseRSSFeed(url: String, source: String, category: ArticleCategory) async throws -> [ResearchArticle] {
        guard let feedURL = URL(string: url) else {
            throw ResearchServiceError.networkError("Invalid RSS URL")
        }
        
        print("Fetching RSS feed from: \(url)")
        
        let (data, response) = try await URLSession.shared.data(from: feedURL)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            print("RSS feed error: Invalid response from \(url)")
            throw ResearchServiceError.networkError("Failed to fetch RSS feed")
        }
        
        let parser = RSSParser()
        let rssItems = try parser.parse(data)
        
        let articles = rssItems.compactMap { item -> ResearchArticle? in
            // Intelligently categorize based on content
            let detectedCategory = detectCategoryFromContent(
                title: item.title ?? "",
                description: item.description ?? ""
            )
            
            return ResearchArticle(
                title: item.title ?? "Untitled",
                summary: cleanHTMLFromDescription(item.description) ?? "No summary available",
                content: nil,
                url: item.link ?? "",
                imageUrl: extractImageFromDescription(item.description),
                author: item.author,
                publishedDate: item.pubDate ?? Date(),
                source: source,
                category: detectedCategory,
                tags: [],
                location: nil,
                relevanceScore: 0.8
            )
        }
        
        return articles
    }
    
    
    private func cleanHTMLFromDescription(_ description: String?) -> String? {
        guard let desc = description else { return nil }
        
        // Remove HTML tags and decode HTML entities
        let cleanedText = desc
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleanedText.isEmpty ? nil : cleanedText
    }
    
    
    
    
    
    // MARK: - Mock Data Generation (for demo)
    
    private func generateMockArticles(for category: ArticleCategory, keyword: String, count: Int) -> [ResearchArticle] {
        let mockTitles = getMockTitles(for: category)
        let mockSummaries = getMockSummaries(for: category)
        // Use real article URLs that actually exist
        let realArticleUrls = [
            ("Runner's World", "https://www.runnersworld.com/training/a20860831/how-to-start-running/"),
            ("Runner's World", "https://www.runnersworld.com/nutrition/a20845996/what-to-eat-before-a-run/"),
            ("Running Magazine", "https://runningmagazine.ca/sections/training/how-to-start-running/"),
            ("Running Magazine", "https://runningmagazine.ca/sections/nutrition/what-to-eat-before-running/"),
            ("iRunFar", "https://www.irunfar.com/trail-running-for-beginners"),
            ("Marathon Handbook", "https://marathonhandbook.com/how-to-start-running/"),
            ("Runners Connect", "https://runnersconnect.net/training/beginners/how-to-start-running/")
        ]
        
        return (0..<count).map { index in
            let source = realArticleUrls.randomElement() ?? ("Running News", "https://runningmagazine.ca")
            
            // Use real article URLs that actually work
            let realUrl = source.1
            
            return ResearchArticle(
                title: mockTitles.randomElement() ?? "Running Article",
                summary: mockSummaries.randomElement() ?? "Interesting running content.",
                content: nil,
                url: realUrl, // Use homepage URL instead of fake article URL
                imageUrl: "https://picsum.photos/400/250?random=\(UUID().uuidString)",
                author: ["John Smith", "Sarah Johnson", "Mike Rodriguez", "Lisa Chen"].randomElement(),
                publishedDate: randomDateWithinDays(days: 7),
                source: source.0,
                category: category,
                tags: category.searchKeywords.prefix(3).map { String($0) } + ["mock-data"], // Add mock-data tag
                location: nil,
                relevanceScore: Double.random(in: 0.7...1.0)
            )
        }
    }
    
    private func generateMockLocalEvents(userLocation: CLLocation, radiusMiles: Double) -> [ResearchArticle] {
        let eventTypes = ["5K Race", "10K Run", "Half Marathon", "Marathon", "Trail Run", "Fun Run"]
        let eventTitles = [
            "Annual City Marathon",
            "Charity 5K Fun Run", 
            "Trail Running Adventure",
            "Summer Solstice 10K",
            "Moonlight Half Marathon",
            "Corporate Challenge Run"
        ]
        
        return (0..<5).map { index in
            let randomDistance = Double.random(in: 5...radiusMiles)
            let randomBearing = Double.random(in: 0...360)
            let eventLocation = userLocation.coordinate.coordinateAtDistance(distance: randomDistance * 1609.34, bearing: randomBearing)
            
            return ResearchArticle(
                title: eventTitles.randomElement() ?? "Local Running Event",
                summary: "Join fellow runners in this exciting local event. Perfect for all skill levels!",
                content: nil,
                url: "https://example.com/event-\(UUID().uuidString)",
                imageUrl: "https://picsum.photos/400/250?random=event-\(UUID().uuidString)",
                author: "Event Organizer",
                publishedDate: randomDateWithinDays(days: 30, future: true),
                source: "Local Events",
                category: .events,
                tags: ["local", "race", "event", "mock-data"],
                location: ArticleLocation(
                    city: "Local City",
                    state: "State",
                    country: "US",
                    latitude: eventLocation.latitude,
                    longitude: eventLocation.longitude
                ),
                relevanceScore: 1.0
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func getMockTitles(for category: ArticleCategory) -> [String] {
        switch category {
        case .health:
            return [
                "5 Ways Running Improves Your Mental Health",
                "Preventing Common Running Injuries",
                "The Science Behind Runner's High",
                "How Running Strengthens Your Immune System"
            ]
        case .nutrition:
            return [
                "Best Pre-Run Snacks for Energy",
                "Hydration Strategies for Long Runs",
                "Post-Workout Recovery Foods",
                "Nutrition for Marathon Training"
            ]
        case .gear:
            return [
                "2024's Best Running Shoes Reviewed",
                "Essential Gear for Winter Running",
                "GPS Watch Comparison Guide",
                "Compression Gear: Worth the Hype?"
            ]
        case .events:
            return [
                "Upcoming Marathon Calendar",
                "Local 5K Series Announced",
                "Trail Running Championships",
                "Virtual Race Opportunities"
            ]
        case .training:
            return [
                "Beginner's Guide to Marathon Training",
                "Speed Work for Distance Runners", 
                "Building Running Endurance",
                "Recovery Techniques for Runners"
            ]
        case .general:
            return [
                "Running Community Spotlight",
                "Motivation Tips for Consistent Running",
                "Celebrity Runners and Their Routines",
                "Running Trends for 2024"
            ]
        }
    }
    
    private func getMockSummaries(for category: ArticleCategory) -> [String] {
        switch category {
        case .health:
            return [
                "Discover how regular running can boost your mental wellbeing and reduce stress levels.",
                "Learn about the most common running injuries and how to prevent them with proper technique.",
                "Explore the scientific basis behind the euphoric feeling many runners experience."
            ]
        case .nutrition:
            return [
                "Fuel your runs with these scientifically-backed nutrition strategies and snack ideas.",
                "Master your hydration game with expert tips for runs of any distance.",
                "Optimize your recovery with these post-run nutrition guidelines."
            ]
        case .gear:
            return [
                "Our comprehensive review of this year's top running shoes across all categories.",
                "Stay warm and safe during cold weather runs with this essential gear guide.",
                "Compare the latest GPS watches and find the perfect training companion."
            ]
        case .events:
            return [
                "Mark your calendar with these exciting upcoming running events in your area.",
                "Join the local running community with these regularly scheduled races.",
                "Challenge yourself with these trail running competitions."
            ]
        case .training:
            return [
                "Everything you need to know to train for your first marathon successfully.",
                "Incorporate speed work into your training with these expert-designed workouts.",
                "Build lasting endurance with these progressive training techniques."
            ]
        case .general:
            return [
                "Get inspired by amazing stories from the running community.",
                "Stay motivated and consistent with your running routine using these proven strategies.",
                "See how celebrities incorporate running into their fitness routines."
            ]
        }
    }
    
    private func randomDateWithinDays(days: Int, future: Bool = false) -> Date {
        let now = Date()
        let timeInterval = TimeInterval.random(in: 0...(TimeInterval(86400 * days))) // 86400 seconds in a day
        return future ? now.addingTimeInterval(timeInterval) : now.addingTimeInterval(-timeInterval)
    }
    
    private func removeDuplicates(_ articles: [ResearchArticle]) -> [ResearchArticle] {
        var seen = Set<String>()
        return articles.filter { article in
            let key = article.title.lowercased()
            if seen.contains(key) {
                return false
            } else {
                seen.insert(key)
                return true
            }
        }
    }
    
    private func sortByRelevance(_ articles: [ResearchArticle], params: ResearchSearchParams) -> [ResearchArticle] {
        return articles.sorted { first, second in
            // Prioritize local events
            if first.isLocalEvent && !second.isLocalEvent { return true }
            if !first.isLocalEvent && second.isLocalEvent { return false }
            
            // Then by relevance score
            if first.relevanceScore != second.relevanceScore {
                return first.relevanceScore > second.relevanceScore
            }
            
            // Finally by date
            return first.publishedDate > second.publishedDate
        }
    }
    
    // MARK: - Caching
    
    private func cacheKey(for params: ResearchSearchParams) -> String {
        let categoriesString = params.categories.map { $0.rawValue }.joined(separator: ",")
        let locationString = params.userLocation?.coordinate != nil ? 
            "\(params.userLocation!.coordinate.latitude),\(params.userLocation!.coordinate.longitude)" : "no-location"
        return "research-\(categoriesString)-\(locationString)-\(params.radiusMiles)"
    }
    
    private func loadFromCache(params: ResearchSearchParams) -> [ResearchArticle]? {
        let key = cacheKey(for: params)
        guard let data = cache.object(forKey: NSString(string: key)) as Data?,
              let articles = try? JSONDecoder().decode([ResearchArticle].self, from: data) else {
            return nil
        }
        
        // Check if cache is still valid
        let cacheAge = Date().timeIntervalSince(articles.first?.createdAt ?? Date.distantPast)
        if cacheAge > cacheTimeout {
            cache.removeObject(forKey: NSString(string: key))
            return nil
        }
        
        return articles
    }
    
    private func cacheArticles(_ articles: [ResearchArticle], params: ResearchSearchParams) {
        let key = cacheKey(for: params)
        if let data = try? JSONEncoder().encode(articles) {
            cache.setObject(data as NSData, forKey: NSString(string: key))
        }
    }
    
    // MARK: - RSS Feed Configuration
    
    private func getRSSFeedsForCategory(_ category: ArticleCategory) -> [RSSFeed] {
        // Get all available RSS feeds and categorize them intelligently
        let allFeeds = [
            RSSFeed(name: "Runner's World", url: "https://www.runnersworld.com/rss/all.xml"),
            RSSFeed(name: "Running Magazine", url: "https://runningmagazine.ca/feed/"),
            RSSFeed(name: "iRunFar", url: "https://www.irunfar.com/feed"),
            RSSFeed(name: "Outside Running", url: "https://www.outsideonline.com/category/running/feed/"),
            RSSFeed(name: "Women's Running", url: "https://womensrunning.com/feed/")
        ]
        
        // Return all feeds for better content diversity
        // Articles will be categorized based on content keywords
        return allFeeds
    }
    
    // MARK: - Helper Functions
    
    private func detectCategoryFromContent(title: String, description: String) -> ArticleCategory {
        let content = (title + " " + description).lowercased()
        
        // Health & Wellness keywords
        let healthKeywords = ["injury", "health", "wellness", "recovery", "pain", "stretching", "therapy", "medical", "doctor", "prevention", "treatment", "healing", "physio"]
        if healthKeywords.contains(where: { content.contains($0) }) {
            return .health
        }
        
        // Nutrition keywords
        let nutritionKeywords = ["nutrition", "diet", "food", "fuel", "hydration", "eating", "meal", "snack", "supplement", "vitamin", "protein", "carb", "electrolyte"]
        if nutritionKeywords.contains(where: { content.contains($0) }) {
            return .nutrition
        }
        
        // Gear & Equipment keywords
        let gearKeywords = ["shoe", "gear", "equipment", "watch", "gps", "apparel", "clothing", "tech", "review", "test", "product", "brand", "model"]
        if gearKeywords.contains(where: { content.contains($0) }) {
            return .gear
        }
        
        // Events & Races keywords
        let eventKeywords = ["race", "marathon", "5k", "10k", "half", "event", "calendar", "registration", "results", "finish", "medal", "virtual"]
        if eventKeywords.contains(where: { content.contains($0) }) {
            return .events
        }
        
        // Training keywords
        let trainingKeywords = ["training", "workout", "plan", "schedule", "speed", "tempo", "interval", "technique", "form", "coaching", "tips"]
        if trainingKeywords.contains(where: { content.contains($0) }) {
            return .training
        }
        
        // Default to general
        return .general
    }
    
    private func calculateRelevanceScore(title: String?, description: String?, keyword: String) -> Double {
        var score = 0.7 // Base score
        
        let titleMatch = title?.lowercased().contains(keyword.lowercased()) ?? false
        let descriptionMatch = description?.lowercased().contains(keyword.lowercased()) ?? false
        
        if titleMatch { score += 0.2 }
        if descriptionMatch { score += 0.1 }
        
        return min(score, 1.0)
    }
    
    private func extractImageFromDescription(_ description: String?) -> String? {
        guard let desc = description else { return nil }
        
        // Simple regex to extract image URLs from HTML content
        let pattern = #"<img[^>]+src="([^"]*)"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(desc.startIndex..<desc.endIndex, in: desc)
        
        if let match = regex?.firstMatch(in: desc, options: [], range: range) {
            if let urlRange = Range(match.range(at: 1), in: desc) {
                return String(desc[urlRange])
            }
        }
        
        return nil
    }
}

// MARK: - NewsAPI Data Models
struct NewsAPIResponse: Codable {
    let status: String
    let totalResults: Int
    let articles: [NewsAPIArticle]
}

struct NewsAPIArticle: Codable {
    let source: NewsAPISource?
    let author: String?
    let title: String?
    let description: String?
    let url: String?
    let urlToImage: String?
    let publishedAt: Date?
    let content: String?
    
    enum CodingKeys: String, CodingKey {
        case source, author, title, description, url, urlToImage, publishedAt, content
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        source = try container.decodeIfPresent(NewsAPISource.self, forKey: .source)
        author = try container.decodeIfPresent(String.self, forKey: .author)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        urlToImage = try container.decodeIfPresent(String.self, forKey: .urlToImage)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        
        // Custom date parsing
        if let dateString = try container.decodeIfPresent(String.self, forKey: .publishedAt) {
            let formatter = ISO8601DateFormatter()
            publishedAt = formatter.date(from: dateString)
        } else {
            publishedAt = nil
        }
    }
}

struct NewsAPISource: Codable {
    let id: String?
    let name: String
}

// MARK: - Eventbrite Data Models
struct EventbriteResponse: Codable {
    let events: [EventbriteEvent]
}

struct EventbriteEvent: Codable {
    let name: EventbriteText?
    let description: EventbriteHTML?
    let url: String?
    let start: EventbriteDateTime?
    let end: EventbriteDateTime?
    let logo: EventbriteLogo?
    let venue: EventbriteVenue?
}

struct EventbriteText: Codable {
    let text: String?
    let html: String?
}

struct EventbriteHTML: Codable {
    let text: String?
    let html: String?
}

struct EventbriteDateTime: Codable {
    let timezone: String?
    let local: Date?
    let utc: Date?
    
    enum CodingKeys: String, CodingKey {
        case timezone, local, utc
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timezone = try container.decodeIfPresent(String.self, forKey: .timezone)
        
        let formatter = ISO8601DateFormatter()
        
        if let localString = try container.decodeIfPresent(String.self, forKey: .local) {
            local = formatter.date(from: localString)
        } else {
            local = nil
        }
        
        if let utcString = try container.decodeIfPresent(String.self, forKey: .utc) {
            utc = formatter.date(from: utcString)
        } else {
            utc = nil
        }
    }
}

struct EventbriteLogo: Codable {
    let url: String?
}

struct EventbriteVenue: Codable {
    let address: EventbriteAddress?
    let latitude: String?
    let longitude: String?
}

struct EventbriteAddress: Codable {
    let city: String?
    let region: String?
    let country: String?
}

// MARK: - RSS Data Models
struct RSSFeed {
    let name: String
    let url: String
}

struct RSSItem {
    let title: String?
    let description: String?
    let link: String?
    let author: String?
    let pubDate: Date?
}

// MARK: - RSS Parser
class RSSParser: NSObject, XMLParserDelegate {
    private var items: [RSSItem] = []
    private var currentItem: RSSItem?
    private var currentElement: String?
    private var currentText: String = ""
    
    func parse(_ data: Data) throws -> [RSSItem] {
        items.removeAll()
        let parser = XMLParser(data: data)
        parser.delegate = self
        
        print("Starting RSS XML parsing...")
        
        guard parser.parse() else {
            if let error = parser.parserError {
                print("RSS parsing error: \(error.localizedDescription)")
                throw ResearchServiceError.parsingError("XML parsing failed: \(error.localizedDescription)")
            } else {
                print("RSS parsing failed with unknown error")
                throw ResearchServiceError.parsingError("Failed to parse RSS feed")
            }
        }
        
        print("RSS parsing completed successfully. Items found: \(items.count)")
        return items
    }
    
    // MARK: - XMLParserDelegate
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        currentText = ""
        
        if elementName == "item" {
            currentItem = RSSItem(title: nil, description: nil, link: nil, author: nil, pubDate: nil)
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        defer { currentElement = nil }
        
        guard var item = currentItem else { return }
        
        switch elementName {
        case "title":
            item = RSSItem(title: currentText.trimmingCharacters(in: .whitespacesAndNewlines),
                          description: item.description,
                          link: item.link,
                          author: item.author,
                          pubDate: item.pubDate)
        case "description", "content:encoded", "summary":
            item = RSSItem(title: item.title,
                          description: currentText.trimmingCharacters(in: .whitespacesAndNewlines),
                          link: item.link,
                          author: item.author,
                          pubDate: item.pubDate)
        case "link", "guid":
            let linkText = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            // Only use as link if it looks like a URL
            if linkText.hasPrefix("http") {
                item = RSSItem(title: item.title,
                              description: item.description,
                              link: linkText,
                              author: item.author,
                              pubDate: item.pubDate)
            }
        case "author", "dc:creator", "creator":
            item = RSSItem(title: item.title,
                          description: item.description,
                          link: item.link,
                          author: currentText.trimmingCharacters(in: .whitespacesAndNewlines),
                          pubDate: item.pubDate)
        case "pubDate":
            let dateText = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
            var date = formatter.date(from: dateText)
            
            // Try alternative date formats if first one fails
            if date == nil {
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                date = formatter.date(from: dateText)
            }
            if date == nil {
                formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
                date = formatter.date(from: dateText)
            }
            
            item = RSSItem(title: item.title,
                          description: item.description,
                          link: item.link,
                          author: item.author,
                          pubDate: date ?? Date())
        case "item":
            if item.title != nil || item.description != nil {
                items.append(item)
            }
            currentItem = nil
            return
        default:
            break
        }
        
        currentItem = item
    }
}

// MARK: - CLLocationCoordinate2D Extension
extension CLLocationCoordinate2D {
    func coordinateAtDistance(distance: Double, bearing: Double) -> CLLocationCoordinate2D {
        let earthRadius = 6371000.0 // meters
        let bearingRadians = bearing * .pi / 180
        let latitudeRadians = latitude * .pi / 180
        let longitudeRadians = longitude * .pi / 180
        
        let newLatitudeRadians = asin(sin(latitudeRadians) * cos(distance / earthRadius) +
                                     cos(latitudeRadians) * sin(distance / earthRadius) * cos(bearingRadians))
        
        let newLongitudeRadians = longitudeRadians + atan2(sin(bearingRadians) * sin(distance / earthRadius) * cos(latitudeRadians),
                                                          cos(distance / earthRadius) - sin(latitudeRadians) * sin(newLatitudeRadians))
        
        return CLLocationCoordinate2D(
            latitude: newLatitudeRadians * 180 / .pi,
            longitude: newLongitudeRadians * 180 / .pi
        )
    }
}
