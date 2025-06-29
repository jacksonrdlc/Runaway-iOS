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
                        
                        // Insert video every 3 articles (only if video loads successfully)
                        if (index + 1) % 3 == 0 {
                            YouTubeVideoCard(
                                searchQuery: getSearchQueryForCategory(selectedCategory),
                                category: selectedCategory
                            )
                            .padding(.horizontal)
                            .padding(.bottom, 12)
                        }
                    }
                } else if !researchService.isLoading {
                    EmptyStateView()
                        .padding()
                }
                
                // Last Updated
                if let lastUpdated = researchService.lastUpdated {
                    Text("Last updated: \(lastUpdated, formatter: RelativeDateTimeFormatter())")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                if count > 0 {
                    Text("\(count)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(isSelected ? Color.blue.opacity(0.8) : Color.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isSelected ? Color.white.opacity(0.9) : Color.secondary.opacity(0.2))
                        )
                }
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.blue : Color(.systemGray6))
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
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text(article.category.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
                
                
                Spacer()
                
                Text(article.timeAgo)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Main content
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(article.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    
                    Text(article.summary)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    
                    // Source and location info
                    HStack {
                        Text(article.source)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        if let location = article.location, article.isLocalEvent {
                            Text("• \(location.displayLocation)")
                                .font(.caption)
                                .foregroundColor(.secondary)
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
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray6))
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.secondary)
                            )
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            
            // Tags
            if !article.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(article.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.systemGray6))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
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
            Text("Loading articles...")
                .font(.subheadline)
                .foregroundColor(.secondary)
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
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text("Unable to load articles")
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again", action: retryAction)
                .buttonStyle(.bordered)
        }
        .padding()
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "newspaper")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("No articles found")
                .font(.headline)
            
            Text("Try adjusting your filters or check back later for new content.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}


// MARK: - YouTube Video Card (Mixed with Articles)
struct YouTubeVideoCard: View {
    let searchQuery: String
    let category: ArticleCategory?
    
    @StateObject private var youtubeService = YouTubeService.shared
    @State private var video: YouTubeSearchResult?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if let video = video {
                VStack(alignment: .leading, spacing: 12) {
                    // Video Header
                    HStack {
                        Image(systemName: "play.rectangle.fill")
                            .foregroundColor(.red)
                            .font(.title3)
                        
                        Text("Video")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("YouTube")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Video content
                    HStack(spacing: 12) {
                        // Thumbnail
                        AsyncImage(url: URL(string: video.thumbnailUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(16/9, contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    Image(systemName: "play.circle.fill")
                                        .font(.title)
                                        .foregroundColor(.white)
                                )
                        }
                        .frame(width: 120, height: 67)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        
                        // Video details
                        VStack(alignment: .leading, spacing: 4) {
                            Text(video.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            
                            Text(video.channelName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                if !video.duration.isEmpty && video.duration != "N/A" {
                                    Text(video.duration)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if !video.viewCount.isEmpty && video.viewCount != "N/A" {
                                    Text(video.viewCount)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .onTapGesture {
                        openYouTubeVideo(video.videoId)
                    }
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.95),
                            Color.black.opacity(0.85),
                            Color(red: 0.1, green: 0.1, blue: 0.12).opacity(0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(12)
            } else if isLoading {
                // Show minimal loading indicator
                HStack {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Loading video...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            // If no video loads and not loading, show nothing (EmptyView)
        }
        .task {
            await loadVideo()
        }
    }
    
    private func loadVideo() async {
        isLoading = true
        
        // Use the real YouTube service to get a random video
        let result = await youtubeService.getRandomVideo(for: category, searchQuery: searchQuery)
        
        await MainActor.run {
            video = result
            isLoading = false
            // If result is nil, the card simply won't show (EmptyView)
        }
    }
    
    private func openYouTubeVideo(_ videoId: String) {
        let youtubeURL = URL(string: "https://www.youtube.com/watch?v=\(videoId)")!
        UIApplication.shared.open(youtubeURL)
    }
}

#Preview {
    ResearchView()
}
