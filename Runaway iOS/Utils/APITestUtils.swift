//
//  APITestUtils.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 7/16/25.
//

import Foundation

class APITestUtils {
    static let shared = APITestUtils()
    private let apiService = RunawayCoachAPIService()
    
    private init() {}
    
    // MARK: - Test Health Check
    
    func testHealthCheck() async -> (success: Bool, message: String) {
        // Print current configuration for debugging
        APIConfiguration.RunawayCoach.printCurrentConfiguration()
        
        do {
            let health = try await apiService.healthCheck()
            return (true, "API Health: \(health.status)")
        } catch {
            return (false, "Health check failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Debug Test with Minimal Data
    
    func testMinimalQuickInsights() async -> (success: Bool, message: String) {
        // Run debug analysis first
        print("🔍 Running debug analysis...")
        APIDebugUtils.shared.debugQuickInsightsRequest()
        
        // Create minimal test data
        let testActivity = Activity(
            id: 1,
            name: "Test Run",
            type: "Run",
            summary_polyline: nil,
            distance: 5000.0, // 5km in meters
            start_date: Date().timeIntervalSince1970,
            elapsed_time: 1800.0 // 30 minutes
        )
        
        print("\n🧪 Testing with minimal activity data:")
        print("   ID: \(testActivity.id)")
        print("   Distance: \(testActivity.distance ?? 0)m")
        print("   Duration: \(testActivity.elapsed_time ?? 0)s")
        print("   Start Date: \(testActivity.start_date ?? 0)")
        
        do {
            let response = try await apiService.getQuickInsights(activities: [testActivity])
            return (true, "Quick insights: \(response.insights.performanceTrend)")
        } catch {
            return (false, "Quick insights failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Test Quick Insights
    
    func testQuickInsights(with activities: [Activity]) async -> (success: Bool, message: String) {
        guard !activities.isEmpty else {
            return (false, "No activities provided for testing")
        }
        
        do {
            let response = try await apiService.getQuickInsights(activities: activities)
            if response.success {
                return (true, "Quick insights: \(response.insights.performanceTrend)")
            } else {
                return (false, "API returned success: false")
            }
        } catch {
            return (false, "Quick insights failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Test Goal Assessment
    
    func testGoalAssessment(goals: [RunningGoal], activities: [Activity]) async -> (success: Bool, message: String) {
        guard !goals.isEmpty && !activities.isEmpty else {
            return (false, "No goals or activities provided for testing")
        }
        
        do {
            let response = try await apiService.assessGoals(goals: goals, activities: activities)
            if response.success && !response.goalAssessments.isEmpty {
                let firstAssessment = response.goalAssessments[0]
                return (true, "Goal assessment: \(firstAssessment.currentStatus) - \(firstAssessment.progressPercentage)%")
            } else {
                return (false, "API returned success: false or no assessments")
            }
        } catch {
            return (false, "Goal assessment failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Test Full Analysis
    
    func testFullAnalysis(
        userId: String,
        activities: [Activity],
        goals: [RunningGoal],
        profile: RunnerProfile
    ) async -> (success: Bool, message: String) {
        do {
            let response = try await apiService.analyzeRunner(
                userId: userId,
                activities: activities,
                goals: goals,
                profile: profile
            )
            
            if response.success {
                let analysis = response.analysis
                return (true, "Full analysis completed. Processing time: \(response.processingTime)s")
            } else {
                return (false, "API returned success: false")
            }
        } catch {
            return (false, "Full analysis failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Test All Endpoints
    
    func runAllTests(
        userId: String,
        activities: [Activity],
        goals: [RunningGoal],
        profile: RunnerProfile
    ) async -> [TestResult] {
        var results: [TestResult] = []
        
        // Test 1: Health Check
        let healthResult = await testHealthCheck()
        results.append(TestResult(
            name: "Health Check",
            success: healthResult.success,
            message: healthResult.message
        ))
        
        // Test 2: Quick Insights
        let insightsResult = await testQuickInsights(with: activities)
        results.append(TestResult(
            name: "Quick Insights",
            success: insightsResult.success,
            message: insightsResult.message
        ))
        
        // Test 3: Goal Assessment
        let goalResult = await testGoalAssessment(goals: goals, activities: activities)
        results.append(TestResult(
            name: "Goal Assessment",
            success: goalResult.success,
            message: goalResult.message
        ))
        
        // Test 4: Full Analysis
        let fullResult = await testFullAnalysis(
            userId: userId,
            activities: activities,
            goals: goals,
            profile: profile
        )
        results.append(TestResult(
            name: "Full Analysis",
            success: fullResult.success,
            message: fullResult.message
        ))
        
        return results
    }
    
    // MARK: - Create Sample Data
    
    func createSampleData() -> (activities: [Activity], goals: [RunningGoal], profile: RunnerProfile) {
        // Create sample activities
        let activities = [
            createSampleActivity(distance: 5.0, duration: 1800, date: Date().addingTimeInterval(-86400 * 7)),
            createSampleActivity(distance: 8.0, duration: 3000, date: Date().addingTimeInterval(-86400 * 5)),
            createSampleActivity(distance: 3.0, duration: 1200, date: Date().addingTimeInterval(-86400 * 3)),
            createSampleActivity(distance: 10.0, duration: 3600, date: Date().addingTimeInterval(-86400 * 1))
        ]
        
        // Create sample goals
        let goals = [
            createSampleGoal(type: .distance, target: 21.1, deadline: Date().addingTimeInterval(86400 * 90))
        ]
        
        // Create sample profile
        let profile = RunnerProfile(
            userId: "test_user_123",
            age: 28,
            gender: "male",
            experienceLevel: "intermediate",
            weeklyMileage: 25.0,
            bestTimes: ["5K": "20:30", "10K": "42:15"],
            preferredWorkoutTypes: ["tempo", "intervals"],
            daysPerWeek: 4
        )
        
        return (activities, goals, profile)
    }
    
    private func createSampleActivity(distance: Double, duration: TimeInterval, date: Date) -> Activity {
        return Activity(
            id: Int.random(in: 1...100000),
            name: "Sample Run",
            type: "Run",
            summary_polyline: nil,
            distance: distance * 1000, // Convert to meters
            start_date: date.timeIntervalSince1970,
            elapsed_time: duration
        )
    }
    
    private func createSampleGoal(type: GoalType, target: Double, deadline: Date) -> RunningGoal {
        return RunningGoal(
            type: type,
            targetValue: target,
            deadline: deadline,
            title: "Sample \(type.displayName)"
        )
    }
}

// MARK: - Test Result Model

struct TestResult {
    let name: String
    let success: Bool
    let message: String
    let timestamp: Date
    
    init(name: String, success: Bool, message: String) {
        self.name = name
        self.success = success
        self.message = message
        self.timestamp = Date()
    }
}

// MARK: - Test Runner View Model

class APITestRunner: ObservableObject {
    @Published var isRunning = false
    @Published var results: [TestResult] = []
    @Published var currentTest: String = ""
    
    func runTests() async {
        await MainActor.run {
            isRunning = true
            results = []
            currentTest = "Starting tests..."
        }
        
        let testUtils = APITestUtils.shared
        let sampleData = testUtils.createSampleData()
        
        await MainActor.run {
            currentTest = "Running API tests..."
        }
        
        let testResults = await testUtils.runAllTests(
            userId: "test_user_123",
            activities: sampleData.activities,
            goals: sampleData.goals,
            profile: sampleData.profile
        )
        
        await MainActor.run {
            results = testResults
            currentTest = "Tests completed"
            isRunning = false
        }
    }
    
    var successCount: Int {
        return results.filter { $0.success }.count
    }
    
    var failureCount: Int {
        return results.filter { !$0.success }.count
    }
    
    var allTestsPassed: Bool {
        return !results.isEmpty && results.allSatisfy { $0.success }
    }
}