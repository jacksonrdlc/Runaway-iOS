//
//  ResearchService.swift
//  Runaway iOS
//
//  Pre-fetched articles from Supabase - no loading, instant display
//  Articles are fetched daily at 6 AM via cron job and stored in database
//

import Foundation
import CoreLocation

class ResearchService: ObservableObject {
    @Published var isLoading = false
    @Published var articles: [ResearchArticle] = []
    @Published var lastUpdated: Date?
    @Published var errorMessage: String?

    // Local cache for offline support
    private var cachedArticles: [ResearchArticle] = []
    private var lastFetchTime: Date?
    private let cacheTimeout: TimeInterval = 300 // 5 minutes (articles are pre-fetched in DB)

    // MARK: - Public Methods

    /// Fetch articles from Supabase database (pre-fetched by cron job)
    func fetchResearchArticles(params: ResearchSearchParams) async -> ResearchServiceResult {
        let startTime = Date()

        // Return cached if recent (within 5 min)
        if let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < cacheTimeout,
           !cachedArticles.isEmpty {
            await MainActor.run {
                self.articles = self.filterByCategory(cachedArticles, categories: params.categories)
                self.isLoading = false
            }
            return ResearchServiceResult(
                articles: articles,
                totalFound: articles.count,
                searchDuration: 0,
                lastUpdated: lastFetch,
                errors: []
            )
        }

        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            // Fetch from Supabase - articles are pre-populated by daily cron job
            let response: [ResearchArticleDB] = try await supabase
                .from("research_articles")
                .select()
                .eq("is_active", value: true)
                .gte("published_at", value: sevenDaysAgo())
                .order("published_at", ascending: false)
                .limit(params.maxArticles)
                .execute()
                .value

            let fetchedArticles = response.map { $0.toResearchArticle() }

            // Update cache
            cachedArticles = fetchedArticles
            lastFetchTime = Date()

            // Filter by requested categories
            let filteredArticles = filterByCategory(fetchedArticles, categories: params.categories)

            await MainActor.run {
                self.articles = filteredArticles
                self.isLoading = false
                self.lastUpdated = Date()
            }

            return ResearchServiceResult(
                articles: filteredArticles,
                totalFound: filteredArticles.count,
                searchDuration: Date().timeIntervalSince(startTime),
                lastUpdated: Date(),
                errors: []
            )

        } catch {
            print("Error fetching articles from Supabase: \(error)")

            // Fallback to cache if available
            if !cachedArticles.isEmpty {
                await MainActor.run {
                    self.articles = self.filterByCategory(cachedArticles, categories: params.categories)
                    self.isLoading = false
                    self.errorMessage = "Using cached articles"
                }
            } else {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Unable to load articles: \(error.localizedDescription)"
                }
            }

            return ResearchServiceResult(
                articles: articles,
                totalFound: articles.count,
                searchDuration: Date().timeIntervalSince(startTime),
                lastUpdated: lastFetchTime ?? Date(),
                errors: [.networkError(error.localizedDescription)]
            )
        }
    }

    // MARK: - Private Helpers

    private func sevenDaysAgo() -> String {
        let date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }

    private func filterByCategory(_ articles: [ResearchArticle], categories: [ArticleCategory]) -> [ResearchArticle] {
        guard !categories.isEmpty else { return articles }
        return articles.filter { article in
            categories.contains(article.category)
        }
    }
}

// MARK: - HTML Entity Decoding

private extension String {
    /// Decode HTML entities like &#8217; and &rsquo; to their actual characters
    func decodingHTMLEntities() -> String {
        var result = self

        // Decode numeric entities (&#8217; -> ')
        let numericPattern = /&#(\d+);/
        result = result.replacing(numericPattern) { match in
            if let codePoint = Int(match.1), let scalar = Unicode.Scalar(codePoint) {
                return String(Character(scalar))
            }
            return String(match.0)
        }

        // Decode hex entities (&#x2019; -> ')
        let hexPattern = /&#x([0-9A-Fa-f]+);/
        result = result.replacing(hexPattern) { match in
            if let codePoint = Int(match.1, radix: 16), let scalar = Unicode.Scalar(codePoint) {
                return String(Character(scalar))
            }
            return String(match.0)
        }

        // Decode named entities
        let namedEntities: [String: String] = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'",
            "&#39;": "'",
            "&nbsp;": " ",
            "&rsquo;": "'",
            "&lsquo;": "'",
            "&rdquo;": "\"",
            "&ldquo;": "\"",
            "&mdash;": "—",
            "&ndash;": "–",
            "&hellip;": "...",
            "&copy;": "©",
            "&reg;": "®",
            "&trade;": "™"
        ]

        for (entity, replacement) in namedEntities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }

        return result
    }
}

// MARK: - Database Model

/// Matches the Supabase research_articles table schema
private struct ResearchArticleDB: Codable {
    let id: String
    let title: String
    let summary: String?
    let content: String?
    let url: String
    let image_url: String?
    let author: String?
    let source: String
    let category: String
    let tags: [String]?
    let published_at: String?
    let fetched_at: String?
    let relevance_score: Double?
    let location_city: String?
    let location_state: String?
    let location_country: String?
    let location_latitude: Double?
    let location_longitude: Double?
    let is_local_event: Bool?

    func toResearchArticle() -> ResearchArticle {
        let articleCategory = ArticleCategory(rawValue: category) ?? .general

        var location: ArticleLocation?
        if let city = location_city {
            location = ArticleLocation(
                city: city,
                state: location_state,
                country: location_country,
                latitude: location_latitude,
                longitude: location_longitude
            )
        }

        let publishedDate: Date
        if let dateString = published_at {
            // Try multiple ISO8601 formats - Supabase may send with or without fractional seconds
            let formatterWithFractional = ISO8601DateFormatter()
            formatterWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            let formatterStandard = ISO8601DateFormatter()
            formatterStandard.formatOptions = [.withInternetDateTime]

            if let date = formatterWithFractional.date(from: dateString) {
                publishedDate = date
            } else if let date = formatterStandard.date(from: dateString) {
                publishedDate = date
            } else {
                // Fallback: try parsing with DateFormatter for other formats
                let fallbackFormatter = DateFormatter()
                fallbackFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                fallbackFormatter.timeZone = TimeZone(identifier: "UTC")
                publishedDate = fallbackFormatter.date(from: dateString) ?? Date.distantPast
            }
        } else {
            publishedDate = Date.distantPast
        }

        return ResearchArticle(
            title: title.decodingHTMLEntities(),
            summary: (summary ?? "").decodingHTMLEntities(),
            content: content?.decodingHTMLEntities(),
            url: url,
            imageUrl: image_url,
            author: author,
            publishedDate: publishedDate,
            source: source,
            category: articleCategory,
            tags: tags ?? [],
            location: location,
            relevanceScore: relevance_score ?? 0.8
        )
    }
}
