//
//  SupabaseLoggingService.swift
//  Runaway iOS
//
//  Logging service for Supabase SDK - logs all API requests/responses
//

import Foundation
import Supabase

/// Custom logger for Supabase SDK that provides detailed API logging
final class SupabaseLoggingService: SupabaseLogger {
    static let shared = SupabaseLoggingService()

    private init() {}

    func log(message: String, fileID: String, functionName: String, line: UInt) {
        #if DEBUG
        let fileName = URL(fileURLWithPath: fileID).lastPathComponent
        let timestamp = ISO8601DateFormatter().string(from: Date())

        // Color-code based on message content
        let icon: String
        if message.lowercased().contains("error") {
            icon = "❌"
        } else if message.lowercased().contains("request") {
            icon = "📤"
        } else if message.lowercased().contains("response") {
            icon = "📥"
        } else if message.lowercased().contains("auth") {
            icon = "🔐"
        } else if message.lowercased().contains("realtime") {
            icon = "⚡"
        } else {
            icon = "📋"
        }

        print("\(icon) [Supabase] \(timestamp)")
        print("   \(fileName):\(line) - \(functionName)")
        print("   \(message)")
        print("")
        #endif
    }
}

// MARK: - Extended Logging Helpers

extension SupabaseLoggingService {
    /// Log API request details
    static func logRequest(endpoint: String, method: String, body: Any? = nil) {
        #if DEBUG
        print("📤 [Supabase Request]")
        print("   Endpoint: \(endpoint)")
        print("   Method: \(method)")
        if let body = body {
            print("   Body: \(body)")
        }
        print("")
        #endif
    }

    /// Log API response details
    static func logResponse(endpoint: String, statusCode: Int, data: Data? = nil) {
        #if DEBUG
        let icon = (200...299).contains(statusCode) ? "✅" : "❌"
        print("\(icon) [Supabase Response]")
        print("   Endpoint: \(endpoint)")
        print("   Status: \(statusCode)")
        if let data = data, let json = try? JSONSerialization.jsonObject(with: data) {
            print("   Response: \(json)")
        }
        print("")
        #endif
    }

    /// Log authentication events
    static func logAuth(event: String, userId: String? = nil) {
        #if DEBUG
        print("🔐 [Supabase Auth]")
        print("   Event: \(event)")
        if let userId = userId {
            print("   User ID: \(userId)")
        }
        print("")
        #endif
    }

    /// Log errors with full details
    static func logError(_ error: Error, context: String) {
        #if DEBUG
        print("❌ [Supabase Error]")
        print("   Context: \(context)")
        print("   Error: \(error.localizedDescription)")
        if let nsError = error as NSError? {
            print("   Domain: \(nsError.domain)")
            print("   Code: \(nsError.code)")
            if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
                print("   Underlying: \(underlying.localizedDescription)")
            }
        }
        print("")
        #endif
    }
}
