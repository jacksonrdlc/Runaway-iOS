//
//  QuickWinsService.swift
//  Runaway iOS
//
//  Service for fetching AI-powered Quick Wins insights
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

    // MARK: - Fetch Comprehensive Analysis

    /// Fetch comprehensive analysis including weather, VO2 max, and training load
    func fetchComprehensiveAnalysis() async throws -> QuickWinsResponse {
        return try await performRequest(
            endpoint: APIConfiguration.RunawayCoach.comprehensiveAnalysis,
            method: "GET",
            responseType: QuickWinsResponse.self
        )
    }

    // MARK: - Individual Endpoints

    /// Fetch weather impact analysis
    func fetchWeatherImpact(limit: Int = 30) async throws -> WeatherAnalysis {
        return try await performRequest(
            endpoint: "\(APIConfiguration.RunawayCoach.weatherImpact)?limit=\(limit)",
            method: "GET",
            responseType: WeatherAnalysis.self
        )
    }

    /// Fetch VO2 max estimate and race predictions
    func fetchVO2MaxEstimate(limit: Int = 50) async throws -> VO2MaxEstimate {
        return try await performRequest(
            endpoint: "\(APIConfiguration.RunawayCoach.vo2maxEstimate)?limit=\(limit)",
            method: "GET",
            responseType: VO2MaxEstimate.self
        )
    }

    /// Fetch training load analysis
    func fetchTrainingLoad(limit: Int = 60) async throws -> TrainingLoadAnalysis {
        return try await performRequest(
            endpoint: "\(APIConfiguration.RunawayCoach.trainingLoad)?limit=\(limit)",
            method: "GET",
            responseType: TrainingLoadAnalysis.self
        )
    }

    // MARK: - Private Helper Methods

    private func performRequest<R: Codable>(
        endpoint: String,
        method: String,
        responseType: R.Type
    ) async throws -> R {
        guard let url = URL(string: APIConfiguration.RunawayCoach.currentBaseURL + endpoint) else {
            throw QuickWinsError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = APIConfiguration.RunawayCoach.requestTimeout

        // Add auth headers (JWT token)
        let authHeaders = await APIConfiguration.RunawayCoach.getAuthHeaders()
        for (key, value) in authHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        #if DEBUG
        print("🏃 Quick Wins API Request:")
        print("   URL: \(url)")
        print("   Method: \(method)")
        print("   Auth: Configured")
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
                let decodedResponse = try decoder.decode(responseType, from: data)
                #if DEBUG
                print("   ✅ Successfully decoded \(String(describing: responseType))")
                #endif
                return decodedResponse
            } catch {
                #if DEBUG
                print("   ❌ Decoding error: \(error)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("   Raw Response: \(jsonString.prefix(200))...")
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
