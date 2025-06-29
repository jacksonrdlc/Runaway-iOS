//
//  WebSearchService.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 6/28/25.
//

import Foundation

class WebSearchService {
    private let session = URLSession.shared
    private let cache: NSCache<NSString, CachedSearchResult> = {
        let cache = NSCache<NSString, CachedSearchResult>()
        cache.countLimit = 50 // Maximum 50 search results
        cache.totalCostLimit = 25_000_000 // 25MB memory limit
        return cache
    }()
    
    // Trusted running websites for content filtering
    private let trustedSources = [
        "runnersworld.com",
        "outsideonline.com", 
        "runningmagazine.ca",
        "podiumrunner.com",
        "womensrunning.com",
        "trailrunner.com",
        "active.com",
        "runnersconnect.net",
        "strengthrunning.com",
        "competitor.com"
    ]
    
    func searchArticles(for category: ArticleCategory, location: String? = nil) async -> [ResearchArticle] {
        let cacheKey = "\(category.rawValue)_\(location ?? "global")" as NSString
        
        // Check cache first (24 hour expiry)
        if let cached = cache.object(forKey: cacheKey),
           Date().timeIntervalSince(cached.timestamp) < 86400 {
            return cached.articles
        }
        
        var allArticles: [ResearchArticle] = []
        let searchQueries = generateSearchQueries(for: category, location: location)
        
        for query in searchQueries {
            let searchResults = await performWebSearch(query: query)
            let articles = await extractArticlesFromSearchResults(searchResults, category: category)
            allArticles.append(contentsOf: articles)
        }
        
        // Remove duplicates and sort by relevance
        let uniqueArticles = removeDuplicateArticles(allArticles)
        let rankedArticles = rankArticlesByQuality(uniqueArticles)
        let finalArticles = Array(rankedArticles.prefix(10)) // Limit to top 10 per category
        
        // Cache the results
        let cachedResult = CachedSearchResult(articles: finalArticles, timestamp: Date())
        cache.setObject(cachedResult, forKey: cacheKey)
        
        return finalArticles
    }
    
    private func generateSearchQueries(for category: ArticleCategory, location: String?) -> [String] {
        let currentYear = Calendar.current.component(.year, from: Date())
        
        // Generate diverse queries that will produce articles for all categories
        let baseQueries = [
            "running tips \(currentYear)",
            "runner health and wellness",
            "marathon training nutrition",
            "running gear reviews \(currentYear)",
            "running events and races",
            "running injury prevention",
            "best running shoes gear",
            "running workout training plans",
            "runner diet and supplements",
            "running motivation community"
        ]
        
        // Add location-specific queries if available
        if let location = location {
            return baseQueries + [
                "running events near \(location)",
                "marathon races \(location) \(currentYear)",
                "running groups \(location)"
            ]
        }
        
        return baseQueries
    }
    
    private func performWebSearch(query: String) async -> [SearchResult] {
        // Use DuckDuckGo instant answers API (free, no key required)
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://html.duckduckgo.com/html/?q=\(encodedQuery)"
        
        guard let url = URL(string: urlString) else { return [] }
        
        do {
            let (data, _) = try await session.data(from: url)
            
            if let htmlString = String(data: data, encoding: .utf8) {
                return parseSearchResults(from: htmlString)
            }
        } catch {
            print("Search error for query '\(query)': \(error)")
        }
        
        return []
    }
    
