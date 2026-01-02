//
//  QuickWinsService.swift
//  Runaway iOS
//
//  Service for fetching AI-powered Quick Wins insights
//  Uses Supabase Edge Functions for analysis
//

import Foundation

class QuickWinsService: ObservableObject {
    private let session = URLSession.shared
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    @Published var isLoading = false
    @Published var error: QuickWinsError?

    // Edge function configuration
    private var edgeFunctionURL: String {
        let baseURL = SupabaseConfiguration.supabaseURL ?? ""
        return "\(baseURL)/functions/v1/comprehensive-analysis"
    }

    // MARK: - Fetch Comprehensive Analysis

    /// Fetch comprehensive analysis including weather, VO2 max, and training load
    func fetchComprehensiveAnalysis() async throws -> QuickWinsResponse {
        guard let url = URL(string: edgeFunctionURL) else {
            throw QuickWinsError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30.0

        // Add auth headers (JWT token from Supabase)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token = await getJWTToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        #if DEBUG
        print("🏃 Quick Wins Request:")
        print("   URL: \(url)")
        print("   Auth: JWT Token")
        #endif

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw QuickWinsError.invalidResponse
            }

            #if DEBUG
            print("   Response Code: \(httpResponse.statusCode)")
            #endif

            guard 200...299 ~= httpResponse.statusCode else {
                let errorMessage = String(data: data, encoding: .utf8)
                #if DEBUG
                print("   Error Response: \(errorMessage ?? "nil")")
                #endif

                switch httpResponse.statusCode {
                case 401:
                    throw QuickWinsError.unauthorized
                default:
                    throw QuickWinsError.serverError(httpResponse.statusCode)
                }
            }

            do {
                let decodedResponse = try decoder.decode(QuickWinsResponse.self, from: data)
                #if DEBUG
                print("   Successfully decoded QuickWinsResponse")
                #endif
                return decodedResponse
            } catch {
                #if DEBUG
                print("   Decoding error: \(error)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("   Raw Response: \(jsonString.prefix(500))...")
                }
                #endif
                throw QuickWinsError.decodingError(error)
            }

        } catch let error as QuickWinsError {
            throw error
        } catch {
            throw QuickWinsError.networkError(error)
        }
    }

    // MARK: - Private Methods

    private func getJWTToken() async -> String? {
        do {
            let session = try await supabase.auth.session
            return session.accessToken
        } catch {
            #if DEBUG
            print("Failed to get JWT token: \(error)")
            #endif
            return nil
        }
    }

    // MARK: - Helper Methods with Loading State

    /// Fetch with loading state management
    @MainActor
    func fetchWithLoading<T>(
        operation: () async throws -> T
    ) async -> Result<T, QuickWinsError> {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let result = try await operation()
            return .success(result)
        } catch let quickWinsError as QuickWinsError {
            error = quickWinsError
            return .failure(quickWinsError)
        } catch {
            let wrappedError = QuickWinsError.networkError(error)
            self.error = wrappedError
            return .failure(wrappedError)
        }
    }
}
