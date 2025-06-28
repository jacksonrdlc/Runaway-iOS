//
//  ContentScraper.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 6/28/25.
//

import Foundation

class ContentScraper {
    private let session = URLSession.shared
    private let cache = NSCache<NSString, ScrapedContent>()
    
    func scrapeArticleContent(from url: String) async -> ScrapedContent? {
        let cacheKey = url as NSString
        
        // Check cache first (6 hour expiry for content)
        if let cached = cache.object(forKey: cacheKey),
           Date().timeIntervalSince(cached.timestamp) < 21600 {
            return cached
        }
        
        guard let articleURL = URL(string: url) else { return nil }
        
        do {
            let (data, response) = try await session.data(from: articleURL)
            
            // Check if response is HTML
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let mimeType = httpResponse.mimeType,
                  mimeType.contains("text/html") else {
                return nil
            }
            
            guard let html = String(data: data, encoding: .utf8) else { return nil }
            
            let content = extractContentFromHTML(html, url: url)
            
            // Cache the result
            if let content = content {
                cache.setObject(content, forKey: cacheKey)
            }
            
            return content
            
        } catch {
            print("Failed to scrape content from \(url): \(error)")
            return nil
        }
    }
    
    private func extractContentFromHTML(_ html: String, url: String) -> ScrapedContent? {
        let title = extractTitle(from: html)
        let summary = extractSummary(from: html)
        let content = extractMainContent(from: html)
        let imageUrl = extractFeaturedImage(from: html, baseUrl: url)
        let publishDate = extractPublishDate(from: html)
        let author = extractAuthor(from: html)
        
        guard !title.isEmpty else { return nil }
        
        return ScrapedContent(
            title: title,
            summary: summary,
            content: content,
            imageUrl: imageUrl,
            publishDate: publishDate,
            author: author,
            url: url,
            timestamp: Date()
        )
    }
    
    private func extractTitle(from html: String) -> String {
        // Try multiple title extraction methods
        var title = ""
        
        // Method 1: <title> tag
        if let titleMatch = html.range(of: "<title[^>]*>([^<]+)</title>", options: .regularExpression) {
            let titleContent = String(html[titleMatch])
            title = titleContent.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        }
        
        // Method 2: Open Graph title
        if title.isEmpty {
            if let ogMatch = html.range(of: "<meta property=\"og:title\" content=\"([^\"]+)\"", options: .regularExpression) {
                let ogContent = String(html[ogMatch])
                if let contentStart = ogContent.range(of: "content=\"") {
                    let startIndex = ogContent.index(contentStart.upperBound, offsetBy: 0)
                    if let endIndex = ogContent.range(of: "\"", range: startIndex..<ogContent.endIndex) {
                        title = String(ogContent[startIndex..<endIndex.lowerBound])
                    }
                }
            }
        }
        
        // Method 3: h1 tag
        if title.isEmpty {
            if let h1Match = html.range(of: "<h1[^>]*>([^<]+)</h1>", options: .regularExpression) {
                let h1Content = String(html[h1Match])
                title = h1Content.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            }
        }
        
        return cleanText(title)
    }
    
    private func extractSummary(from html: String) -> String {
        var summary = ""
        
        // Method 1: Meta description
        if let descMatch = html.range(of: "<meta name=\"description\" content=\"([^\"]+)\"", options: .regularExpression) {
            let descContent = String(html[descMatch])
            if let contentStart = descContent.range(of: "content=\"") {
                let startIndex = descContent.index(contentStart.upperBound, offsetBy: 0)
                if let endIndex = descContent.range(of: "\"", range: startIndex..<descContent.endIndex) {
                    summary = String(descContent[startIndex..<endIndex.lowerBound])
                }
            }
        }
        
        // Method 2: Open Graph description
        if summary.isEmpty {
            if let ogMatch = html.range(of: "<meta property=\"og:description\" content=\"([^\"]+)\"", options: .regularExpression) {
                let ogContent = String(html[ogMatch])
                if let contentStart = ogContent.range(of: "content=\"") {
                    let startIndex = ogContent.index(contentStart.upperBound, offsetBy: 0)
                    if let endIndex = ogContent.range(of: "\"", range: startIndex..<ogContent.endIndex) {
                        summary = String(ogContent[startIndex..<endIndex.lowerBound])
                    }
                }
            }
        }
        
        // Method 3: First paragraph after headline
        if summary.isEmpty {
            let paragraphs = extractParagraphs(from: html)
            if let firstParagraph = paragraphs.first, firstParagraph.count > 50 {
                summary = String(firstParagraph.prefix(200)) + "..."
            }
        }
        
        return cleanText(summary)
    }
    
    private func extractMainContent(from html: String) -> String {
        let paragraphs = extractParagraphs(from: html)
        
        // Filter out short paragraphs and combine into content
        let meaningfulParagraphs = paragraphs.filter { $0.count > 50 }
        let content = meaningfulParagraphs.prefix(5).joined(separator: "\n\n")
        
        return cleanText(content)
    }
    
