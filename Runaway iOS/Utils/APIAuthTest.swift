//
//  APIAuthTest.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 7/16/25.
//

import Foundation

class APIAuthTest {
    static let shared = APIAuthTest()
    private let apiService = RunawayCoachAPIService()
    
    private init() {}
    
    func testAuthentication() async {
        print("🔐 Testing API Authentication")
        print("=" * 40)
        
        // Print current configuration
        await APIConfiguration.RunawayCoach.printCurrentConfiguration()
        
        // Test health endpoint (usually doesn't require auth)
        await testHealthEndpoint()
        
        // Test authenticated endpoint
        await testAuthenticatedEndpoint()
    }
    
    private func testHealthEndpoint() async {
        print("\n🏥 Testing Health Endpoint (usually no auth required):")
        
        do {
            let health = try await apiService.healthCheck()
            print("✅ Health Check Success:")
            print("   Status: \(health.status)")
        } catch {
            print("❌ Health Check Failed: \(error)")
        }
    }
    
    private func testAuthenticatedEndpoint() async {
        print("\n🔒 Testing Authenticated Endpoint (/goals/assess):")
        
        // Create minimal test data
        let testGoal = RunningGoal(
            type: .distance,
            targetValue: 5.0,
            deadline: Date().addingTimeInterval(86400 * 30), // 30 days
            title: "Test Goal"
        )
        
        let testActivity = Activity(
            id: 1,
            name: "Test Run",
            type: "Run",
            summary_polyline: nil,
            distance: 3000.0,
            start_date: Date().addingTimeInterval(-3600).timeIntervalSince1970,
            elapsed_time: 1200.0
        )
        
        do {
            let response = try await apiService.assessGoals(
                goals: [testGoal],
                activities: [testActivity]
            )
            print("✅ Goals Assessment Success:")
            print("   Success: \(response.success)")
            print("   Assessments: \(response.goalAssessments.count)")
        } catch {
            print("❌ Goals Assessment Failed: \(error)")
            
            if let apiError = error as? APIError {
                switch apiError {
                case .authenticationError(let message):
                    print("   🔐 Authentication Issue: \(message)")
                    print("   💡 Check:")
                    print("      - API key is correct")
                    print("      - API key has proper permissions")
                    print("      - Server expects 'Bearer' token format")
                case .validationError(let message):
                    print("   📋 Validation Issue: \(message)")
                case .serverError(let message):
                    print("   🖥️ Server Issue: \(message)")
                default:
                    print("   ❓ Other Error: \(apiError.localizedDescription)")
                }
            }
        }
    }
    
    func debugAuthHeaders() async {
        print("🔍 Debug Authentication Headers")
        print("=" * 40)

        let headers = await APIConfiguration.RunawayCoach.getAuthHeaders()
        
        for (key, value) in headers {
            if key == "Authorization" {
                // Mask the API key for security
                let maskedValue = String(value.prefix(15)) + "..." + String(value.suffix(8))
                print("   \(key): \(maskedValue)")
            } else {
                print("   \(key): \(value)")
            }
        }
        
        // Check if we actually have an auth token
        if headers["Authorization"] == nil {
            print("❌ No Authorization header found!")
            print("💡 Check APIConfiguration.RunawayCoach.getAuthToken()")
        }
    }
}

// MARK: - String Extension
extension String {
    static func *(left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}