//
//  UnifiedInsightsView.swift
//  Runaway iOS
//
//  Unified Insights view combining Quick Wins and Local Analysis
//

import SwiftUI

struct UnifiedInsightsView: View {
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var viewModel = UnifiedInsightsViewModel()
    @State private var selectedDetailView: DetailViewType?

    enum DetailViewType: Identifiable {
        case weather, vo2max, trainingLoad, activityTrends

        var id: String {
            switch self {
            case .weather: return "weather"
            case .vo2max: return "vo2max"
            case .trainingLoad: return "trainingLoad"
            case .activityTrends: return "activityTrends"
            }
        }
    }

    var body: some View {
        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()

            if dataManager.activities.isEmpty {
                EmptyInsightsStateView()
            } else if viewModel.isLoading && !viewModel.hasData {
                LoadingInsightsStateView()
            } else {
                ScrollView {
                    LazyVStack(spacing: AppTheme.Spacing.lg) {
                        // Section 1: Hero Stats Carousel
                        if viewModel.hasQuickWinsData {
                            HeroStatsSection(quickWinsData: viewModel.quickWinsData)
                        }

                        // Section 2: Priority Insights
                        if !viewModel.unifiedRecommendations.isEmpty || viewModel.performanceTrend != nil {
                            PriorityInsightsSection(
                                recommendations: viewModel.unifiedRecommendations,
                                performanceTrend: viewModel.performanceTrend
                            )
                        }

                        // Section 3: Performance at a Glance
                        PerformanceGlanceSection(
                            activities: dataManager.activities,
                            quickWinsData: viewModel.quickWinsData
                        )

                        // Section 4: Deep Dive Navigation
                        DeepDiveNavigationGrid(
                            quickWinsData: viewModel.quickWinsData,
                            onWeatherTap: { selectedDetailView = .weather },
                            onVO2MaxTap: { selectedDetailView = .vo2max },
                            onTrainingLoadTap: { selectedDetailView = .trainingLoad },
                            onActivityTrendsTap: { selectedDetailView = .activityTrends }
                        )

                        // Section 5: Charts & Analysis
                        ChartsSection(
                            activities: dataManager.activities,
                            weeklyData: viewModel.localAnalysis?.insights.weeklyVolume ?? []
                        )

                        // Section 6: Goal & Readiness
                        if dataManager.currentGoal != nil || viewModel.localAnalysis?.insights.goalReadiness != nil {
                            GoalReadinessSection(
                                activities: dataManager.activities,
                                goalReadiness: viewModel.localAnalysis?.insights.goalReadiness,
                                nextRunPrediction: viewModel.localAnalysis?.insights.nextRunPrediction
                            )
                        }
                    }
                    .padding(AppTheme.Spacing.md)
                }
            }
        }
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            #if DEBUG
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    Task {
                        await viewModel.refresh(activities: dataManager.activities)
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
            #endif
        }
        .refreshable {
            await viewModel.refresh(activities: dataManager.activities)
            await dataManager.refreshActivities()
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
                case .activityTrends:
                    ActivityTrendsView(activities: dataManager.activities)
                }
            } else if detailType == .activityTrends {
                ActivityTrendsView(activities: dataManager.activities)
            }
        }
        .task {
            await viewModel.loadAllData(activities: dataManager.activities)
        }
    }
}

// MARK: - Empty State

struct EmptyInsightsStateView: View {
    var body: some View {
        VStack(spacing: AppTheme.Spacing.xl) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 80))
                .foregroundColor(AppTheme.Colors.primary)

            VStack(spacing: AppTheme.Spacing.sm) {
                Text("No Insights Available")
                    .font(AppTheme.Typography.title)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Text("Start logging activities to see AI-powered insights and performance analytics.")
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(AppTheme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Loading State

struct LoadingInsightsStateView: View {
    @State private var animationPhase = 0.0

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            ZStack {
                Circle()
                    .stroke(AppTheme.Colors.cardBackground, lineWidth: 8)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(AppTheme.Colors.primary, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(animationPhase))
                    .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: animationPhase)
            }

            VStack(spacing: AppTheme.Spacing.sm) {
                Text("Loading Insights")
                    .font(AppTheme.Typography.title)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Text("Analyzing your performance data...")
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppTheme.Spacing.xxl)
        .onAppear {
            animationPhase = 360
        }
    }
}

// MARK: - Preview

struct UnifiedInsightsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            UnifiedInsightsView()
                .environmentObject(DataManager.shared)
        }
    }
}
