//
//  AnalysisView.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 6/27/25.
//


import SwiftUI
import Charts
import Foundation

struct AnalysisView: View {
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var analyzer = RunningAnalyzer()
    
    var body: some View {
        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    RunningGoalCard(activities: dataManager.activities, goalReadiness: analyzer.analysisResults?.insights.goalReadiness)
                    
                    // Always show progress overview regardless of analysis state
                    ProgressOverviewCard(activities: dataManager.activities)
                    
                    if analyzer.isAnalyzing {
                        EnhancedAnalysisLoadingView()
                    } else if let results = analyzer.analysisResults {
                        AnalysisResultsView(results: results, activities: dataManager.activities)
                    } else {
                        EnhancedEmptyAnalysisView()
                    }
                }
                .padding(AppTheme.Spacing.md)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    Task {
                        await analyzer.analyzePerformance(activities: dataManager.activities)
                    }
                }) {
                    HStack(spacing: AppTheme.Spacing.xs) {
                        Image(systemName: AppIcons.analyze)
                        Text("Analyze")
                            .font(AppTheme.Typography.caption)
                    }
                    .foregroundColor(analyzer.isAnalyzing ? AppTheme.Colors.mutedText : AppTheme.Colors.primary)
                }
                .disabled(analyzer.isAnalyzing)
            }
        }
        .onAppear {
            if analyzer.analysisResults == nil && !dataManager.activities.isEmpty {
                Task {
                    await analyzer.analyzePerformance(activities: dataManager.activities)
                }
            }
        }
    }
}

struct EnhancedAnalysisLoadingView: View {
    @State private var animationPhase = 0.0
    
    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            ZStack {
                Circle()
                    .stroke(AppTheme.Colors.cardBackground, lineWidth: 8)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(AppTheme.Colors.primaryGradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(animationPhase))
                    .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: animationPhase)
                
                Image(systemName: AppIcons.analyze)
                    .font(.title2)
                    .foregroundColor(AppTheme.Colors.primary)
            }
            
            VStack(spacing: AppTheme.Spacing.sm) {
                Text("Analyzing Performance")
                    .font(AppTheme.Typography.title)
                    .foregroundColor(AppTheme.Colors.primaryText)
                
                Text("Training ML models and generating insights from your running data")
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.secondaryText)
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

struct EnhancedEmptyAnalysisView: View {
    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.primaryGradient)
                    .frame(width: 120, height: 120)
                    .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 20, x: 0, y: 10)
                
                Image(systemName: AppIcons.analysis)
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: AppTheme.Spacing.sm) {
                Text("Ready to Analyze")
                    .font(AppTheme.Typography.title)
                    .foregroundColor(AppTheme.Colors.primaryText)
                
                Text("Tap 'Analyze' to generate AI insights and discover patterns in your running performance")
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
            }
            
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                FeatureItem(icon: "brain.head.profile", text: "AI-powered performance analysis")
                FeatureItem(icon: "chart.line.uptrend.xyaxis", text: "Trend identification and predictions")
                FeatureItem(icon: "lightbulb", text: "Personalized training recommendations")
            }
            .padding(.top, AppTheme.Spacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppTheme.Spacing.xxl)
    }
}

struct FeatureItem: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: icon)
                .foregroundColor(AppTheme.Colors.accent)
                .font(.title3)
                .frame(width: 24)
            
            Text(text)
                .font(AppTheme.Typography.body)
                .foregroundColor(AppTheme.Colors.secondaryText)
        }
    }
}

struct AnalysisResultsView: View {
    let results: AnalysisResults
    let activities: [Activity]
    
    var body: some View {
        LazyVStack(alignment: .leading, spacing: 24) {
            // Recommendations
            RecommendationsCard(recommendations: results.insights.recommendations)
            
            // Goal Readiness Analysis
            if let goalReadiness = results.insights.goalReadiness {
                GoalReadinessCard(goalReadiness: goalReadiness)
            }
            
            // Performance Overview
            PerformanceOverviewCard(insights: results.insights)
            
            // Weekly Volume Chart
            WeeklyVolumeChart(weeklyData: results.insights.weeklyVolume)
            
            // Performance Trend
            PerformanceTrendCard(insights: results.insights)
            
            // Next Run Prediction
            if let prediction = results.insights.nextRunPrediction {
                NextRunPredictionCard(prediction: prediction)
            }
            
            // Last Updated
            Text("Last updated: \(results.lastUpdated, style: .relative) ago")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top)
        }
    }
}

struct PerformanceOverviewCard: View {
    let insights: RunningInsights
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance Overview")
                .font(.title2)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                MetricBox(
                    title: "Total Distance",
                    value: String(format: "%.1f mi", insights.totalDistance),
                    icon: "road.lanes"
                )
                
                MetricBox(
                    title: "Avg Pace",
                    value: formatPace(insights.averagePace),
                    icon: "speedometer"
                )
                
