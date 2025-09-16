//
//  PerformanceCache.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 9/14/25.
//

import Foundation

// MARK: - Performance Cache

class PerformanceCache {
    private let cache = NSCache<NSString, CachedValue>()

    static let shared = PerformanceCache()

    private init() {
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }

    func getValue<T>(forKey key: String) -> T? {
        guard let cachedValue = cache.object(forKey: key as NSString) else {
            return nil
        }

        // Check if value has expired
        if Date().timeIntervalSince(cachedValue.timestamp) > cachedValue.expirationInterval {
            cache.removeObject(forKey: key as NSString)
            return nil
        }

        return cachedValue.value as? T
    }

    func setValue<T>(_ value: T, forKey key: String, expirationInterval: TimeInterval = 300) {
        let cachedValue = CachedValue(value: value, expirationInterval: expirationInterval)
        cache.setObject(cachedValue, forKey: key as NSString)
    }

    func removeValue(forKey key: String) {
        cache.removeObject(forKey: key as NSString)
    }

    func clearAll() {
        cache.removeAllObjects()
    }

    // Cache key generators
    static func totalMilesKey(for activities: [Activity]) -> String {
        let hashValue = activities.map { "\($0.id)_\($0.distance ?? 0)" }.joined().hash
        return "total_miles_\(hashValue)"
    }

    static func weeklyVolumeKey(for activities: [Activity]) -> String {
        let hashValue = activities.map { "\($0.id)_\($0.start_date ?? 0)" }.joined().hash
        return "weekly_volume_\(hashValue)"
    }

    static func monthlyProgressKey(for activities: [Activity]) -> String {
        let currentMonth = Calendar.current.component(.month, from: Date())
        let currentYear = Calendar.current.component(.year, from: Date())
        let hashValue = activities.map { "\($0.id)_\($0.distance ?? 0)" }.joined().hash
        return "monthly_progress_\(currentYear)_\(currentMonth)_\(hashValue)"
    }
}

// MARK: - Cached Value Container

class CachedValue: NSObject {
    let value: Any
    let timestamp: Date
    let expirationInterval: TimeInterval

    init(value: Any, expirationInterval: TimeInterval = 300) {
        self.value = value
        self.timestamp = Date()
        self.expirationInterval = expirationInterval
        super.init()
    }
}

// MARK: - Activity Metrics Cache

class ActivityMetricsCache {
    private let cache = PerformanceCache.shared

    // Cache total miles calculation
    func getTotalMiles(for activities: [Activity]) -> Double? {
        let key = PerformanceCache.totalMilesKey(for: activities)
        return cache.getValue(forKey: key)
    }

    func cacheTotalMiles(_ totalMiles: Double, for activities: [Activity]) {
        let key = PerformanceCache.totalMilesKey(for: activities)
        cache.setValue(totalMiles, forKey: key, expirationInterval: 600) // 10 minutes
    }

    // Cache weekly volume calculation
    func getWeeklyVolume(for activities: [Activity]) -> [WeeklyVolume]? {
        let key = PerformanceCache.weeklyVolumeKey(for: activities)
        return cache.getValue(forKey: key)
    }

    func cacheWeeklyVolume(_ weeklyVolume: [WeeklyVolume], for activities: [Activity]) {
        let key = PerformanceCache.weeklyVolumeKey(for: activities)
        cache.setValue(weeklyVolume, forKey: key, expirationInterval: 1800) // 30 minutes
    }

    // Cache monthly progress calculation
    func getMonthlyProgress(for activities: [Activity]) -> (current: Double, target: Double, total: Double)? {
        let key = PerformanceCache.monthlyProgressKey(for: activities)
        return cache.getValue(forKey: key)
    }

    func cacheMonthlyProgress(current: Double, target: Double, total: Double, for activities: [Activity]) {
        let key = PerformanceCache.monthlyProgressKey(for: activities)
        let progress = (current: current, target: target, total: total)
        cache.setValue(progress, forKey: key, expirationInterval: 3600) // 1 hour
    }

    // Invalidate all activity-related caches
    func invalidateActivityCaches() {
        // Since we can't iterate through NSCache, we'll clear all caches
        // This could be optimized with a custom cache implementation
        cache.clearAll()
    }
}