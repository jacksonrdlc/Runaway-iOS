//
//  RunningGoalComponents.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 6/28/25.
//

import SwiftUI
import Charts

// MARK: - Main Goal Card Component
struct RunningGoalCard: View {
    @StateObject private var goalAgent = GoalRecommendationAgent()
    @State private var showingGoalInput = false
    @State private var currentGoal: RunningGoal?
    @State private var goalAnalysis: GoalAnalysis?
    @State private var isLoadingGoal = false
    @State private var errorMessage: String?
    
    let activities: [Activity]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Running Goal")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.Colors.primaryText)
                
                Spacer()
                
                if isLoadingGoal {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button(action: {
                        showingGoalInput = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: currentGoal == nil ? "plus.circle.fill" : "pencil.circle.fill")
                            Text(currentGoal == nil ? "Set Goal" : "Edit")
                        }
                        .font(.subheadline)
                        .foregroundColor(AppTheme.Colors.primary)
                    }
                }
            }
            
            // Error Message
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.error)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.Colors.error.opacity(0.1))
                    .cornerRadius(8)
            }
            
            if let goal = currentGoal, let analysis = goalAnalysis {
                // Goal Overview
                GoalOverviewSection(goal: goal, analysis: analysis)
                
                // Progress Chart
                GoalProgressChart(analysis: analysis)
                
                // AI Recommendations
                if !goalAgent.isAnalyzing {
                    GoalRecommendationsSection(recommendations: analysis.recommendations)
                } else {
                    ProgressView("Generating AI recommendations...")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            } else if !isLoadingGoal {
                // Empty State
                GoalEmptyState()
            }
        }
        .padding()
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.medium)
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        .sheet(isPresented: $showingGoalInput) {
            GoalInputSheet(currentGoal: currentGoal) { newGoal in
                if let goal = newGoal {
                    currentGoal = goal
                    Task {
                        await generateAnalysis(for: goal)
                    }
                }
            }
        }
        .onAppear {
            loadActiveGoal()
        }
        .refreshable {
            await refreshGoal()
        }
    }
    
    private func loadActiveGoal() {
        isLoadingGoal = true
        errorMessage = nil
        
        Task {
            do {
                // Get the most recent active goal (any type)
                let activeGoals = try await GoalService.getActiveGoals()
                let mostRecentGoal = activeGoals.first
                
                await MainActor.run {
                    currentGoal = mostRecentGoal
                    isLoadingGoal = false
                }
                
                if let goal = mostRecentGoal {
                    await generateAnalysis(for: goal)
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load goal: \(error.localizedDescription)"
                    isLoadingGoal = false
                }
                print("❌ Error loading goal: \(error)")
            }
        }
    }
    
    private func generateAnalysis(for goal: RunningGoal) async {
        let analysis = await goalAgent.analyzeGoalAndGenerateRecommendations(
            goal: goal,
            activities: activities
        )
        await MainActor.run {
            goalAnalysis = analysis
        }
    }
    
    @MainActor
    private func refreshGoal() async {
        guard let currentGoalId = currentGoal?.id else {
            loadActiveGoal()
            return
        }
        
        do {
            let refreshedGoal = try await GoalService.getGoalById(currentGoalId)
            currentGoal = refreshedGoal
            
            if let goal = refreshedGoal {
                await generateAnalysis(for: goal)
            }
        } catch {
            errorMessage = "Failed to refresh goal: \(error.localizedDescription)"
            print("❌ Error refreshing goal: \(error)")
        }
    }
}

// MARK: - Goal Overview Section
struct GoalOverviewSection: View {
    let goal: RunningGoal
    let analysis: GoalAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.title)
                        .font(.headline)
                        .foregroundColor(AppTheme.Colors.primaryText)
                    
                    Text(goal.formattedTarget)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.Colors.accent)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(goal.daysRemaining) days left")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.Colors.secondaryText)
                    
                    Text(analysis.trackingStatus.description)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(statusColor.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            
            // Progress Bar
            ProgressView(value: analysis.progressPercentage / 100.0)
                .progressViewStyle(LinearProgressViewStyle(tint: statusColor))
                .scaleEffect(x: 1, y: 2, anchor: .center)
            
            Text("\(Int(analysis.progressPercentage))% Complete")
                .font(.caption)
                .foregroundColor(AppTheme.Colors.secondaryText)
        }
    }
    
    private var statusColor: Color {
        switch analysis.trackingStatus {
        case .onTrack: return .green
        case .slightlyBehind: return .orange
        case .significantlyBehind: return .red
        }
    }
}

// MARK: - Progress Chart
struct GoalProgressChart: View {
    let analysis: GoalAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progress Trajectory")
                .font(.headline)
                .foregroundColor(AppTheme.Colors.primaryText)
            
            Chart {
                // Target trajectory line
                ForEach(analysis.progressPoints) { point in
                    LineMark(
                        x: .value("Week", point.weekNumber),
                        y: .value("Progress", point.targetProgress * 100)
                    )
                    .foregroundStyle(.gray)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                }
                
                // Actual progress line
                ForEach(analysis.progressPoints) { point in
                    LineMark(
                        x: .value("Week", point.weekNumber),
                        y: .value("Progress", point.actualProgress * 100)
                    )
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                }
                
                // Current position marker
                if let currentPoint = analysis.progressPoints.first {
                    PointMark(
                        x: .value("Week", currentPoint.weekNumber),
                        y: .value("Progress", currentPoint.actualProgress * 100)
                    )
                    .foregroundStyle(.blue)
                    .symbolSize(100)
                }
            }
            .frame(height: 150)
            .chartYScale(domain: 0...100)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            
            // Legend
            HStack(spacing: 20) {
                Label("Target", systemImage: "line.diagonal")
                    .foregroundColor(.gray)
                    .font(.caption)
                
                Label("Actual", systemImage: "line.diagonal")
                    .foregroundColor(.blue)
                    .font(.caption)
            }
        }
    }
}

