//
//  APIDebugUtils.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 7/16/25.
//

import Foundation

class APIDebugUtils {
    static let shared = APIDebugUtils()
    
    private init() {}
    
    // MARK: - Debug Functions
    
    func debugActivityConversion() {
        print("🔍 DEBUG: Activity Conversion")
        print("=" * 50)
        
        // Create sample activity
        let sampleActivity = Activity(
            id: 123,
            name: "Morning Run",
            type: "Run",
            summary_polyline: nil,
            distance: 5000.0, // 5km in meters
            start_date: Date().timeIntervalSince1970,
            elapsed_time: 1800.0 // 30 minutes in seconds
        )
        
        print("📱 Original Activity:")
        print("   ID: \(sampleActivity.id)")
        print("   Name: \(sampleActivity.name ?? "nil")")
        print("   Type: \(sampleActivity.type ?? "nil")")
        print("   Distance: \(sampleActivity.distance ?? 0.0) meters")
        print("   Start Date: \(sampleActivity.start_date ?? 0) (timestamp)")
        print("   Elapsed Time: \(sampleActivity.elapsed_time ?? 0) seconds")
        
        // Convert to API format
        let apiActivity = sampleActivity.toAPIActivity()
        
        print("\n🌐 API Activity:")
        print("   ID: \(apiActivity.id)")
        print("   Type: \(apiActivity.type)")
        print("   Distance: \(apiActivity.distance)")
        print("   Duration: \(apiActivity.duration)")
        print("   Avg Pace: \(apiActivity.avgPace)")
        print("   Date: \(apiActivity.date)")
        print("   Heart Rate: \(apiActivity.heartRateAvg?.description ?? "nil")")
        print("   Elevation: \(apiActivity.elevationGain?.description ?? "nil")")
        
        // Show JSON representation
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(apiActivity)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "Failed to encode"
            print("\n📄 JSON Output:")
            print(jsonString)
        } catch {
            print("\n❌ JSON Encoding Error: \(error)")
        }
    }
    
    func debugQuickInsightsRequest() {
        print("🔍 DEBUG: Quick Insights Request")
        print("=" * 50)
        
        // Create sample activity
        let sampleActivity = Activity(
            id: 456,
            name: "Test Run",
            type: "Run",
            summary_polyline: nil,
            distance: 3000.0, // 3km
            start_date: Date().addingTimeInterval(-3600).timeIntervalSince1970, // 1 hour ago
            elapsed_time: 1200.0 // 20 minutes
        )
        
        // Create request as direct array (not wrapped in object)
        let activitiesArray = [sampleActivity.toAPIActivity()]
        
        print("📱 Request Array:")
        print("   Activities Count: \(activitiesArray.count)")
        print("   First Activity: \(activitiesArray.first?.id ?? "none")")
        
        // Show JSON representation
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(activitiesArray)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "Failed to encode"
            print("\n📄 Full Request JSON (Direct Array):")
            print(jsonString)
        } catch {
            print("\n❌ Request Encoding Error: \(error)")
        }
    }
    
    func debugRunnerProfileConversion() {
        print("🔍 DEBUG: Runner Profile Conversion")
        print("=" * 50)
        
        let profile = RunnerProfile(
            userId: "test123",
            age: 30,
            gender: "male",
            experienceLevel: "intermediate",
            weeklyMileage: 20.0,
            bestTimes: ["5K": "22:30", "10K": "47:15"],
            preferredWorkoutTypes: ["easy", "tempo"],
            daysPerWeek: 4
        )
        
        let apiProfile = profile.toAPIProfile()
        
        print("📱 Profile Object:")
        print("   User ID: \(apiProfile.userId)")
        print("   Age: \(apiProfile.age)")
        print("   Experience: \(apiProfile.experienceLevel)")
        print("   Weekly Mileage: \(apiProfile.weeklyMileage)")
        
        // Show JSON representation
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(apiProfile)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "Failed to encode"
            print("\n📄 Profile JSON:")
            print(jsonString)
        } catch {
            print("\n❌ Profile Encoding Error: \(error)")
        }
    }
    
    func debugGoalConversion() {
        print("🔍 DEBUG: Goal Conversion")
        print("=" * 50)
        
        let goal = RunningGoal(
            type: .distance,
            targetValue: 10.0,
            deadline: Date().addingTimeInterval(86400 * 30), // 30 days from now
            title: "Run 10 miles"
        )
        
        let apiGoal = goal.toAPIGoal()
        
        print("📱 Goal Object:")
        print("   ID: \(apiGoal.id)")
        print("   Type: \(apiGoal.type)")
        print("   Target: \(apiGoal.target)")
        print("   Deadline: \(apiGoal.deadline)")
        print("   Current Best: \(apiGoal.currentBest ?? "nil")")
        
        // Show JSON representation
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(apiGoal)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "Failed to encode"
            print("\n📄 Goal JSON:")
            print(jsonString)
        } catch {
            print("\n❌ Goal Encoding Error: \(error)")
        }
    }
    
    func runAllDebugTests() {
        debugActivityConversion()
        print("\n")
        debugQuickInsightsRequest()
        print("\n")
        debugRunnerProfileConversion()
        print("\n")
        debugGoalConversion()
    }
}

