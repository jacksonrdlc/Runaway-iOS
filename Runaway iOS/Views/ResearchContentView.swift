//
//  ResearchContentView.swift
//  Runaway iOS
//
//  Embeddable version of ResearchView for nesting inside PlanView
//

import SwiftUI
import CoreLocation

struct ResearchContentView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var researchService = ResearchService()
    @ObservedObject private var locationManager = LocationManager.shared
    @State private var selectedCategory: ArticleCategory? = nil
    @State private var selectedArticle: ResearchArticle?
    @State private var filteredArticles: [ResearchArticle] = []

    private var colors: (background: Color, cardBg: Color, textPrimary: Color, textSecondary: Color, textTertiary: Color, surface: Color) {
        if themeManager.isDarkMode {
            return (
                AppTheme.Colors.DarkMode.background,
                AppTheme.Colors.DarkMode.cardBackground,
                AppTheme.Colors.DarkMode.textPrimary,
                AppTheme.Colors.DarkMode.textSecondary,
                AppTheme.Colors.DarkMode.textTertiary,
                AppTheme.Colors.DarkMode.surfaceBackground
            )
        } else {
            return (
                AppTheme.Colors.LightMode.background,
                AppTheme.Colors.LightMode.cardBackground,
                AppTheme.Colors.LightMode.textPrimary,
                AppTheme.Colors.LightMode.textSecondary,
                AppTheme.Colors.LightMode.textTertiary,
                AppTheme.Colors.LightMode.surfaceBackground
            )
        }
    }

    private func updateFilteredArticles() {
        if let category = selectedCategory {
            filteredArticles = researchService.articles.filter { $0.category == category }
        } else {
            filteredArticles = researchService.articles
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Refresh button row
                HStack {
                    Spacer()
                    Button(action: {
                        Task {
                            await loadArticles()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                                .rotationEffect(.degrees(researchService.isLoading ? 360 : 0))
                                .animation(researchService.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: researchService.isLoading)
                            Text("Refresh")
                                .font(AppTheme.Typography.caption)
                        }
                        .foregroundColor(AppTheme.Colors.accent)
                    }
                    .disabled(researchService.isLoading)
                }
                .padding(.horizontal)
                .padding(.top, AppTheme.Spacing.sm)

                // Category Filter Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        CategoryPill(
                            title: "All",
                            count: researchService.articles.count,
                            isSelected: selectedCategory == nil,
                            isDarkMode: themeManager.isDarkMode,
                            action: { selectedCategory = nil }
                        )

                        ForEach(ArticleCategory.allCases, id: \.self) { category in
                            let categoryCount = researchService.articles.filter { $0.category == category }.count
                            CategoryPill(
                                title: category.displayName,
                                count: categoryCount,
                                isSelected: selectedCategory == category,
                                isDarkMode: themeManager.isDarkMode,
                                action: { selectedCategory = category }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)

                // Loading State
                if researchService.isLoading && researchService.articles.isEmpty {
                    LoadingView()
                        .frame(height: 200)
                }

                // Error Message
                if let errorMessage = researchService.errorMessage {
                    ErrorView(message: errorMessage) {
                        Task {
                            await loadArticles()
                        }
                    }
                    .padding()
                }

                // Mixed Articles and Videos
                if !filteredArticles.isEmpty {
                    ForEach(Array(filteredArticles.enumerated()), id: \.offset) { index, article in
                        ArticleCard(article: article, isDarkMode: themeManager.isDarkMode) {
                            selectedArticle = article
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                    }
                } else if !researchService.isLoading {
                    EmptyStateView(isDarkMode: themeManager.isDarkMode)
                        .padding()
                }

                // Last Updated
                if let lastUpdated = researchService.lastUpdated {
                    Text("Last updated: \(lastUpdated, formatter: RelativeDateTimeFormatter())")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(colors.textSecondary)
                        .padding(.vertical)
                }
            }
        }
        .refreshable {
            await loadArticles()
        }
        .task {
            await loadArticles()
        }
        .onReceive(locationManager.$location) { _ in
            Task {
                await loadArticles()
            }
        }
        .onReceive(researchService.$articles) { _ in
            updateFilteredArticles()
        }
        .onChange(of: selectedCategory) { _, _ in
            updateFilteredArticles()
        }
        .onAppear {
            updateFilteredArticles()
        }
        .sheet(item: $selectedArticle) { article in
            ArticleWebView(article: article)
        }
    }

    private func loadArticles() async {
        let searchParams = ResearchSearchParams(
            categories: ArticleCategory.allCases,
            userLocation: locationManager.location,
            radiusMiles: 50.0,
            maxArticles: 50,
            daysBack: 7
        )

        _ = await researchService.fetchResearchArticles(params: searchParams)
    }
}

#Preview {
    ResearchContentView()
        .environmentObject(ThemeManager.shared)
}