                MetricBox(
                    title: "Total Time",
                    value: formatTime(insights.totalTime),
                    icon: "clock"
                )
                
                MetricBox(
                    title: "Consistency",
                    value: String(format: "%.0f%%", insights.consistency),
                    icon: "calendar"
                )
            }
        }
        .padding()
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(12)
    }
}

struct MetricBox: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.small)
    }
}

struct WeeklyVolumeChart: View {
    let weeklyData: [WeeklyVolume]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Volume Trend")
                .font(.title2)
                .fontWeight(.semibold)
            
            if !weeklyData.isEmpty {
                Chart {
                    ForEach(weeklyData, id: \.weekStart) { week in
                        BarMark(
                            x: .value("Week", week.weekStart),
                            y: .value("Distance", week.totalDistance)
                        )
                        .foregroundStyle(.blue.gradient)
                    }
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
            } else {
                Text("Not enough data for weekly analysis")
                    .foregroundColor(.secondary)
                    .frame(height: 100)
            }
        }
        .padding()
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(12)
    }
}

struct PerformanceTrendCard: View {
    let insights: RunningInsights
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance Trend")
                .font(.title2)
                .fontWeight(.semibold)
            
            HStack {
                Image(systemName: trendIcon)
                    .foregroundColor(trendColor)
                    .font(.title)
                
                VStack(alignment: .leading) {
                    Text(insights.performanceTrend.description)
                        .font(.headline)
                        .foregroundColor(trendColor)
                    
                    Text(trendDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(12)
    }
    
    private var trendIcon: String {
        switch insights.performanceTrend {
        case .improving: return "arrow.up.circle.fill"
        case .stable: return "minus.circle.fill"
        case .declining: return "arrow.down.circle.fill"
        }
    }
    
    private var trendColor: Color {
        switch insights.performanceTrend {
        case .improving: return .green
        case .stable: return .blue
        case .declining: return .red
        }
    }
    
    private var trendDescription: String {
        switch insights.performanceTrend {
        case .improving: return "Your pace has been getting faster"
        case .stable: return "Your performance is consistent"
        case .declining: return "Your pace has been slower recently"
        }
    }
}

struct NextRunPredictionCard: View {
    let prediction: PaceRange
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Next Run Prediction")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                PredictionRow(
                    label: "Expected Pace",
                    pace: prediction.expected,
                    color: .blue
                )
                
                HStack {
                    PredictionRow(
                        label: "Best Case",
                        pace: prediction.fastest,
                        color: .green
                    )
                    
                    Spacer()
                    
                    PredictionRow(
                        label: "Conservative",
                        pace: prediction.slowest,
                        color: .orange
                    )
                }
            }
        }
        .padding()
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(12)
    }
}

struct PredictionRow: View {
    let label: String
    let pace: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(formatPace(pace))
                .font(.headline)
                .foregroundColor(color)
        }
    }
}

struct RecommendationsCard: View {
    let recommendations: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Recommendations")
                .font(.title2)
                .fontWeight(.semibold)
            
            if recommendations.isEmpty {
                Text("Great job! Keep up your current training.")
                    .foregroundColor(.green)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(recommendations.enumerated()), id: \.offset) { index, recommendation in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(width: 20, height: 20)
                                .background(Color.blue)
                                .clipShape(Circle())
                            
                            Text(recommendation)
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - Goal Readiness Card
struct GoalReadinessCard: View {
    let goalReadiness: GoalReadiness
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Goal Readiness")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Marathon Training Assessment")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Overall Score Circle
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: goalReadiness.overallScore / 100)
                        .stroke(
                            getScoreColor(goalReadiness.overallScore),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 1.0), value: goalReadiness.overallScore)
                    
                    Text("\(Int(goalReadiness.overallScore))%")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(getScoreColor(goalReadiness.overallScore))
                }
            }
            
            // Readiness Categories
            VStack(spacing: 12) {
                ReadinessRow(
                    title: "Fitness Level",
                    level: goalReadiness.fitnessLevel,
                    icon: "heart.fill"
                )
                
                ReadinessRow(
                    title: "Experience",
                    level: goalReadiness.experienceLevel,
                    icon: "star.fill"
                )
                
                ReadinessRow(
                    title: "Training Volume",
                    level: goalReadiness.volumePreparation,
                    icon: "speedometer"
                )
                
                ReadinessRow(
                    title: "Time Remaining",
                    level: goalReadiness.timeToGoal,
                    icon: "clock.fill"
                )
            }
            
            // Risk Factors (if any)
            if !goalReadiness.riskFactors.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Risk Factors")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                    
                    ForEach(goalReadiness.riskFactors.indices, id: \.self) { index in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                                .padding(.top, 2)
                            
                            Text(goalReadiness.riskFactors[index])
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                    }
                }
                .padding(.top, 8)
            }
            
            // Quick Recommendations
            if !goalReadiness.recommendations.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Key Recommendations")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    
                    ForEach(goalReadiness.recommendations.prefix(3).indices, id: \.self) { index in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                                .padding(.top, 2)
                            
                            Text(goalReadiness.recommendations[index])
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(12)
    }
    
    private func getScoreColor(_ score: Double) -> Color {
        switch score {
        case 80...: return .green
        case 60..<80: return .blue
        case 40..<60: return .orange
        default: return .red
        }
    }
}

