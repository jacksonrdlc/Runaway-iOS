//
//  APIRequestManager.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 9/14/25.
//

import Foundation

// MARK: - API Request Manager

class APIRequestManager {
    static let shared = APIRequestManager()

    private var pendingRequests: [String: Task<Any, Error>] = [:]
    private let requestQueue = DispatchQueue(label: "api.request.queue", attributes: .concurrent)

    private init() {}

    // MARK: - Request Deduplication

    func performRequest<T: Codable>(
        key: String,
        timeout: TimeInterval = 30.0,
        request: @escaping () async throws -> T
    ) async throws -> T {
        // Check if request is already in progress
        if let existingTask = pendingRequests[key] {
            return try await withTimeout(timeout: timeout) {
                return try await existingTask.value as! T
            }
        }

        // Create new request task
        let task = Task<Any, Error> {
            do {
                let result = try await request()
                requestQueue.async(flags: .barrier) {
                    self.pendingRequests.removeValue(forKey: key)
                }
                return result
            } catch {
                requestQueue.async(flags: .barrier) {
                    self.pendingRequests.removeValue(forKey: key)
                }
                throw error
            }
        }

        // Store the task
        requestQueue.async(flags: .barrier) {
            self.pendingRequests[key] = task
        }

        return try await withTimeout(timeout: timeout) {
            return try await task.value as! T
        }
    }

    private func withTimeout<T>(timeout: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            // Add the main operation
            group.addTask {
                try await operation()
            }

            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw APIRequestError.timeout
            }

            // Return the first one to complete
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    // MARK: - Request Key Generation

    static func generateKey(endpoint: String, parameters: [String: Any]?) -> String {
        let paramString = parameters?.sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&") ?? ""
        return "\(endpoint)?\(paramString)".hash.description
    }

    static func generateKeyForActivities(_ activities: [Activity], endpoint: String) -> String {
        let activityIds = activities.map { String($0.id) }.sorted().joined(separator: ",")
        return "\(endpoint)_\(activityIds)".hash.description
    }

    // MARK: - Cancel Requests

    func cancelRequest(key: String) {
        requestQueue.async(flags: .barrier) {
            self.pendingRequests[key]?.cancel()
            self.pendingRequests.removeValue(forKey: key)
        }
    }

    func cancelAllRequests() {
        requestQueue.async(flags: .barrier) {
            for task in self.pendingRequests.values {
                task.cancel()
            }
            self.pendingRequests.removeAll()
        }
    }
}

// MARK: - API Request Error

enum APIRequestError: LocalizedError {
    case timeout
    case duplicateRequest
    case cancelled

    var errorDescription: String? {
        switch self {
        case .timeout:
            return "Request timed out"
        case .duplicateRequest:
            return "Duplicate request in progress"
        case .cancelled:
            return "Request was cancelled"
        }
    }
}