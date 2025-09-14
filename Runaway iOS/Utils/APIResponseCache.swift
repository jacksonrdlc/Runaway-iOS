//
//  APIResponseCache.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 7/16/25.
//

import Foundation

// MARK: - API Response Caching

class APIResponseCache {
    private static let cache: NSCache<NSString, CachedResponse> = {
        let cache = NSCache<NSString, CachedResponse>()
        cache.countLimit = 50 // Maximum 50 cached responses
        cache.totalCostLimit = 10 * 1024 * 1024 // 10MB limit
        return cache
    }()

    private static let cacheQueue = DispatchQueue(label: "api.response.cache", attributes: .concurrent)

    static func getCachedResponse(for key: String) -> CachedResponse? {
        return cacheQueue.sync {
            return cache.object(forKey: key as NSString)
        }
    }

    static func setCachedResponse(_ response: CachedResponse, for key: String) {
        cacheQueue.async(flags: .barrier) {
            cache.setObject(response, forKey: key as NSString)
        }
    }

    static func isResponseValid(_ response: CachedResponse) -> Bool {
        return Date().timeIntervalSince(response.timestamp) < APIConfiguration.RunawayCoach.cacheTimeout
    }

    static func clearCache() {
        cacheQueue.async(flags: .barrier) {
            cache.removeAllObjects()
        }
    }

    // Enhanced cache management
    static func removeExpiredEntries() {
        // Since NSCache doesn't provide enumeration, we'll periodically clear all entries
        // and let the natural request flow repopulate with fresh data
        cacheQueue.async(flags: .barrier) {
            cache.removeAllObjects()
        }
    }

    static func getCacheSize() -> (count: Int, cost: Int) {
        return cacheQueue.sync {
            return (count: cache.countLimit, cost: cache.totalCostLimit)
        }
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