// MARK: - Recommendations Section
struct GoalRecommendationsSection: View {
    let recommendations: [TrainingRecommendation]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Training Recommendations")
                .font(.headline)
                .foregroundColor(AppTheme.Colors.primaryText)
            
            ForEach(recommendations) { recommendation in
                RecommendationCard(recommendation: recommendation)
            }
        }
    }
}

struct RecommendationCard: View {
    let recommendation: TrainingRecommendation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Run \(recommendation.runNumber)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.Colors.accent)
                
                Spacer()
                
                Text(recommendation.formattedDistance)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.Colors.primaryText)
            }
            
            Text(recommendation.description)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppTheme.Colors.primaryText)
            
            Text("Pace: \(recommendation.formattedPace)")
                .font(.caption)
                .foregroundColor(AppTheme.Colors.secondaryText)
            
            Text(recommendation.reasoning)
                .font(.caption)
                .foregroundColor(AppTheme.Colors.mutedText)
                .italic()
        }
        .padding(12)
        .background(AppTheme.Colors.background)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.Colors.mutedText.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Empty State
struct GoalEmptyState: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 40))
                .foregroundColor(AppTheme.Colors.accent)
            
            VStack(spacing: 8) {
                Text("Set Your Running Goal")
                    .font(.headline)
                    .foregroundColor(AppTheme.Colors.primaryText)
                
                Text("Get AI-powered training recommendations based on your performance data")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

// MARK: - Goal Input Sheet
struct GoalInputSheet: View {
    @Environment(\.presentationMode) var presentationMode
    
    let currentGoal: RunningGoal?
    let onSave: (RunningGoal?) -> Void
    
    @State private var selectedType: GoalType = .distance
    @State private var targetValue: String = ""
    @State private var deadline = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    @State private var goalTitle: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Goal Details")) {
                    TextField("Goal Title", text: $goalTitle)
                        .placeholder("e.g., 'Run a 10K'", when: goalTitle.isEmpty)
                    
                    Picker("Goal Type", selection: $selectedType) {
                        ForEach(GoalType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    HStack {
                        TextField("Target", text: $targetValue)
                            .keyboardType(.decimalPad)
                        
                        Text(selectedType.unit)
                            .foregroundColor(.secondary)
                    }
                    
                    DatePicker("Deadline", selection: $deadline, displayedComponents: .date)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(currentGoal == nil ? "Set Running Goal" : "Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(isSaving)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSaving {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Button("Save") {
                            saveGoal()
                        }
                        .disabled(!isValidInput)
                    }
                }
            }
        }
        .onAppear {
            loadCurrentGoal()
        }
    }
    
    private var isValidInput: Bool {
        !goalTitle.isEmpty && 
        !targetValue.isEmpty && 
        Double(targetValue) != nil &&
        deadline > Date() &&
        !isSaving
    }
    
    private func loadCurrentGoal() {
        if let goal = currentGoal {
            goalTitle = goal.title
            selectedType = goal.type
            targetValue = String(goal.targetValue)
            deadline = goal.deadline
        }
    }
    
    private func saveGoal() {
        guard let value = Double(targetValue) else { return }
        
        isSaving = true
        errorMessage = nil
        
        Task {
            do {
                let goal: RunningGoal
                
                if let existingGoal = currentGoal {
                    // Update existing goal
                    let updatedGoal = RunningGoal(
                        id: existingGoal.id,
                        userId: existingGoal.userId,
                        type: selectedType,
                        targetValue: value,
                        deadline: deadline,
                        createdDate: existingGoal.createdDate,
                        updatedDate: existingGoal.updatedDate,
                        title: goalTitle,
                        isActive: existingGoal.isActive,
                        isCompleted: existingGoal.isCompleted,
                        currentProgress: existingGoal.currentProgress,
                        completedDate: existingGoal.completedDate
                    )
                    goal = try await GoalService.updateGoal(updatedGoal)
                } else {
                    // Create new goal
                    // First deactivate any existing goals of the same type
                    try await GoalService.deactivateGoalsOfType(selectedType)
                    
                    // Create the new goal
                    let newGoal = RunningGoal(
                        type: selectedType,
                        targetValue: value,
                        deadline: deadline,
                        title: goalTitle
                    )
                    goal = try await GoalService.createGoal(newGoal)
                }
                
                await MainActor.run {
                    onSave(goal)
                    presentationMode.wrappedValue.dismiss()
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to save goal: \(error.localizedDescription)"
                    isSaving = false
                }
                print("❌ Error saving goal: \(error)")
            }
        }
    }
}

// MARK: - Helper Extensions
extension View {
    func placeholder(_ text: String, when shouldShow: Bool) -> some View {
        ZStack(alignment: .leading) {
            if shouldShow {
                Text(text)
                    .foregroundColor(.secondary)
            }
            self
        }
    }
}
