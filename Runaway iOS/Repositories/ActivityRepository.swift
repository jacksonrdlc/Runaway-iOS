//
//  ActivityRepository.swift
//  Runaway iOS
//
//  Created by Claude on 12/23/25.
//

import Foundation

// MARK: - Activity Repository Protocol

/// Protocol defining activity data access operations
/// Enables dependency injection and testability
protocol ActivityRepositoryProtocol {
    func getActivities(userId: Int, limit: Int, offset: Int) async throws -> [Activity]
    func getActivitiesPaginated(userId: Int, page: Int, pageSize: Int) async throws -> PaginatedResult<Activity>
    func getAllActivities(userId: Int) async throws -> [Activity]
    func getActivity(id: Int) async throws -> Activity
    func createActivity(_ activity: Activity) async throws -> Activity
    func updateActivity(_ activity: Activity) async throws -> Activity
    func deleteActivity(id: Int) async throws
    func getActivitiesByDateRange(userId: Int, startDate: Date, endDate: Date) async throws -> [Activity]
    func getActivitiesByType(userId: Int, activityTypeId: Int) async throws -> [Activity]
}

// MARK: - Paginated Result

struct PaginatedResult<T> {
    let items: [T]
    let hasMore: Bool
    let page: Int
    let pageSize: Int
    let totalCount: Int?

    var nextPage: Int? {
        hasMore ? page + 1 : nil
    }
}

// MARK: - Supabase Activity Repository

/// Concrete implementation using Supabase
final class SupabaseActivityRepository: ActivityRepositoryProtocol {

    static let shared = SupabaseActivityRepository()

    private let defaultPageSize = 50

    private init() {}

    func getActivities(userId: Int, limit: Int = 50, offset: Int = 0) async throws -> [Activity] {
        return try await ActivityService.getAllActivitiesByUser(userId: userId, limit: limit, offset: offset)
    }

    func getActivitiesPaginated(userId: Int, page: Int = 0, pageSize: Int = 50) async throws -> PaginatedResult<Activity> {
        let response = try await ActivityService.getActivitiesPaginated(userId: userId, page: page, pageSize: pageSize)
        return PaginatedResult(
            items: response.items,
            hasMore: response.hasMore,
            page: page,
            pageSize: pageSize,
            totalCount: response.totalCount
        )
    }

    func getAllActivities(userId: Int) async throws -> [Activity] {
        return try await ActivityService.getAllActivitiesByUserComplete(userId: userId)
    }

    func getActivity(id: Int) async throws -> Activity {
        return try await ActivityService.getActivityById(id: id)
    }

    func createActivity(_ activity: Activity) async throws -> Activity {
        return try await ActivityService.createActivity(activity: activity)
    }

    func updateActivity(_ activity: Activity) async throws -> Activity {
        // Note: ActivityService doesn't have a full update method
        // Return the activity as-is since ActivityService.updateActivity is limited
        return activity
    }

    func deleteActivity(id: Int) async throws {
        try await ActivityService.deleteActivity(id: id)
    }

    func getActivitiesByDateRange(userId: Int, startDate: Date, endDate: Date) async throws -> [Activity] {
        return try await ActivityService.getActivitiesByDateRange(userId: userId, startDate: startDate, endDate: endDate)
    }

    func getActivitiesByType(userId: Int, activityTypeId: Int) async throws -> [Activity] {
        return try await ActivityService.getActivitiesByType(userId: userId, activityTypeId: activityTypeId)
    }
}

// MARK: - Mock Activity Repository (for testing)

#if DEBUG
final class MockActivityRepository: ActivityRepositoryProtocol {

    var mockActivities: [Activity] = []
    var shouldThrowError = false
    var errorToThrow: Error?

    func getActivities(userId: Int, limit: Int, offset: Int) async throws -> [Activity] {
        if shouldThrowError { throw errorToThrow ?? RepositoryError.networkError }
        let end = min(offset + limit, mockActivities.count)
        guard offset < mockActivities.count else { return [] }
        return Array(mockActivities[offset..<end])
    }

    func getActivitiesPaginated(userId: Int, page: Int, pageSize: Int) async throws -> PaginatedResult<Activity> {
        let activities = try await getActivities(userId: userId, limit: pageSize + 1, offset: page * pageSize)
        let hasMore = activities.count > pageSize
        let items = hasMore ? Array(activities.dropLast()) : activities
        return PaginatedResult(items: items, hasMore: hasMore, page: page, pageSize: pageSize, totalCount: mockActivities.count)
    }

    func getAllActivities(userId: Int) async throws -> [Activity] {
        if shouldThrowError { throw errorToThrow ?? RepositoryError.networkError }
        return mockActivities
    }

    func getActivity(id: Int) async throws -> Activity {
        if shouldThrowError { throw errorToThrow ?? RepositoryError.networkError }
        guard let activity = mockActivities.first(where: { $0.id == id }) else {
            throw RepositoryError.notFound
        }
        return activity
    }

    func createActivity(_ activity: Activity) async throws -> Activity {
        if shouldThrowError { throw errorToThrow ?? RepositoryError.networkError }
        mockActivities.insert(activity, at: 0)
        return activity
    }

    func updateActivity(_ activity: Activity) async throws -> Activity {
        if shouldThrowError { throw errorToThrow ?? RepositoryError.networkError }
        if let index = mockActivities.firstIndex(where: { $0.id == activity.id }) {
            mockActivities[index] = activity
        }
        return activity
    }

    func deleteActivity(id: Int) async throws {
        if shouldThrowError { throw errorToThrow ?? RepositoryError.networkError }
        mockActivities.removeAll { $0.id == id }
    }

    func getActivitiesByDateRange(userId: Int, startDate: Date, endDate: Date) async throws -> [Activity] {
        if shouldThrowError { throw errorToThrow ?? RepositoryError.networkError }
        return mockActivities.filter { activity in
            guard let date = activity.activity_date ?? activity.start_date else { return false }
            let activityDate = Date(timeIntervalSince1970: date)
            return activityDate >= startDate && activityDate <= endDate
        }
    }

    func getActivitiesByType(userId: Int, activityTypeId: Int) async throws -> [Activity] {
        if shouldThrowError { throw errorToThrow ?? RepositoryError.networkError }
        return mockActivities.filter { $0.activity_type_id == activityTypeId }
    }
}
#endif

// MARK: - Repository Errors

enum RepositoryError: LocalizedError {
    case notFound
    case networkError
    case invalidData(String)
    case unauthorized
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "The requested resource was not found"
        case .networkError:
            return "A network error occurred"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .unauthorized:
            return "You are not authorized to perform this action"
        case .serverError(let code):
            return "Server error (code: \(code))"
        }
    }
}
