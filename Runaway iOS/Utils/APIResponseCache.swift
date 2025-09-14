//
//  APIResponseCache.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 7/16/25.
//

import Foundation

// MARK: - API Response Caching

class APIResponseCache {
    private static let cache = NSCache<NSString, CachedResponse>()
    
    static func getCachedResponse(for key: String) -> CachedResponse? {
        return cache.object(forKey: key as NSString)
    }
    
    static func setCachedResponse(_ response: CachedResponse, for key: String) {
        cache.setObject(response, forKey: key as NSString)
    }
    
    static func isResponseValid(_ response: CachedResponse) -> Bool {
        return Date().timeIntervalSince(response.timestamp) < APIConfiguration.RunawayCoach.cacheTimeout
    }
    
    static func clearCache() {
        cache.removeAllObjects()
    }
    
    static func removeExpiredEntries() {
        // Note: NSCache doesn't provide a way to iterate over entries
        // This would require a more sophisticated implementation with a custom cache
        // For now, we rely on NSCache's automatic eviction
    }
}

class CachedResponse: NSObject {
    let data: Data
    let timestamp: Date
    
    init(data: Data) {
        self.data = data
        self.timestamp = Date()
    }
}

// MARK: - API Request Builder

struct APIRequestBuilder {
    static func buildRequest(
        endpoint: String,
        method: HTTPMethod = .GET,
        body: Data? = nil
    ) -> URLRequest? {
        guard let url = URL(string: APIConfiguration.RunawayCoach.currentBaseURL + endpoint) else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = APIConfiguration.RunawayCoach.requestTimeout
        
        // Add headers
        for (key, value) in APIConfiguration.RunawayCoach.getAuthHeaders() {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Add body if provided
        if let body = body {
            request.httpBody = body
        }
        
        return request
    }
}

enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
}

// MARK: - API Health Monitor

class APIHealthMonitor: ObservableObject {
    @Published var isHealthy = false
    @Published var lastHealthCheck: Date?
    
    private let apiService = RunawayCoachAPIService()
    private var healthCheckTimer: Timer?
    
    func startMonitoring() {
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task {
                await self.checkHealth()
            }
        }
        
        // Initial check
        Task {
            await checkHealth()
        }
    }
    
    func stopMonitoring() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
    }
    
    @MainActor
    private func checkHealth() async {
        do {
            let health = try await apiService.healthCheck()
            isHealthy = health.status == "healthy"
            lastHealthCheck = Date()
        } catch {
            isHealthy = false
            lastHealthCheck = Date()
        }
    }
}