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
    let goalReadiness: GoalReadiness?
    
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
                
                // Goal Readiness Assessment
                if let goalReadiness = goalReadiness {
                    GoalReadinessCompactCard(goalReadiness: goalReadiness)
                } else {
                    // Fallback to progress chart if no readiness data
                    GoalProgressChart(analysis: analysis)
                }
                
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
                    
                    Text(goal.formattedTarget())
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
    
    private var currentProgress: Double {
        analysis.progressPoints.first?.actualProgress ?? 0
    }
    
    private var targetProgress: Double {
        analysis.progressPoints.first?.targetProgress ?? 0
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
            Text("Progress Overview")
                .font(.headline)
                .foregroundColor(AppTheme.Colors.primaryText)
            
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
                    Text("\(Int(currentProgress * 100))%")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(progressColor)
                    
                    Text("Complete")
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
                    Text("Current Progress")
                        .font(.caption)
                        .foregroundColor(.primary)
                    Spacer()
                    Text("\(Int(currentProgress * 100))%")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.primary)
                }
                
                HStack {
                    Circle()
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 12, height: 12)
                    Text("Target Progress")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(targetProgress * 100))%")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }
                
                if currentProgress > 0 && targetProgress > 0 {
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
            }
            .padding(.horizontal, 4)
        }
        .padding()
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(12)
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
    @State private var isMetric: Bool = false
    
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
                    
                    // Unit toggle for distance and pace goals
                    if selectedType == .distance || selectedType == .pace {
                        HStack {
                            Text("Units")
                            Spacer()
                            Picker("Units", selection: $isMetric) {
                                Text(selectedType == .distance ? "Miles" : "Miles/Min").tag(false)
                                Text(selectedType == .distance ? "Kilometers" : "Km/Min").tag(true)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .frame(width: 180)
                        }
                        .onChange(of: isMetric) { newValue in
                            convertTargetValue(toMetric: newValue)
                        }
                    }
                    
                    HStack {
                        TextField("Target", text: $targetValue)
                            .keyboardType(.decimalPad)
                        
                        Text(selectedType.unit(isMetric: isMetric))
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
        guard let value = getTargetValueInMiles() else { return }
        
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
    
    private func convertTargetValue(toMetric: Bool) {
        guard !targetValue.isEmpty, let currentValue = Double(targetValue) else { return }
        
        if selectedType == .distance {
            if toMetric {
                // Convert miles to km
                let kmValue = currentValue * 1.60934
                targetValue = String(format: "%.1f", kmValue)
            } else {
                // Convert km to miles
                let milesValue = currentValue / 1.60934
                targetValue = String(format: "%.1f", milesValue)
            }
        } else if selectedType == .pace {
            if toMetric {
                // Convert min/mile to min/km (pace gets faster in km)
                let kmPace = currentValue / 1.60934
                targetValue = String(format: "%.2f", kmPace)
            } else {
                // Convert min/km to min/mile (pace gets slower in miles)
                let milePace = currentValue * 1.60934
                targetValue = String(format: "%.2f", milePace)
            }
        }
    }
    
    private func getTargetValueInMiles() -> Double? {
        guard let value = Double(targetValue) else { return nil }
        
        if selectedType == .distance && isMetric {
            // Convert km to miles for storage
            return value / 1.60934
        } else if selectedType == .pace && isMetric {
            // Convert min/km to min/mile for storage
            return value * 1.60934
        }
        
        return value // Already in miles or not distance/pace
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

// MARK: - Goal Readiness Compact Card
struct GoalReadinessCompactCard: View {
    let goalReadiness: GoalReadiness
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Goal Readiness")
                    .font(.headline)
                    .foregroundColor(AppTheme.Colors.primaryText)
                
                Spacer()
                
                // Overall Score Badge
                Text("\(Int(goalReadiness.overallScore))%")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(getScoreColor(goalReadiness.overallScore))
                    .cornerRadius(8)
            }
            
            // Quick readiness indicators
            HStack(spacing: 16) {
                ReadinessIndicator(
                    title: "Fitness",
                    level: goalReadiness.fitnessLevel,
                    icon: "heart.fill"
                )
                
                ReadinessIndicator(
                    title: "Volume",
                    level: goalReadiness.volumePreparation,
                    icon: "speedometer"
                )
                
                ReadinessIndicator(
                    title: "Time",
                    level: goalReadiness.timeToGoal,
                    icon: "clock.fill"
                )
                
                ReadinessIndicator(
                    title: "Experience",
                    level: goalReadiness.experienceLevel,
                    icon: "star.fill"
                )
            }
            
            // Key recommendation
            if !goalReadiness.recommendations.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                        .padding(.top, 1)
                    
                    Text(goalReadiness.recommendations.first ?? "")
                        .font(.caption)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                }
                .padding(.top, 4)
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

struct ReadinessIndicator: View {
    let title: String
    let level: ReadinessLevel
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(getLevelColor(level))
                .font(.caption)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            Circle()
                .fill(getLevelColor(level))
                .frame(width: 8, height: 8)
        }
        .frame(maxWidth: .infinity)
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
