//
//  ResearchView.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 6/28/25.
//

import SwiftUI
import CoreLocation

struct ResearchView: View {
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
                ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.background : AppTheme.Colors.LightMode.background,
                ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.cardBackground : AppTheme.Colors.LightMode.cardBackground,
                ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary,
                ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary,
                ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textTertiary : AppTheme.Colors.LightMode.textTertiary,
                ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.surfaceBackground : AppTheme.Colors.LightMode.surfaceBackground
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
    
    private func getSearchQueryForCategory(_ category: ArticleCategory?) -> String {
        guard let category = category else { return "running tips" }
        
        switch category {
        case .health:
            return "running injury prevention"
        case .nutrition:
            return "running nutrition diet"
        case .gear:
            return "running shoes gear review"
        case .training:
            return "running training workout"
        case .events:
            return "marathon race preparation"
        case .general:
            return "running motivation tips"
        }
    }
    
    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()

            ScrollView {
            LazyVStack(spacing: 0) {
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
        .navigationTitle("Research")

        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(themeManager.isDarkMode ? .dark : .light, for: .navigationBar)
        .refreshable {
            await loadArticles()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    Task {
                        await loadArticles()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .rotationEffect(.degrees(researchService.isLoading ? 360 : 0))
                        .animation(researchService.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: researchService.isLoading)
                }
                .disabled(researchService.isLoading)
            }
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
        .onChange(of: selectedCategory) { _ in
            updateFilteredArticles()
        }
        .onAppear {
            updateFilteredArticles()
        }
        .sheet(item: $selectedArticle) { article in
            ArticleWebView(article: article)
        }
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

// MARK: - Category Pills
struct CategoryPill: View {
    let title: String
    let count: Int
    let isSelected: Bool
    var isDarkMode: Bool = false
    let action: () -> Void

    private var colors: (cardBg: Color, textPrimary: Color, textSecondary: Color) {
        if isDarkMode {
            return (
                AppTheme.Colors.DarkMode.cardBackground,
                AppTheme.Colors.DarkMode.textPrimary,
                AppTheme.Colors.DarkMode.textSecondary
            )
        } else {
            return (
                ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.cardBackground : AppTheme.Colors.LightMode.cardBackground,
                ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary,
                ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary
            )
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(AppTheme.Typography.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)

                if count > 0 {
                    Text("\(count)")
                        .font(AppTheme.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(isSelected ? .white : colors.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isSelected ? AppTheme.Colors.accent : colors.textSecondary.opacity(AppTheme.Opacity.medium))
                        )
                }
            }
            .foregroundColor(isSelected ? .white : colors.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? AppTheme.Colors.accent : colors.cardBg)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Article Card
struct ArticleCard: View {
    let article: ResearchArticle
    var isDarkMode: Bool = false
    let onTap: () -> Void

    private var colors: (cardBg: Color, textPrimary: Color, textSecondary: Color, textTertiary: Color, surface: Color) {
        if isDarkMode {
            return (
                AppTheme.Colors.DarkMode.cardBackground,
                AppTheme.Colors.DarkMode.textPrimary,
                AppTheme.Colors.DarkMode.textSecondary,
                AppTheme.Colors.DarkMode.textTertiary,
                AppTheme.Colors.DarkMode.surfaceBackground
            )
        } else {
            return (
                ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.cardBackground : AppTheme.Colors.LightMode.cardBackground,
                ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary,
                ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary,
                ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textTertiary : AppTheme.Colors.LightMode.textTertiary,
                ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.surfaceBackground : AppTheme.Colors.LightMode.surfaceBackground
            )
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        // Handle missing/invalid dates
        if article.publishedDate == Date.distantPast ||
           article.publishedDate.timeIntervalSince1970 < 0 {
            return ""
        }

        if calendar.isDateInToday(article.publishedDate) {
            return "Today"
        } else if calendar.isDateInYesterday(article.publishedDate) {
            return "Yesterday"
        } else if calendar.isDate(article.publishedDate, equalTo: Date(), toGranularity: .year) {
            formatter.dateFormat = "MMM d"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
        }
        return formatter.string(from: article.publishedDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with category and published date
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: article.category.iconName)
                        .foregroundColor(AppTheme.Colors.accent)
                        .font(AppTheme.Typography.caption)
                    Text(article.category.displayName)
                        .font(AppTheme.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.Colors.accent)
                }

                Spacer()

                Text(formattedDate)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(colors.textSecondary)
            }

            // Main content
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(article.title)
                        .font(AppTheme.Typography.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(colors.textPrimary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    Text(article.summary)
                        .font(AppTheme.Typography.subheadline)
                        .foregroundColor(colors.textSecondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    // Source and location info
                    HStack {
                        Text(article.source)
                            .font(AppTheme.Typography.caption)
                            .fontWeight(.medium)
                            .foregroundColor(colors.textPrimary)

                        if let location = article.location, article.isLocalEvent {
                            Text("• \(location.displayLocation)")
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(colors.textSecondary)
                        }

                        Spacer()
                    }
                }

                // Article image
                if let imageUrl = article.imageUrl {
                    AsyncImage(url: URL(string: imageUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                            .fill(colors.surface)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(colors.textTertiary)
                            )
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
                }
            }

            // Tags
            if !article.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(article.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(AppTheme.Typography.caption2)
                                .foregroundColor(colors.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(colors.surface)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding()
        .background(colors.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))
        .shadow(
            color: isDarkMode ? Color.black.opacity(0.3) : AppTheme.Shadows.light.color,
            radius: isDarkMode ? 8 : AppTheme.Shadows.light.radius,
            x: 0,
            y: isDarkMode ? 4 : AppTheme.Shadows.light.y
        )
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Loading View
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(AppTheme.Colors.accent)
            Text("Loading articles...")
                .font(AppTheme.Typography.subheadline)
                .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
        }
    }
}

// MARK: - Error View
struct ErrorView: View {
    let message: String
    let retryAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(AppTheme.Typography.largeTitle)
                .foregroundColor(AppTheme.Colors.warning)

            Text("Unable to load articles")
                .font(AppTheme.Typography.headline)
                .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary)

            Text(message)
                .font(AppTheme.Typography.subheadline)
                .foregroundColor(ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary)
                .multilineTextAlignment(.center)

            Button("Try Again", action: retryAction)
                .font(AppTheme.Typography.bodyBold)
                .foregroundColor(.white)
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.vertical, AppTheme.Spacing.sm)
                .background(AppTheme.Colors.accent)
                .cornerRadius(AppTheme.CornerRadius.medium)
        }
        .padding()
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    var isDarkMode: Bool = false

    private var colors: (textPrimary: Color, textSecondary: Color, textTertiary: Color) {
        if isDarkMode {
            return (
                AppTheme.Colors.DarkMode.textPrimary,
                AppTheme.Colors.DarkMode.textSecondary,
                AppTheme.Colors.DarkMode.textTertiary
            )
        } else {
            return (
                ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textPrimary : AppTheme.Colors.LightMode.textPrimary,
                ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textSecondary : AppTheme.Colors.LightMode.textSecondary,
                ThemeManager.shared.isDarkMode ? AppTheme.Colors.DarkMode.textTertiary : AppTheme.Colors.LightMode.textTertiary
            )
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "newspaper")
                .font(AppTheme.Typography.largeTitle)
                .foregroundColor(colors.textTertiary)

            Text("No articles found")
                .font(AppTheme.Typography.headline)
                .foregroundColor(colors.textPrimary)

            Text("Try adjusting your filters or check back later for new content.")
                .font(AppTheme.Typography.subheadline)
                .foregroundColor(colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview {
    ResearchView()
}
