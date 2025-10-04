//
//  QuickWinsViewModel.swift
//  Runaway iOS
//
//  ViewModel for Quick Wins Dashboard and detail views
//

import Foundation
import SwiftUI

@MainActor
class QuickWinsViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var quickWinsData: QuickWinsResponse?
    @Published var isLoading = false
    @Published var error: QuickWinsError?
    @Published var lastUpdated: Date?

    // MARK: - Private Properties

    private let service: QuickWinsService
    private let cacheKey = "QuickWinsCache"
    private let cacheTimestampKey = "QuickWinsCacheTimestamp"
    private let cacheValidityDuration: TimeInterval = 3600 // 1 hour

    // MARK: - Initialization

    init(service: QuickWinsService = QuickWinsService()) {
        self.service = service
        loadCachedData()
    }

    // MARK: - Public Methods

    /// Fetch comprehensive analysis from API
    func fetchComprehensiveAnalysis() async {
        isLoading = true
        error = nil

        do {
            let data = try await service.fetchComprehensiveAnalysis()
            self.quickWinsData = data
            self.lastUpdated = Date()
            cacheData(data)
            #if DEBUG
            print("✅ QuickWins: Fetched comprehensive analysis")
            #endif
        } catch let quickWinsError as QuickWinsError {
            self.error = quickWinsError
            #if DEBUG
            print("❌ QuickWins Error: \(quickWinsError.localizedDescription)")
            #endif
        } catch {
            self.error = .networkError(error)
            #if DEBUG
            print("❌ QuickWins Network Error: \(error.localizedDescription)")
            #endif
        }

        isLoading = false
    }

    /// Refresh data (for pull-to-refresh)
    func refresh() async {
        await fetchComprehensiveAnalysis()
    }

    /// Load data on app launch (use cache if valid)
    func loadData() async {
        if isCacheValid() {
            #if DEBUG
            print("📦 QuickWins: Using cached data")
            #endif
            return
        }

        await fetchComprehensiveAnalysis()
    }

    // MARK: - Cache Management

    private func loadCachedData() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cachedResponse = try? JSONDecoder().decode(QuickWinsResponse.self, from: data),
              let timestamp = UserDefaults.standard.object(forKey: cacheTimestampKey) as? Date
        else {
            return
        }

        self.quickWinsData = cachedResponse
        self.lastUpdated = timestamp

        #if DEBUG
        print("📦 QuickWins: Loaded cached data from \(timestamp)")
        #endif
    }

    private func cacheData(_ data: QuickWinsResponse) {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        UserDefaults.standard.set(encoded, forKey: cacheKey)
        UserDefaults.standard.set(Date(), forKey: cacheTimestampKey)
    }

    private func isCacheValid() -> Bool {
        guard let timestamp = UserDefaults.standard.object(forKey: cacheTimestampKey) as? Date else {
            return false
        }

        let age = Date().timeIntervalSince(timestamp)
        return age < cacheValidityDuration
    }

    func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: cacheTimestampKey)
        quickWinsData = nil
        lastUpdated = nil
    }

    // MARK: - Helper Methods

    var hasData: Bool {
        quickWinsData != nil
    }

    var errorMessage: String? {
        error?.localizedDescription
    }

    // Mock data for development
    func loadMockData() {
        quickWinsData = .mock
        lastUpdated = Date()
    }
}
