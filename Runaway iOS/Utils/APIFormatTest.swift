//
//  APIFormatTest.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 7/16/25.
//

import Foundation

class APIFormatTest {
    static let shared = APIFormatTest()
    private let apiService = RunawayCoachAPIService()
    
    private init() {}
    
    /// Test the corrected format for quick insights
    func testCorrectedQuickInsights() async {
        print("🧪 Testing Corrected Quick Insights Format")
        
        // Create simple test activity
        let testActivity = Activity(
            id: 1,
            name: "Test Run",
            type: "Run",
            summary_polyline: nil,
            distance: 5000.0, // 5km in meters
            start_date: Date().addingTimeInterval(-3600).timeIntervalSince1970, // 1 hour ago
            elapsed_time: 1800.0 // 30 minutes
        )
        
        print("📱 Test Activity:")
        print("   Distance: \(testActivity.distance ?? 0) meters")
        print("   Duration: \(testActivity.elapsed_time ?? 0) seconds")
        print("   Calculated Pace: \(calculatePace(distance: testActivity.distance ?? 0, time: testActivity.elapsed_time ?? 0))")
        
        // Show what will be sent
        let apiActivity = testActivity.toAPIActivity()
        print("\n📤 API Activity:")
        print("   Distance: \(apiActivity.distance)")
        print("   Duration: \(apiActivity.duration)")
        print("   Pace: \(apiActivity.avgPace)")
        print("   Date: \(apiActivity.date)")
        
        // Test the actual API call
        do {
            print("\n🌐 Making API Call...")
            let response = try await apiService.getQuickInsights(activities: [testActivity])
            
            print("✅ SUCCESS! Response received:")
            print("   Success: \(response.success)")
            print("   Performance Trend: \(response.insights.performanceTrend)")
            print("   Weekly Mileage: \(response.insights.weeklyMileage)")
            print("   Consistency: \(response.insights.consistency)")
            print("   Recommendations: \(response.insights.topRecommendations)")
            
        } catch {
            print("❌ API Call Failed: \(error)")
            
            if let apiError = error as? APIError {
                switch apiError {
                case .validationError(let message):
                    print("   Validation Error: \(message)")
                case .serverError(let message):
                    print("   Server Error: \(message)")
                case .httpError(let code, let message):
                    print("   HTTP \(code): \(message ?? "Unknown")")
                default:
                    print("   Error: \(apiError.localizedDescription)")
                }
            }
        }
    }
    
    /// Test health endpoint (should work)
    func testHealthEndpoint() async {
        print("🏥 Testing Health Endpoint")
        do {
            let health = try await apiService.healthCheck()
            print("✅ Health Check Success:")
            print("   Status: \(health.status)")
            print("   Agents: \(health.agents)")
            print("   Timestamp: \(health.timestamp)")
        } catch {
            print("❌ Health Check Failed: \(error)")
        }
    }
    
    /// Test both endpoints
    func runAllFormatTests() async {
        await testHealthEndpoint()
        print("\n")
        await testCorrectedQuickInsights()
    }
    
    private func calculatePace(distance: Double, time: Double) -> String {
        guard distance > 0 && time > 0 else { return "N/A" }
        
        let miles = distance * 0.000621371
        let minutes = time / 60.0
        let paceMinPerMile = minutes / miles
        
        let mins = Int(paceMinPerMile)
        let secs = Int((paceMinPerMile - Double(mins)) * 60)
        
        return "\(mins):\(String(format: "%02d", secs))/mile"
    }
}

