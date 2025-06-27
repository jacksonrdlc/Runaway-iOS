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
    @StateObject private var analyzer = RunningAnalyzer()
    let activities: [Activity]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if analyzer.isAnalyzing {
                        AnalysisLoadingView()
                    } else if let results = analyzer.analysisResults {
                        AnalysisResultsView(results: results)
                    } else {
                        EmptyAnalysisView()
                    }
                }
                .padding()
            }
            .navigationTitle("Performance Analysis")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Analyze") {
                        Task {
                            await analyzer.analyzePerformance(activities: activities)
                        }
                    }
                    .disabled(analyzer.isAnalyzing)
                }
            }
        }
        .onAppear {
            if analyzer.analysisResults == nil && !activities.isEmpty {
                Task {
                    await analyzer.analyzePerformance(activities: activities)
                }
            }
        }
    }
}

struct AnalysisLoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Analyzing your running data...")
                .font(.headline)
            Text("Training ML models and generating insights")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

struct EmptyAnalysisView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            Text("Ready to Analyze")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Tap 'Analyze' to generate AI insights from your running data")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

struct AnalysisResultsView: View {
    let results: AnalysisResults
    
    var body: some View {
        LazyVStack(alignment: .leading, spacing: 24) {
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
            
            // Recommendations
            RecommendationsCard(recommendations: results.insights.recommendations)
            
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
                    value: String(format: "%.1f km", insights.totalDistance),
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
        .background(Color(.systemGray6))
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
        .padding()
        .background(Color.black)
        .cornerRadius(8)
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
        .background(Color(.systemGray6))
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
        .background(Color(.systemGray6))
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
        .background(Color(.systemGray6))
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
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Helper Functions
private func formatPace(_ pace: Double) -> String {
    let minutes = Int(pace)
    let seconds = Int((pace - Double(minutes)) * 60)
    return String(format: "%d:%02d/km", minutes, seconds)
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
