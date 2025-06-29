//
//  YouTubeService.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 6/29/25.
//

import Foundation

class YouTubeService: ObservableObject {
    static let shared = YouTubeService()
    
    private let baseURL = "https://www.googleapis.com/youtube/v3"
    private let cache = NSCache<NSString, YouTubeCachedResult>()
    private var lastRequestTime: Date = Date.distantPast
    private let minRequestInterval: TimeInterval = 1.0 // Rate limiting: 1 second between requests
    
    private var apiKey: String {
        // Try multiple ways to get API key
        if let key = Bundle.main.object(forInfoDictionaryKey: "YOUTUBE_API_KEY") as? String {
            return key
        }
        if let key = ProcessInfo.processInfo.environment["YOUTUBE_API_KEY"] {
            return key
        }
        // Fallback for demo - replace with your actual API key
        return "AIzaSyAfEB6jgCsiEalyd3RYjWUXzWlbp4gO7vY"
    }
    
    private init() {
        cache.countLimit = 100
        cache.totalCostLimit = 10_000_000 // 10MB cache limit
    }
    
    // MARK: - Public Methods
    
    func searchVideos(for category: ArticleCategory?, customQuery: String? = nil, maxResults: Int = 10) async throws -> [YouTubeSearchResult] {
        let query = customQuery ?? getSearchQuery(for: category)
        let cacheKey = "\(query)_\(maxResults)" as NSString
        
        // Check cache first (1 hour TTL)
        if let cached = cache.object(forKey: cacheKey),
           Date().timeIntervalSince(cached.timestamp) < 3600 {
            return cached.results
        }
        
        // Rate limiting
        await enforceRateLimit()
        
        do {
            let searchResults = try await performSearch(query: query, maxResults: maxResults)
            let videoIds = searchResults.items.map { $0.id.videoId }
            let videoDetails = try await getVideoDetails(videoIds: videoIds)
            
            let results = combineSearchAndDetails(searchResults: searchResults.items, videoDetails: videoDetails.items)
            
            // Cache results
            let cachedResult = YouTubeCachedResult(results: results, timestamp: Date())
            cache.setObject(cachedResult, forKey: cacheKey)
            
            return results
        } catch {
            print("YouTube API error: \(error)")
            // No fallback - return empty array if API fails
            throw error
        }
    }
    
    func getRandomVideo(for category: ArticleCategory?, searchQuery: String? = nil) async -> YouTubeSearchResult? {
        do {
            let videos = try await searchVideos(for: category, customQuery: searchQuery, maxResults: 5)
            return videos.randomElement()
        } catch {
            print("Failed to get random video: \(error)")
            // Return nil if API fails - no fallback videos
            return nil
        }
    }
    
    // MARK: - Private Methods
    
    private func enforceRateLimit() async {
        let timeSinceLastRequest = Date().timeIntervalSince(lastRequestTime)
        if timeSinceLastRequest < minRequestInterval {
            let delay = minRequestInterval - timeSinceLastRequest
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        lastRequestTime = Date()
    }
    
    private func performSearch(query: String, maxResults: Int) async throws -> YouTubeSearchResponse {
        // API key validation - allow the configured key to work
        guard !apiKey.isEmpty else {
            throw YouTubeError.invalidAPIKey
        }
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "\(baseURL)/search?part=snippet&type=video&q=\(encodedQuery)&maxResults=\(maxResults)&key=\(apiKey)&order=relevance&videoDuration=medium&videoDefinition=high"
        
        guard let url = URL(string: urlString) else {
            throw YouTubeError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw YouTubeError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            let searchResponse = try JSONDecoder().decode(YouTubeSearchResponse.self, from: data)
            return searchResponse
        case 403:
            if let errorData = try? JSONDecoder().decode(YouTubeErrorResponse.self, from: data),
               let error = errorData.error.errors.first {
                if error.reason == "quotaExceeded" {
                    throw YouTubeError.quotaExceeded
                } else if error.reason == "keyInvalid" {
                    throw YouTubeError.invalidAPIKey
                }
            }
            throw YouTubeError.forbidden
        case 429:
            throw YouTubeError.rateLimitExceeded
        default:
            throw YouTubeError.requestFailed(httpResponse.statusCode)
        }
    }
    
    private func getVideoDetails(videoIds: [String]) async throws -> YouTubeVideoDetailsResponse {
        guard !videoIds.isEmpty else {
            return YouTubeVideoDetailsResponse(items: [])
        }
        
        let videoIdsString = videoIds.joined(separator: ",")
        let urlString = "\(baseURL)/videos?part=statistics,contentDetails&id=\(videoIdsString)&key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            throw YouTubeError.invalidURL
        }
        
        await enforceRateLimit()
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(YouTubeVideoDetailsResponse.self, from: data)
    }
    
