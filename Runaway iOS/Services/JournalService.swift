//
//  JournalService.swift
//  Runaway iOS
//
//  Service for Training Journal API communication
//

import Foundation
import Supabase

class JournalService {
    // MARK: - Public Methods

    /// Get journal entries for an athlete
    static func getJournalEntries(
        athleteId: Int,
        limit: Int = 10
    ) async throws -> [TrainingJournal] {

        #if DEBUG
        print("📔 Journal API Request:")
        print("   Athlete ID: \(athleteId)")
        print("   Limit: \(limit)")
        #endif

        // Get Supabase base URL and construct Edge Function URL
        guard let baseURL = SupabaseConfiguration.supabaseURL else {
            throw JournalError.invalidResponse
        }

        let url = URL(string: "\(baseURL)/functions/v1/journal?athlete_id=\(athleteId)&limit=\(limit)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15.0
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add JWT authentication from Supabase session
        if let session = try? await supabase.auth.session {
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            #if DEBUG
            print("   🔐 JWT token added to request")
            #endif
        } else {
            #if DEBUG
            print("   ⚠️ No active Supabase session - request may fail")
            #endif
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw JournalError.invalidResponse
        }

        #if DEBUG
        print("   Response Code: \(httpResponse.statusCode)")
        #endif

        switch httpResponse.statusCode {
        case 200:
            do {
                let apiResponse = try JSONDecoder().decode(JournalAPIResponse.self, from: data)

                if apiResponse.success, let entries = apiResponse.entries {
                    #if DEBUG
                    print("   ✅ Success: \(entries.count) journal entries")
                    #endif
                    return entries
                } else {
                    throw JournalError.noEntriesFound
                }
            } catch let decodingError {
                #if DEBUG
                print("   ❌ Decoding Error: \(decodingError)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("   Raw Response: \(jsonString)")
                }
                #endif
                throw JournalError.decodingFailed(decodingError)
            }

        case 404:
            throw JournalError.noEntriesFound

        default:
            if let errorResponse = try? JSONDecoder().decode(JournalAPIResponse.self, from: data),
               let error = errorResponse.error {
                throw JournalError.apiError(error.code, error.message)
            }
            throw JournalError.httpError(httpResponse.statusCode)
        }
    }

    /// Generate journal entry for a specific week
    static func generateJournalEntry(
        athleteId: Int,
        weekStartDate: String
    ) async throws -> TrainingJournal {

        #if DEBUG
        print("📔 Journal Generation Request:")
        print("   Athlete ID: \(athleteId)")
        print("   Week Start: \(weekStartDate)")
        #endif

        // Get Supabase base URL and construct Edge Function URL
        guard let baseURL = SupabaseConfiguration.supabaseURL else {
            throw JournalError.invalidResponse
        }

        let url = URL(string: "\(baseURL)/functions/v1/journal/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120.0  // Longer timeout for AI generation
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add JWT authentication from Supabase session
        if let session = try? await supabase.auth.session {
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            #if DEBUG
            print("   🔐 JWT token added to request")
            #endif
        } else {
            #if DEBUG
            print("   ⚠️ No active Supabase session - request may fail")
            #endif
        }

        let requestBody: [String: Any] = [
            "athlete_id": athleteId,
            "week_start_date": weekStartDate
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw JournalError.invalidResponse
        }

        #if DEBUG
        print("   Response Code: \(httpResponse.statusCode)")
        #endif

        switch httpResponse.statusCode {
        case 200:
            do {
                let apiResponse = try JSONDecoder().decode(JournalAPIResponse.self, from: data)

                if apiResponse.success, let journal = apiResponse.journal {
                    #if DEBUG
                    print("   ✅ Journal Generated")
                    #endif
                    return journal
                } else {
                    throw JournalError.generationFailed
                }
            } catch let decodingError {
                #if DEBUG
                print("   ❌ Decoding Error: \(decodingError)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("   Raw Response: \(jsonString)")
                }
                #endif
                throw JournalError.decodingFailed(decodingError)
            }

        case 404:
            throw JournalError.noActivitiesFound

        default:
            if let errorResponse = try? JSONDecoder().decode(JournalAPIResponse.self, from: data),
               let error = errorResponse.error {
                throw JournalError.apiError(error.code, error.message)
            }
            throw JournalError.httpError(httpResponse.statusCode)
        }
    }

    /// Generate journal entries for the last N weeks
    static func generateRecentJournals(
        athleteId: Int,
        weeks: Int = 4
    ) async throws -> [TrainingJournal] {

        #if DEBUG
        print("📔 Batch Journal Generation Request:")
        print("   Athlete ID: \(athleteId)")
        print("   Weeks: \(weeks)")
        #endif

        // Get Supabase base URL and construct Edge Function URL
        guard let baseURL = SupabaseConfiguration.supabaseURL else {
            throw JournalError.invalidResponse
        }

        let url = URL(string: "\(baseURL)/functions/v1/journal/generate-recent")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 180.0  // Longer timeout for batch generation
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add JWT authentication from Supabase session
        if let session = try? await supabase.auth.session {
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            #if DEBUG
            print("   🔐 JWT token added to request")
            #endif
        } else {
            #if DEBUG
            print("   ⚠️ No active Supabase session - request may fail")
            #endif
        }

        let requestBody: [String: Any] = [
            "athlete_id": athleteId,
            "weeks": weeks
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw JournalError.invalidResponse
        }

        #if DEBUG
        print("   Response Code: \(httpResponse.statusCode)")
        #endif

        switch httpResponse.statusCode {
        case 200:
            do {
                let apiResponse = try JSONDecoder().decode(JournalAPIResponse.self, from: data)

                if apiResponse.success, let entries = apiResponse.entries {
                    #if DEBUG
                    print("   ✅ Success: Generated \(entries.count) journal entries")
                    #endif
                    return entries
                } else {
                    throw JournalError.generationFailed
                }
            } catch let decodingError {
                #if DEBUG
                print("   ❌ Decoding Error: \(decodingError)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("   Raw Response: \(jsonString)")
                }
                #endif
                throw JournalError.decodingFailed(decodingError)
            }

        default:
            if let errorResponse = try? JSONDecoder().decode(JournalAPIResponse.self, from: data),
               let error = errorResponse.error {
                throw JournalError.apiError(error.code, error.message)
            }
            throw JournalError.httpError(httpResponse.statusCode)
        }
    }
}

// MARK: - Error Types
enum JournalError: LocalizedError {
    case invalidResponse
    case noEntriesFound
    case noActivitiesFound
    case generationFailed
    case decodingFailed(Error)
    case apiError(String, String)
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .noEntriesFound:
            return "No journal entries found"
        case .noActivitiesFound:
            return "No activities found for this week"
        case .generationFailed:
            return "Failed to generate journal entry"
        case .decodingFailed(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .apiError(let code, let message):
            return "API Error (\(code)): \(message)"
        case .httpError(let statusCode):
            return "HTTP Error: \(statusCode)"
        }
    }
}
