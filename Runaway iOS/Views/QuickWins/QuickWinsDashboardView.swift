//
//  QuickWinsDashboardView.swift
//  Runaway iOS
//
//  Main dashboard for AI-powered Quick Wins insights
//

import SwiftUI

struct QuickWinsDashboardView: View {
    @StateObject private var viewModel = QuickWinsViewModel()
    @State private var selectedDetailView: DetailViewType?

    enum DetailViewType: Identifiable {
        case weather, vo2max, trainingLoad

        var id: String {
            switch self {
            case .weather: return "weather"
            case .vo2max: return "vo2max"
            case .trainingLoad: return "trainingLoad"
            }
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if viewModel.isLoading && !viewModel.hasData {
                        ProgressView("Loading insights...")
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else if let error = viewModel.error, !viewModel.hasData {
                        QuickWinsErrorView(error: error) {
                            Task { await viewModel.refresh() }
                        }
                    } else if let data = viewModel.quickWinsData, data.analyses.hasData {
                        // Quick Stats Carousel
                        QuickStatsCarousel(data: data)

                        // Priority Recommendations
                        if !data.priorityRecommendations.isEmpty {
                            PriorityRecommendationsBanner(recommendations: data.priorityRecommendations)
                        }

                        // Navigation Grid
                        NavigationCardsGrid(
                            data: data,
                            onWeatherTap: { selectedDetailView = .weather },
                            onVO2MaxTap: { selectedDetailView = .vo2max },
                            onTrainingLoadTap: { selectedDetailView = .trainingLoad }
                        )

                        // Last Updated
                        if let lastUpdated = viewModel.lastUpdated {
                            Text("Last updated: \(lastUpdated, formatter: dateFormatter)")
                                .font(.caption)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                                .padding(.top, 8)
                        }
                    } else {
                        QuickWinsEmptyStateView {
                            Task { await viewModel.loadData() }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Quick Wins")
            .toolbar {
                #if DEBUG
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.clearCache()
                        Task { await viewModel.refresh() }
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
                #endif
            }
            .refreshable {
                await viewModel.refresh()
            }
            .sheet(item: $selectedDetailView) { detailType in
                if let data = viewModel.quickWinsData {
                    switch detailType {
                    case .weather:
                        if let weather = data.analyses.weatherContext {
                            WeatherImpactView(weather: weather)
                        }
                    case .vo2max:
                        if let vo2max = data.analyses.vo2maxEstimate {
                            VO2MaxRacingView(vo2max: vo2max)
                        }
                    case .trainingLoad:
                        if let trainingLoad = data.analyses.trainingLoad {
                            TrainingLoadView(trainingLoad: trainingLoad)
                        }
                    }
                }
            }
            .task {
                await viewModel.loadData()
            }
        }
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
}

// MARK: - Quick Stats Carousel

struct QuickStatsCarousel: View {
    let data: QuickWinsResponse

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                // ACWR Card
                if let trainingLoad = data.analyses.trainingLoad {
                    QuickStatCard(
                        title: "ACWR",
                        value: String(format: "%.2f", trainingLoad.acwr),
                        subtitle: trainingLoad.acwrZone,
                        color: colorForACWR(trainingLoad.acwr),
                        icon: "chart.bar.fill"
                    )
                }

                // VO2 Max Card
                if let vo2max = data.analyses.vo2maxEstimate {
                    QuickStatCard(
                        title: "VO2 Max",
                        value: String(format: "%.1f", vo2max.vo2Max),
                        subtitle: vo2max.fitnessLevelDisplay,
                        color: colorForFitnessLevel(vo2max.fitnessLevel),
                        icon: "heart.fill"
                    )
                }

                // Temperature Card
                if let weather = data.analyses.weatherContext {
                    QuickStatCard(
                        title: "Avg Temp",
                        value: String(format: "%.1f°C", weather.averageTemperatureCelsius),
                        subtitle: "\(Int(weather.temperatureFahrenheit))°F",
                        color: colorForTemperature(weather.averageTemperatureCelsius),
                        icon: "thermometer"
                    )
                }

                // Weekly Volume Card
                if let trainingLoad = data.analyses.trainingLoad {
                    QuickStatCard(
                        title: "Weekly KM",
                        value: String(format: "%.1f", trainingLoad.totalVolumeKm),
                        subtitle: String(format: "%.1f mi", trainingLoad.totalVolumeMiles),
                        color: .blue,
                        icon: "figure.run"
                    )
                }
            }
            .padding(.horizontal)
        }
    }