    private func combineSearchAndDetails(searchResults: [YouTubeSearchItem], videoDetails: [YouTubeVideoDetails]) -> [YouTubeSearchResult] {
        let detailsDict = Dictionary(uniqueKeysWithValues: videoDetails.map { ($0.id, $0) })
        
        return searchResults.compactMap { searchItem in
            let details = detailsDict[searchItem.id.videoId]
            
            return YouTubeSearchResult(
                videoId: searchItem.id.videoId,
                title: searchItem.snippet.title,
                channelName: searchItem.snippet.channelTitle,
                thumbnailUrl: searchItem.snippet.thumbnails.medium?.url ?? searchItem.snippet.thumbnails.default.url,
                duration: formatDuration(details?.contentDetails.duration),
                viewCount: formatViewCount(details?.statistics.viewCount)
            )
        }
    }
    
    private func getSearchQuery(for category: ArticleCategory?) -> String {
        guard let category = category else { return "running tips motivation" }
        
        switch category {
        case .health:
            return "running injury prevention health tips"
        case .nutrition:
            return "running nutrition diet fuel hydration"
        case .gear:
            return "running shoes gear equipment review"
        case .training:
            return "running training workout technique"
        case .events:
            return "marathon race preparation strategy"
        case .general:
            return "running motivation tips beginner"
        }
    }
    
    private func formatDuration(_ duration: String?) -> String {
        guard let duration = duration else { return "N/A" }
        
        // Parse ISO 8601 duration format (PT4M13S = 4 minutes 13 seconds)
        let pattern = #"PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: duration, range: NSRange(duration.startIndex..., in: duration)) else {
            return "N/A"
        }
        
        let hours = match.range(at: 1).location != NSNotFound ? Int(String(duration[Range(match.range(at: 1), in: duration)!])) ?? 0 : 0
        let minutes = match.range(at: 2).location != NSNotFound ? Int(String(duration[Range(match.range(at: 2), in: duration)!])) ?? 0 : 0
        let seconds = match.range(at: 3).location != NSNotFound ? Int(String(duration[Range(match.range(at: 3), in: duration)!])) ?? 0 : 0
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private func formatViewCount(_ viewCount: String?) -> String {
        guard let viewCountString = viewCount, let count = Int(viewCountString) else {
            return "N/A"
        }
        
        if count >= 1_000_000 {
            let millions = Double(count) / 1_000_000
            return String(format: "%.1fM views", millions)
        } else if count >= 1_000 {
            let thousands = Double(count) / 1_000
            return String(format: "%.1fK views", thousands)
        } else {
            return "\(count) views"
        }
    }
    
}

// MARK: - Data Models

class YouTubeCachedResult {
    let results: [YouTubeSearchResult]
    let timestamp: Date
    
    init(results: [YouTubeSearchResult], timestamp: Date) {
        self.results = results
        self.timestamp = timestamp
    }
}

struct YouTubeSearchResponse: Codable {
    let items: [YouTubeSearchItem]
}

struct YouTubeSearchItem: Codable {
    let id: YouTubeVideoId
    let snippet: YouTubeSnippet
}

struct YouTubeVideoId: Codable {
    let videoId: String
}

struct YouTubeSnippet: Codable {
    let title: String
    let channelTitle: String
    let thumbnails: YouTubeThumbnails
}

struct YouTubeThumbnails: Codable {
    let `default`: YouTubeThumbnail
    let medium: YouTubeThumbnail?
    let high: YouTubeThumbnail?
}

struct YouTubeThumbnail: Codable {
    let url: String
}

struct YouTubeVideoDetailsResponse: Codable {
    let items: [YouTubeVideoDetails]
}

struct YouTubeVideoDetails: Codable {
    let id: String
    let statistics: YouTubeStatistics
    let contentDetails: YouTubeContentDetails
}

struct YouTubeStatistics: Codable {
    let viewCount: String?
}

struct YouTubeContentDetails: Codable {
    let duration: String
}

struct YouTubeErrorResponse: Codable {
    let error: YouTubeErrorDetails
}

struct YouTubeErrorDetails: Codable {
    let errors: [YouTubeErrorItem]
}

struct YouTubeErrorItem: Codable {
    let reason: String
    let message: String
}

// MARK: - Error Types

enum YouTubeError: Error, LocalizedError {
    case invalidAPIKey
    case quotaExceeded
    case rateLimitExceeded
    case invalidURL
    case invalidResponse
    case forbidden
    case requestFailed(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid YouTube API key. Please check your configuration."
        case .quotaExceeded:
            return "YouTube API quota exceeded. Please try again later."
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please slow down your requests."
        case .invalidURL:
            return "Invalid URL for YouTube API request."
        case .invalidResponse:
            return "Invalid response from YouTube API."
        case .forbidden:
            return "Access forbidden to YouTube API."
        case .requestFailed(let code):
            return "YouTube API request failed with status code: \(code)"
        }
    }
}