    private func extractParagraphs(from html: String) -> [String] {
        var paragraphs: [String] = []
        
        // Extract all <p> tags
        let pTagPattern = "<p[^>]*>([^<]*(?:<[^/][^>]*>[^<]*</[^>]*>[^<]*)*)</p>"
        let regex = try? NSRegularExpression(pattern: pTagPattern, options: .caseInsensitive)
        let range = NSRange(location: 0, length: html.count)
        
        regex?.enumerateMatches(in: html, options: [], range: range) { match, _, _ in
            if let match = match, let range = Range(match.range, in: html) {
                let pContent = String(html[range])
                let cleanContent = pContent.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                if !cleanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    paragraphs.append(cleanContent.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        }
        
        return paragraphs
    }
    
    private func extractFeaturedImage(from html: String, baseUrl: String) -> String? {
        var imageUrl: String?
        
        // Method 1: Open Graph image
        if let ogMatch = html.range(of: "<meta property=\"og:image\" content=\"([^\"]+)\"", options: .regularExpression) {
            let ogContent = String(html[ogMatch])
            if let contentStart = ogContent.range(of: "content=\"") {
                let startIndex = ogContent.index(contentStart.upperBound, offsetBy: 0)
                if let endIndex = ogContent.range(of: "\"", range: startIndex..<ogContent.endIndex) {
                    imageUrl = String(ogContent[startIndex..<endIndex.lowerBound])
                }
            }
        }
        
        // Method 2: First img tag with substantial size
        if imageUrl == nil {
            let imgPattern = "<img[^>]+src=\"([^\"]+)\"[^>]*>"
            let regex = try? NSRegularExpression(pattern: imgPattern, options: .caseInsensitive)
            let range = NSRange(location: 0, length: html.count)
            
            regex?.enumerateMatches(in: html, options: [], range: range) { match, _, _ in
                if let match = match, imageUrl == nil {
                    if let srcRange = Range(match.range(at: 1), in: html) {
                        let src = String(html[srcRange])
                        
                        // Filter out small icons, logos, or tracking pixels
                        if !src.contains("icon") && !src.contains("logo") && !src.contains("pixel") {
                            imageUrl = src
                        }
                    }
                }
            }
        }
        
        // Convert relative URLs to absolute
        if let url = imageUrl, !url.hasPrefix("http") {
            if let baseURL = URL(string: baseUrl) {
                imageUrl = URL(string: url, relativeTo: baseURL)?.absoluteString
            }
        }
        
        return imageUrl
    }
    
    private func extractPublishDate(from html: String) -> Date? {
        // Try to extract publish date from various meta tags
        let datePatterns = [
            "<meta property=\"article:published_time\" content=\"([^\"]+)\"",
            "<meta name=\"publishdate\" content=\"([^\"]+)\"",
            "<meta name=\"date\" content=\"([^\"]+)\"",
            "<time[^>]+datetime=\"([^\"]+)\""
        ]
        
        for pattern in datePatterns {
            if let match = html.range(of: pattern, options: .regularExpression) {
                let matchContent = String(html[match])
                if let contentStart = matchContent.range(of: "content=\"") ?? matchContent.range(of: "datetime=\"") {
                    let startIndex = matchContent.index(contentStart.upperBound, offsetBy: 0)
                    if let endIndex = matchContent.range(of: "\"", range: startIndex..<matchContent.endIndex) {
                        let dateString = String(matchContent[startIndex..<endIndex.lowerBound])
                        
                        // Try to parse the date
                        let iso8601Formatter = ISO8601DateFormatter()
                        if let date = iso8601Formatter.date(from: dateString) {
                            return date
                        }
                        
                        let dateFormatters = [
                            createDateFormatter("yyyy-MM-dd'T'HH:mm:ssZ"),
                            createDateFormatter("yyyy-MM-dd"),
                            createDateFormatter("MMM dd, yyyy")
                        ]
                        
                        for formatter in dateFormatters {
                            if let date = formatter.date(from: dateString) {
                                return date
                            }
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    private func createDateFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }
    
    private func extractAuthor(from html: String) -> String? {
        let authorPatterns = [
            "<meta name=\"author\" content=\"([^\"]+)\"",
            "<meta property=\"article:author\" content=\"([^\"]+)\"",
            "<span[^>]*class=\"[^\"]*author[^\"]*\"[^>]*>([^<]+)</span>",
            "<div[^>]*class=\"[^\"]*author[^\"]*\"[^>]*>([^<]+)</div>"
        ]
        
        for pattern in authorPatterns {
            if let match = html.range(of: pattern, options: .regularExpression) {
                let matchContent = String(html[match])
                
                if let contentStart = matchContent.range(of: "content=\"") {
                    let startIndex = matchContent.index(contentStart.upperBound, offsetBy: 0)
                    if let endIndex = matchContent.range(of: "\"", range: startIndex..<matchContent.endIndex) {
                        return cleanText(String(matchContent[startIndex..<endIndex.lowerBound]))
                    }
                } else {
                    // For span/div content
                    let authorText = matchContent.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    let cleanAuthor = cleanText(authorText)
                    if !cleanAuthor.isEmpty {
                        return cleanAuthor
                    }
                }
            }
        }
        
        return nil
    }
    
    private func cleanText(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Data Model
class ScrapedContent {
    let title: String
    let summary: String
    let content: String
    let imageUrl: String?
    let publishDate: Date?
    let author: String?
    let url: String
    let timestamp: Date
    
    init(title: String, summary: String, content: String, imageUrl: String?, publishDate: Date?, author: String?, url: String, timestamp: Date) {
        self.title = title
        self.summary = summary
        self.content = content
        self.imageUrl = imageUrl
        self.publishDate = publishDate
        self.author = author
        self.url = url
        self.timestamp = timestamp
    }
}