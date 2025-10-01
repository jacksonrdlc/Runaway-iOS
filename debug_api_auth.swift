// Debug function to test API authentication
// Add this to a view or call it from your app to debug the auth issue

import Foundation

func debugAPIAuthentication() async {
    print("🔍 Starting API Authentication Debug")
    print("=" + String(repeating: "=", count: 50))

    // Check current configuration
    print("\n1️⃣ Checking API Configuration:")
    await APIConfiguration.RunawayCoach.printCurrentConfiguration()

    // Test basic authentication setup
    print("\n2️⃣ Testing Authentication Headers:")
    let headers = await APIConfiguration.RunawayCoach.getAuthHeaders()

    for (key, value) in headers {
        if key == "Authorization" {
            let maskedValue = String(value.prefix(20)) + "..." + String(value.suffix(8))
            print("   \(key): \(maskedValue)")
        } else {
            print("   \(key): \(value)")
        }
    }

    // Get current user info
    print("\n3️⃣ Current User Info:")
    if let userId = await APIConfiguration.RunawayCoach.getCurrentAuthUserId() {
        print("   User ID: \(userId)")
    } else {
        print("   ❌ No user ID available")
    }

    // Test a simple API call
    print("\n4️⃣ Testing API Call:")
    let apiService = RunawayCoachAPIService()

    do {
        let health = try await apiService.healthCheck()
        print("   ✅ Health Check Success: \(health.status)")
    } catch {
        print("   ❌ Health Check Failed: \(error)")
    }

    // Test auth-protected endpoint with minimal data
    print("\n5️⃣ Testing Protected Endpoint (Quick Insights):")

    let testActivity = Activity(
        id: 1,
        name: "Debug Test Run",
        type: "Run",
        summary_polyline: nil,
        distance: 5000.0, // 5km
        start_date: Date().timeIntervalSince1970,
        elapsed_time: 1800.0 // 30 minutes
    )

    do {
        let insights = try await apiService.getQuickInsights(activities: [testActivity])
        print("   ✅ Quick Insights Success: \(insights.success)")
    } catch {
        print("   ❌ Quick Insights Failed: \(error)")

        if let apiError = error as? APIError {
            switch apiError {
            case .authenticationError(let message):
                print("   🔐 Authentication Error Details: \(message)")
                print("   💡 Possible issues:")
                print("      - JWT token expired or invalid")
                print("      - API server JWT secret mismatch")
                print("      - User not found in athletes table")
            default:
                print("   Other API Error: \(apiError)")
            }
        }
    }

    print("\n" + String(repeating: "=", count: 60))
    print("🔍 Debug Complete")
}

// Also add this simpler version that you can call from UI
func quickAuthDebug() async -> String {
    let hasJWT = await APIConfiguration.RunawayCoach.getJWTToken() != nil
    let hasAPIKey = APIConfiguration.RunawayCoach.getAuthToken() != nil
    let userId = await APIConfiguration.RunawayCoach.getCurrentAuthUserId()

    return """
    Auth Status:
    JWT Available: \(hasJWT ? "✅" : "❌")
    API Key Available: \(hasAPIKey ? "✅" : "❌")
    User ID: \(userId ?? "None")
    """
}