struct ReadinessRow: View {
    let title: String
    let level: ReadinessLevel
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(getLevelColor(level))
                .font(.caption)
                .frame(width: 16)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(level.displayName)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(getLevelColor(level))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(getLevelColor(level).opacity(0.2))
                .cornerRadius(6)
        }
    }
    
    private func getLevelColor(_ level: ReadinessLevel) -> Color {
        switch level {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        }
    }
}

// MARK: - Progress Overview Card
struct ProgressOverviewCard: View {
    let activities: [Activity]
    @State private var cachedTotalMiles: Double = 0.0
    private let metricsCache = ActivityMetricsCache()

    // Calculate actual progress from activities with caching
    private func calculateTotalMiles() -> Double {
        // Try to get from cache first
        if let cached = metricsCache.getTotalMiles(for: activities) {
            return cached
        }

        // Calculate if not in cache
        let activitiesWithDistance = activities.compactMap { activity -> Double? in
            return activity.distance
        }

        let totalMeters = activitiesWithDistance.reduce(0, +)
        let miles = totalMeters * 0.000621371 // Convert meters to miles

        // Cache the result
        metricsCache.cacheTotalMiles(miles, for: activities)

        return miles
    }

    private var totalMiles: Double {
        return cachedTotalMiles
    }
    
    private var currentProgress: Double { 
        // For now, assume a 100-mile monthly goal as example
        let monthlyGoal = 100.0
        return min(totalMiles / monthlyGoal, 1.0)
    }
    
    private var targetProgress: Double { 
        // Calculate expected progress based on days into the month
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        let dayOfMonth = calendar.component(.day, from: now)
        
        return Double(dayOfMonth) / Double(daysInMonth)
    }
    
    private var progressColor: Color {
        let ratio = currentProgress / max(targetProgress, 0.01)
        if ratio >= 1.0 { return .green }
        if ratio >= 0.8 { return .blue }
        if ratio >= 0.6 { return .orange }
        return .red
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Monthly Distance Progress")
                .font(.headline)
                .foregroundColor(.primary)
            
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                    .frame(width: 160, height: 160)
                
                // Target progress ring (outer)
                Circle()
                    .trim(from: 0, to: targetProgress)
                    .stroke(
                        Color.gray.opacity(0.5),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                
                // Actual progress ring (inner)
                Circle()
                    .trim(from: 0, to: currentProgress)
                    .stroke(
                        LinearGradient(
                            colors: [progressColor.opacity(0.7), progressColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: currentProgress)
                
                // Center content
                VStack(spacing: 4) {
                    Text(String(format: "%.1f", totalMiles))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(progressColor)
                    
                    Text("Miles")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            
            // Progress details
            VStack(spacing: 8) {
                HStack {
                    Circle()
                        .fill(progressColor)
                        .frame(width: 12, height: 12)
                    Text("Current Distance")
                        .font(.caption)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(String(format: "%.1f mi", totalMiles))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.primary)
                }
                
                HStack {
                    Circle()
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 12, height: 12)
                    Text("Monthly Goal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("100.0 mi")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }
                
                let ratio = currentProgress / targetProgress
                let statusText = ratio >= 1.0 ? "Ahead of Target" : ratio >= 0.8 ? "On Track" : "Behind Target"
                let statusColor = ratio >= 1.0 ? Color.green : ratio >= 0.8 ? Color.blue : Color.orange
                
                HStack {
                    Image(systemName: ratio >= 1.0 ? "checkmark.circle.fill" : ratio >= 0.8 ? "clock.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(statusColor)
                        .font(.caption)
                    Text(statusText)
                        .font(.caption.weight(.medium))
                        .foregroundColor(statusColor)
                    Spacer()
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 4)
        }
        .padding()
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(12)
        .onAppear {
            // Calculate total miles when view appears
            cachedTotalMiles = calculateTotalMiles()
        }
        .onChange(of: activities.count) { _ in
            // Recalculate when activities change
            cachedTotalMiles = calculateTotalMiles()
        }
    }
}

// MARK: - Helper Functions
private func formatPace(_ pace: Double) -> String {
    let minutes = Int(pace)
    let seconds = Int((pace - Double(minutes)) * 60)
    return String(format: "%d:%02d/mi", minutes, seconds)
}

private func formatTime(_ timeInMinutes: Double) -> String {
    let hours = Int(timeInMinutes / 60)
    let minutes = Int(timeInMinutes.truncatingRemainder(dividingBy: 60))
    
    if hours > 0 {
        return String(format: "%dh %dm", hours, minutes)
    } else {
        return String(format: "%dm", minutes)
    }
}