    private func parseSearchResults(from html: String) -> [SearchResult] {
        var results: [SearchResult] = []
        
        // Parse DuckDuckGo HTML results
        let lines = html.components(separatedBy: .newlines)
        var currentTitle = ""
        var currentURL = ""
        var currentSnippet = ""
        
        for line in lines {
            // Extract title from result link
            if line.contains("result__a") && line.contains("href=") {
                if let titleRange = line.range(of: ">") {
                    let titleStart = line.index(after: titleRange.upperBound)
                    if let titleEnd = line.range(of: "</a>", range: titleStart..<line.endIndex) {
                        currentTitle = String(line[titleStart..<titleEnd.lowerBound])
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .replacingOccurrences(of: "&amp;", with: "&")
                    }
                }
                
                // Extract URL
                if let urlStart = line.range(of: "href=\"//"),
                   let urlEnd = line.range(of: "\"", range: urlStart.upperBound..<line.endIndex) {
                    currentURL = "https://" + String(line[urlStart.upperBound..<urlEnd.lowerBound])
                }
            }
            
            // Extract snippet
            if line.contains("result__snippet") {
                if let snippetStart = line.range(of: ">"),
                   let snippetEnd = line.range(of: "</span>", range: snippetStart.upperBound..<line.endIndex) {
                    currentSnippet = String(line[snippetStart.upperBound..<snippetEnd.lowerBound])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                }
                
                // Complete result when we have all components
                if !currentTitle.isEmpty && !currentURL.isEmpty {
                    let result = SearchResult(
                        title: currentTitle,
                        url: currentURL,
                        snippet: currentSnippet
                    )
                    results.append(result)
                    
                    // Reset for next result
                    currentTitle = ""
                    currentURL = ""
                    currentSnippet = ""
                }
            }
        }
        
        return results
    }
    
    private func extractArticlesFromSearchResults(_ searchResults: [SearchResult], category: ArticleCategory) async -> [ResearchArticle] {
        var articles: [ResearchArticle] = []
        
        for result in searchResults.prefix(5) { // Limit to top 5 per search query
            // Filter by trusted sources
            let domain = extractDomain(from: result.url)
            guard trustedSources.contains(where: { domain.contains($0) }) else { continue }
            
            // Intelligently categorize based on search result content
            let detectedCategory = detectCategoryFromContent(
                title: result.title,
                description: result.snippet
            )
            
            // Create article from search result
            let article = ResearchArticle(
                title: result.title,
                summary: result.snippet,
                url: result.url,
                imageUrl: nil, // Will be extracted during content scraping if needed
                publishedDate: Date(), // Assume recent for search results
                source: domain,
                category: detectedCategory
            )
            
            articles.append(article)
        }
        
        return articles
    }
    
    private func extractDomain(from url: String) -> String {
        guard let urlObj = URL(string: url) else { return "" }
        return urlObj.host ?? ""
    }
    
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
    
    private func removeDuplicateArticles(_ articles: [ResearchArticle]) -> [ResearchArticle] {
        var seen = Set<String>()
        return articles.filter { article in
            let key = article.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if seen.contains(key) {
                return false
            } else {
                seen.insert(key)
                return true
            }
        }
    }
    
    private func rankArticlesByQuality(_ articles: [ResearchArticle]) -> [ResearchArticle] {
        return articles.sorted { article1, article2 in
            let score1 = calculateQualityScore(for: article1)
            let score2 = calculateQualityScore(for: article2)
            return score1 > score2
        }
    }
    
    private func calculateQualityScore(for article: ResearchArticle) -> Int {
        var score = 0
        
        // Higher score for trusted sources
        let domain = extractDomain(from: article.url)
        if trustedSources.contains(where: { domain.contains($0) }) {
            score += 10
        }
        
        // Higher score for longer, more detailed titles
        if article.title.count > 50 {
            score += 5
        }
        
        // Higher score for articles with summaries
        if !article.summary.isEmpty && article.summary.count > 100 {
            score += 5
        }
        
        // Bonus for specific running-related keywords
        let runningKeywords = ["running", "marathon", "race", "training", "runner", "pace", "fitness"]
        let titleLower = article.title.lowercased()
        let summaryLower = article.summary.lowercased()
        
        for keyword in runningKeywords {
            if titleLower.contains(keyword) { score += 2 }
            if summaryLower.contains(keyword) { score += 1 }
        }
        
        return score
    }
}

// MARK: - Supporting Data Models
struct SearchResult {
    let title: String
    let url: String
    let snippet: String
}

class CachedSearchResult {
    let articles: [ResearchArticle]
    let timestamp: Date
    
    init(articles: [ResearchArticle], timestamp: Date) {
        self.articles = articles
        self.timestamp = timestamp
    }
}