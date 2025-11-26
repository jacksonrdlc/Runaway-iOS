//
//  ResearchView.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 6/28/25.
//

import SwiftUI
import CoreLocation

struct ResearchView: View {
    @StateObject private var researchService = ResearchService()
    @ObservedObject private var locationManager = LocationManager.shared
    @State private var selectedCategory: ArticleCategory? = nil
    @State private var selectedArticle: ResearchArticle?
    @State private var showingArticle = false
    @State private var filteredArticles: [ResearchArticle] = []
    
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
            AppTheme.Colors.background.ignoresSafeArea()
            
            ScrollView {
            LazyVStack(spacing: 0) {
                // Category Filter Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        CategoryPill(
                            title: "All",
                            count: researchService.articles.count,
                            isSelected: selectedCategory == nil,
                            action: { selectedCategory = nil }
                        )
                        
                        ForEach(ArticleCategory.allCases, id: \.self) { category in
                            let categoryCount = researchService.articles.filter { $0.category == category }.count
                            CategoryPill(
                                title: category.displayName,
                                count: categoryCount,
                                isSelected: selectedCategory == category,
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
                        ArticleCard(article: article) {
                            selectedArticle = article
                            showingArticle = true
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                    }
                } else if !researchService.isLoading {
                    EmptyStateView()
                        .padding()
                }
                
                // Last Updated
                if let lastUpdated = researchService.lastUpdated {
                    Text("Last updated: \(lastUpdated, formatter: RelativeDateTimeFormatter())")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .padding(.vertical)
                }
            }
        }
        .navigationTitle("Research")
        
        .navigationBarTitleDisplayMode(.large)
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
        .sheet(isPresented: $showingArticle) {
            if let article = selectedArticle {
                ArticleWebView(article: article)
            }
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
    let action: () -> Void
    
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
                        .foregroundColor(isSelected ? .black : AppTheme.Colors.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isSelected ? AppTheme.Colors.accent : AppTheme.Colors.textSecondary.opacity(AppTheme.Opacity.medium))
                        )
                }
            }
            .foregroundColor(isSelected ? .black : AppTheme.Colors.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? AppTheme.Colors.accent : AppTheme.Colors.cardBackground)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Article Card
struct ArticleCard: View {
    let article: ResearchArticle
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with category, mock indicator, and time
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

                Text(article.timeAgo)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            // Main content
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(article.title)
                        .font(AppTheme.Typography.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    Text(article.summary)
                        .font(AppTheme.Typography.subheadline)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    // Source and location info
                    HStack {
                        Text(article.source)
                            .font(AppTheme.Typography.caption)
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.Colors.textPrimary)

                        if let location = article.location, article.isLocalEvent {
                            Text("• \(location.displayLocation)")
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(AppTheme.Colors.textSecondary)
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
                            .fill(AppTheme.Colors.background)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(AppTheme.Colors.textTertiary)
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
                                .foregroundColor(AppTheme.Colors.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppTheme.Colors.background)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))
        .shadow(
            color: AppTheme.Shadows.light.color,
            radius: AppTheme.Shadows.light.radius,
            x: AppTheme.Shadows.light.x,
            y: AppTheme.Shadows.light.y
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
                .foregroundColor(AppTheme.Colors.textSecondary)
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
                .foregroundColor(AppTheme.Colors.textPrimary)

            Text(message)
                .font(AppTheme.Typography.subheadline)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            Button("Try Again", action: retryAction)
                .font(AppTheme.Typography.bodyBold)
                .foregroundColor(.black)
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
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "newspaper")
                .font(AppTheme.Typography.largeTitle)
                .foregroundColor(AppTheme.Colors.textTertiary)

            Text("No articles found")
                .font(AppTheme.Typography.headline)
                .foregroundColor(AppTheme.Colors.textPrimary)

            Text("Try adjusting your filters or check back later for new content.")
                .font(AppTheme.Typography.subheadline)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview {
    ResearchView()
}
