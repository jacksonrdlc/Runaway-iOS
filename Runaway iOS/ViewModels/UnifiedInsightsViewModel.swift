//
//  UnifiedInsightsViewModel.swift
//  Runaway iOS
//
//  Unified ViewModel combining Quick Wins and Local Analysis
//

import Foundation
import SwiftUI

@MainActor
class UnifiedInsightsViewModel: ObservableObject {
    // MARK: - Published Properties

    // Quick Wins Data
    @Published var quickWinsData: QuickWinsResponse?
    @Published var isLoadingQuickWins = false
    @Published var quickWinsError: QuickWinsError?

    // Local Analysis Data
    @Published var localAnalysis: AnalysisResults?
    @Published var isLoadingLocal = false

    // Training Journal Data
    @Published var currentJournal: TrainingJournal?
    @Published var isLoadingJournal = false
    @Published var journalError: JournalError?

    // Combined/Unified Data
    @Published var unifiedRecommendations: [String] = []
    @Published var lastUpdated: Date?

    // MARK: - Services

    private let quickWinsService: QuickWinsService
    private let localAnalyzer: RunningAnalyzer

    // MARK: - Initialization

    init(quickWinsService: QuickWinsService = QuickWinsService(),
         localAnalyzer: RunningAnalyzer = RunningAnalyzer()) {
        self.quickWinsService = quickWinsService
        self.localAnalyzer = localAnalyzer
    }

    // MARK: - Public Methods

    /// Load all data sources in parallel
    func loadAllData(activities: [Activity]) async {
        guard !activities.isEmpty else {
            #if DEBUG
            print("🔄 UnifiedInsights: No activities to analyze")
            #endif
            return
        }

        #if DEBUG
        print("🔄 UnifiedInsights: Loading all data sources")
        #endif

        // Load all data sources in parallel
        async let quickWinsTask = loadQuickWins()
        async let localTask = loadLocalAnalysis(activities: activities)
        async let journalTask = loadCurrentJournal()

        _ = await (quickWinsTask, localTask, journalTask)

        // Merge recommendations after both complete
        mergeRecommendations()
        lastUpdated = Date()

        #if DEBUG
        print("✅ UnifiedInsights: All data loaded")
        #endif
    }

    /// Refresh all data
    func refresh(activities: [Activity]) async {
        await loadAllData(activities: activities)
    }

    // MARK: - Private Methods

    private func loadQuickWins() async {
        isLoadingQuickWins = true
        quickWinsError = nil

        do {
            let data = try await quickWinsService.fetchComprehensiveAnalysis()
            self.quickWinsData = data

            #if DEBUG
            print("✅ UnifiedInsights: Quick Wins loaded")
            #endif
        } catch let error as QuickWinsError {
            self.quickWinsError = error
            #if DEBUG
            print("❌ UnifiedInsights: Quick Wins error: \(error.localizedDescription)")
            #endif
        } catch {
            self.quickWinsError = .networkError(error)
            #if DEBUG
            print("❌ UnifiedInsights: Quick Wins network error: \(error.localizedDescription)")
            #endif
        }

        isLoadingQuickWins = false
    }

    private func loadLocalAnalysis(activities: [Activity]) async {
        isLoadingLocal = true

        await localAnalyzer.analyzePerformance(activities: activities)
        self.localAnalysis = localAnalyzer.analysisResults

        isLoadingLocal = false

        #if DEBUG
        print("✅ UnifiedInsights: Local analysis completed")
        #endif
    }

    private func loadCurrentJournal() async {
        isLoadingJournal = true
        journalError = nil

        guard let athleteId = await DataManager.shared.athlete?.id else {
            #if DEBUG
            print("⚠️ UnifiedInsights: No athlete ID available for journal")
            #endif
            isLoadingJournal = false
            return
        }

        do {
            let journals = try await JournalService.getJournalEntries(athleteId: athleteId, limit: 1)
            self.currentJournal = journals.first

            #if DEBUG
            print("✅ UnifiedInsights: Journal loaded")
            #endif
        } catch let error as JournalError {
            self.journalError = error
            self.currentJournal = nil
            #if DEBUG
            print("❌ UnifiedInsights: Journal error: \(error.localizedDescription)")
            #endif
        } catch {
            self.journalError = .decodingFailed(error)
            self.currentJournal = nil
            #if DEBUG
            print("❌ UnifiedInsights: Journal error: \(error.localizedDescription)")
            #endif
        }

        isLoadingJournal = false
    }

    /// Merge recommendations from both sources
    private func mergeRecommendations() {
        var combined: [String] = []

        // Add Quick Wins priority recommendations (higher priority)
        if let qw = quickWinsData {
            combined.append(contentsOf: qw.priorityRecommendations)
        }

        // Add local AI recommendations
        if let local = localAnalysis {
            combined.append(contentsOf: local.insights.recommendations)
        }

        // Deduplicate and limit to top 6
        let uniqueRecommendations = Array(NSOrderedSet(array: combined)) as! [String]
        unifiedRecommendations = Array(uniqueRecommendations.prefix(6))

        #if DEBUG
        print("🔄 UnifiedInsights: Merged \(unifiedRecommendations.count) recommendations")
        #endif
    }

    // MARK: - Computed Properties

    var hasData: Bool {
        quickWinsData != nil || localAnalysis != nil
    }

    var hasQuickWinsData: Bool {
        quickWinsData?.analyses.hasData ?? false
    }

    var isLoading: Bool {
        isLoadingQuickWins || isLoadingLocal
    }

    var performanceTrend: PerformanceTrend? {
        localAnalysis?.insights.performanceTrend
    }

    var weeklyVolume: Double? {
        if let trainingLoad = quickWinsData?.analyses.trainingLoad {
            return trainingLoad.totalVolumeKm
        }
        return nil
    }

    var journalErrorMessage: String? {
        guard let error = journalError else { return nil }
        switch error {
        case .noEntriesFound:
            return nil // Not really an error, just no data
        case .invalidResponse, .httpError:
            return "Unable to connect to journal service. Please try again."
        case .apiError(_, let message):
            return "Journal error: \(message)"
        default:
            return "Failed to load training journal."
        }
    }
}