    private func colorForACWR(_ acwr: Double) -> Color {
        if acwr < 0.8 { return .blue }
        else if acwr <= 1.3 { return .green }
        else if acwr <= 1.5 { return .orange }
        else { return .red }
    }

    private func colorForFitnessLevel(_ level: String) -> Color {
        switch level {
        case "elite": return .purple
        case "excellent": return .blue
        case "good": return .green
        case "average": return .orange
        default: return .gray
        }
    }

    private func colorForTemperature(_ temp: Double) -> Color {
        if temp < 15 { return .blue }
        else if temp < 20 { return .green }
        else if temp < 25 { return .orange }
        else { return .red }
    }
}

struct QuickStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(subtitle)
                .font(.caption)
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .frame(width: 140)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Priority Recommendations Banner

struct PriorityRecommendationsBanner: View {
    let recommendations: [String]
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Priority Recommendations")
                    .font(.headline)
                Spacer()
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }

            ForEach(Array(recommendations.prefix(isExpanded ? recommendations.count : 3).enumerated()), id: \.offset) { index, recommendation in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: recommendation.hasPrefix("✓") ? "checkmark.circle.fill" : "info.circle.fill")
                        .foregroundColor(recommendation.hasPrefix("✓") ? .green : .blue)
                        .font(.caption)

                    Text(recommendation)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()
                }
            }

            if !isExpanded && recommendations.count > 3 {
                Button(action: { isExpanded = true }) {
                    Text("See \(recommendations.count - 3) more")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5)
    }
}

// MARK: - Navigation Cards Grid

struct NavigationCardsGrid: View {
    let data: QuickWinsResponse
    let onWeatherTap: () -> Void
    let onVO2MaxTap: () -> Void
    let onTrainingLoadTap: () -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            if let weather = data.analyses.weatherContext {
                NavigationCard(
                    title: "Weather Impact",
                    subtitle: weather.weatherImpactScore.capitalized,
                    icon: "cloud.sun.fill",
                    color: colorForWeatherImpact(weather.weatherImpactScore),
                    action: onWeatherTap
                )
            }

            if let vo2max = data.analyses.vo2maxEstimate {
                NavigationCard(
                    title: "Race Predictions",
                    subtitle: "\(vo2max.racePredictions.count) Distances",
                    icon: "flag.fill",
                    color: .blue,
                    action: onVO2MaxTap
                )
            }

            if let trainingLoad = data.analyses.trainingLoad {
                NavigationCard(
                    title: "Training Load",
                    subtitle: trainingLoad.injuryRiskDisplay,
                    icon: "chart.line.uptrend.xyaxis",
                    color: colorForInjuryRisk(trainingLoad.injuryRiskLevel),
                    action: onTrainingLoadTap
                )

                NavigationCard(
                    title: "7-Day Plan",
                    subtitle: trainingLoad.trainingTrendDisplay,
                    icon: "calendar",
                    color: .purple,
                    action: onTrainingLoadTap // Opens training load view
                )
            }
        }
    }

    private func colorForWeatherImpact(_ score: String) -> Color {
        switch score {
        case "minimal": return .green
        case "moderate": return .orange
        case "significant": return .red
        case "severe": return .purple
        default: return .gray
        }
    }

    private func colorForInjuryRisk(_ risk: String) -> Color {
        switch risk {
        case "low": return .green
        case "moderate": return .orange
        case "high": return .red
        case "very_high": return .purple
        default: return .gray
        }
    }
}

struct NavigationCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                    Spacer()
                }

                Text(title)
                    .font(.headline)
                    .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(color.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Quick Wins Error View

struct QuickWinsErrorView: View {
    let error: QuickWinsError
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)

            Text("Error Loading Insights")
                .font(.headline)

            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: retry) {
                Label("Retry", systemImage: "arrow.clockwise")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

// MARK: - Quick Wins Empty State View

struct QuickWinsEmptyStateView: View {
    let action: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 50))
                .foregroundColor(AppTheme.Colors.textSecondary)

            Text("No Insights Available")
                .font(.headline)

            Text("Complete more runs to get AI-powered insights and recommendations.")
                .font(.subheadline)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: action) {
                Label("Load Data", systemImage: "arrow.clockwise")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
}

// MARK: - Preview

struct QuickWinsDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        QuickWinsDashboardView()
    }
}
