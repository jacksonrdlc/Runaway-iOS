//
//  TrainingView.swift
//  Runaway iOS
//
//  Training view with streamlined hierarchy:
//  Action-first → Readiness → Progress → Details
//
//  Based on UX research for athletic apps:
//  - Eastern Peak fitness app best practices
//  - Output Sports athlete monitoring dashboards
//  - Strava case study by Samantha Marin
//

import SwiftUI

struct TrainingView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(AppRouter.self) private var router
    @StateObject private var viewModel = TrainingViewModel()
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
            Color.white.ignoresSafeArea()

            if dataManager.activities.isEmpty {
                EmptyInsightsStateView()
            } else if viewModel.isLoading && !viewModel.hasData {
                LoadingInsightsStateView()
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        // 1. Readiness Banner (glanceable, color-coded)
                        ReadinessBanner()

                        // 2. Today's Focus (most actionable - what to do NOW)
                        TodaysFocusCard()

                        // 3. Week Progress (compact, glanceable)
                        WeekProgressRow()

                        // 4. Coach Insight (AI differentiator)
                        CoachInsightCard(onAskCoach: navigateToCoach)

                        // 5. Key Metrics (3 metrics max)
                        KeyMetricsGrid(quickWinsData: viewModel.quickWinsData)

                        // 6. Trends Chart (single, expandable)
                        CompactTrendsChart(activities: dataManager.activities)

                        // 7. Explore (deep dives at bottom - progressive disclosure)
                        ExploreSection(
                            quickWinsData: viewModel.quickWinsData,
                            onWeatherTap: { selectedDetailView = .weather },
                            onVO2MaxTap: { selectedDetailView = .vo2max },
                            onTrainingLoadTap: { selectedDetailView = .trainingLoad },
                            onActivityTrendsTap: { selectedDetailView = .activityTrends }
                        )
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle("Training")
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
                        .foregroundColor(AppTheme.Colors.LightMode.accent)
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

    private func navigateToCoach() {
        // Navigate to Coach tab
        NotificationCenter.default.post(name: .navigateToCoachTab, object: nil)
    }
}

// MARK: - Notification for Coach Navigation

extension Notification.Name {
    static let navigateToCoachTab = Notification.Name("navigateToCoachTab")
}

// MARK: - Empty State

struct EmptyInsightsStateView: View {
    var body: some View {
        VStack(spacing: AppTheme.Spacing.xl) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 80))
                .foregroundColor(AppTheme.Colors.LightMode.accent)

            VStack(spacing: AppTheme.Spacing.sm) {
                Text("No Insights Available")
                    .font(AppTheme.Typography.title)
                    .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

                Text("Start logging activities to see AI-powered insights and performance analytics.")
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
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
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(AppTheme.Colors.LightMode.accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(animationPhase))
                    .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: animationPhase)
            }

            VStack(spacing: AppTheme.Spacing.sm) {
                Text("Loading Insights")
                    .font(AppTheme.Typography.title)
                    .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

                Text("Analyzing your performance data...")
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
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

struct TrainingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            TrainingView()
                .environmentObject(DataManager.shared)
        }
    }
}
