//  ActivityService.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 3/14/25.
//

import Foundation
import Supabase
import WidgetKit

// MARK: - AnyEncodable Helper
struct AnyEncodable: Encodable {
    let value: Encodable
    
    init(_ value: Encodable) {
        self.value = value
    }
    
    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}

class ActivityService {
    
    // Function to get all activities
    static func getAllActivities() async throws -> [Activity] {
        let activities: [Activity] = try await supabase
            .from("activities")
            .select(
                """
                id,
                name,
                athlete_id,
                activity_type_id,
                activity_types!inner(name),
                map_summary_polyline,
                distance,
                activity_date,
                elapsed_time
                """
            )
            .order("activity_date", ascending: false)
            .execute()
            .value
        return activities
    }
    
    // MARK: - Pagination Support

    struct PaginatedResponse<T> {
        let items: [T]
        let hasMore: Bool
        let totalCount: Int?
    }

    static let defaultPageSize = 50

    // Function to get all activities for a user in a time range (with pagination)
    static func getAllActivitiesByUser(userId: Int, limit: Int = defaultPageSize, offset: Int = 0) async throws -> [Activity] {
        let startOfThisYear = Date().startOfThisYear
        print("🔍 ActivityService: Fetching activities for user \(userId) (limit: \(limit), offset: \(offset))")

        let activities: [Activity] = try await supabase
            .from("activities")
            .select(
                """
                id,
                name,
                athlete_id,
                activity_type_id,
                activity_types!inner(name),
                map_summary_polyline,
                distance,
                activity_date,
                elapsed_time
                """
            )
            .eq("athlete_id", value: userId)
            .gte("activity_date", value: startOfThisYear)
            .order("activity_date", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value

        print("🔍 ActivityService: Successfully fetched \(activities.count) activities")
        return activities
    }

    // Function to get paginated activities with hasMore indicator
    static func getActivitiesPaginated(userId: Int, page: Int = 0, pageSize: Int = defaultPageSize) async throws -> PaginatedResponse<Activity> {
        let offset = page * pageSize
        let activities = try await getAllActivitiesByUser(userId: userId, limit: pageSize + 1, offset: offset)

        let hasMore = activities.count > pageSize
        let items = hasMore ? Array(activities.dropLast()) : activities

        return PaginatedResponse(items: items, hasMore: hasMore, totalCount: nil)
    }

    // Function to load all activities (for backwards compatibility) - loads in batches
    static func getAllActivitiesByUserComplete(userId: Int) async throws -> [Activity] {
        var allActivities: [Activity] = []
        var offset = 0
        let batchSize = 100

        while true {
            let batch = try await getAllActivitiesByUser(userId: userId, limit: batchSize, offset: offset)
            allActivities.append(contentsOf: batch)

            if batch.count < batchSize {
                break // No more activities
            }
            offset += batchSize
        }

        print("🔍 ActivityService: Loaded \(allActivities.count) total activities")
        return allActivities
    }
    
    // Function to get a single activity by ID
    static func getActivityById(id: Int) async throws -> Activity {
        let activity: Activity = try await supabase
            .from("activities")
            .select(
                """
                id,
                name,
                athlete_id,
                activity_type_id,
                activity_types!inner(name),
                map_summary_polyline,
                distance,
                activity_date,
                elapsed_time
                """
            )
            .eq("id", value: id)
            .single()
            .execute()
            .value
        return activity
    }
    
    // Function to create an activity
    static func createActivity(activity: Activity) async throws -> Activity {
        let createdActivity: Activity = try await supabase.from("activities")
            .insert(activity)
            .select(
                """
                id,
                name,
                athlete_id,
                activity_type_id,
                activity_types!inner(name),
                map_summary_polyline,
                distance,
                activity_date,
                elapsed_time
                """
            )
            .single()
            .execute()
            .value

        // Refresh widgets after creating activity
        WidgetRefreshService.refreshForActivityUpdate()

        return createdActivity
    }
    
    // Function to create an activity with custom data (for recording)
    static func createActivity(data: [String: AnyEncodable]) async throws -> Activity {
        let createdActivity: Activity = try await supabase.from("activities")
            .insert(data)
            .select(
                """
                id,
                name,
                athlete_id,
                activity_type_id,
                activity_types!inner(name),
                map_summary_polyline,
                distance,
                activity_date,
                elapsed_time
                """
            )
            .single()
            .execute()
            .value

        // Refresh widgets after creating activity
        WidgetRefreshService.refreshForActivityUpdate()

        return createdActivity
    }
    
    // Function to create an activity with enhanced data (matching new schema)
    static func createActivityWithFullData(
        athleteId: Int,
        activityTypeId: Int,
        name: String,
        description: String? = nil,
        activityDate: Date,
        elapsedTime: Int,
        movingTime: Int? = nil,
        distance: Double,
        elevationGain: Double? = nil,
        elevationLoss: Double? = nil,
        maxSpeed: Double? = nil,
        averageSpeed: Double? = nil,
        maxHeartRate: Int? = nil,
        averageHeartRate: Int? = nil,
        calories: Int? = nil,
        mapPolyline: String? = nil,
        mapSummaryPolyline: String? = nil,
        startLatitude: Double? = nil,
        startLongitude: Double? = nil,
        endLatitude: Double? = nil,
        endLongitude: Double? = nil,
        commute: Bool = false,
        gearId: Int? = nil
    ) async throws -> Activity {
        var data: [String: AnyEncodable] = [
            "athlete_id": AnyEncodable(athleteId),
            "activity_type_id": AnyEncodable(activityTypeId),
            "name": AnyEncodable(name),
            "activity_date": AnyEncodable(activityDate.iso8601String),
            "elapsed_time": AnyEncodable(elapsedTime),
            "distance": AnyEncodable(distance),
            "commute": AnyEncodable(commute)
        ]
        
        // Add optional fields if provided
        if let description = description { data["description"] = AnyEncodable(description) }
        if let movingTime = movingTime { data["moving_time"] = AnyEncodable(movingTime) }
        if let elevationGain = elevationGain { data["elevation_gain"] = AnyEncodable(elevationGain) }
        if let elevationLoss = elevationLoss { data["elevation_loss"] = AnyEncodable(elevationLoss) }
        if let maxSpeed = maxSpeed { data["max_speed"] = AnyEncodable(maxSpeed) }
        if let averageSpeed = averageSpeed { data["average_speed"] = AnyEncodable(averageSpeed) }
        if let maxHeartRate = maxHeartRate { data["max_heart_rate"] = AnyEncodable(maxHeartRate) }
        if let averageHeartRate = averageHeartRate { data["average_heart_rate"] = AnyEncodable(averageHeartRate) }
        if let calories = calories { data["calories"] = AnyEncodable(calories) }
        if let mapPolyline = mapPolyline { data["map_polyline"] = AnyEncodable(mapPolyline) }
        if let mapSummaryPolyline = mapSummaryPolyline { data["map_summary_polyline"] = AnyEncodable(mapSummaryPolyline) }
        if let startLatitude = startLatitude { data["start_latitude"] = AnyEncodable(startLatitude) }
        if let startLongitude = startLongitude { data["start_longitude"] = AnyEncodable(startLongitude) }
        if let endLatitude = endLatitude { data["end_latitude"] = AnyEncodable(endLatitude) }
        if let endLongitude = endLongitude { data["end_longitude"] = AnyEncodable(endLongitude) }
        if let gearId = gearId { data["gear_id"] = AnyEncodable(gearId) }
        
        return try await createActivity(data: data)
    }

    // Function to get activities with activity type information
    static func getActivitiesWithTypes(userId: Int) async throws -> [Activity] {
        let activities: [Activity] = try await supabase
            .from("activities")
            .select(
                """
                id,
                name,
                activity_types!inner(name, category),
                map_summary_polyline,
                distance,
                activity_date,
                elapsed_time,
                elevation_gain,
                average_speed,
                average_heart_rate,
                calories
                """
            )
            .eq("athlete_id", value: userId)
            .order("activity_date", ascending: false)
            .execute()
            .value
        return activities
    }

    // Function to get activities by type
    static func getActivitiesByType(userId: Int, activityTypeId: Int) async throws -> [Activity] {
        let activities: [Activity] = try await supabase
            .from("activities")
            .select(
                """
                id,
                name,
                athlete_id,
                activity_type_id,
                activity_types!inner(name),
                map_summary_polyline,
                distance,
                activity_date,
                elapsed_time
                """
            )
            .eq("athlete_id", value: userId)
            .eq("activity_type_id", value: activityTypeId)
            .order("activity_date", ascending: false)
            .execute()
            .value
        return activities
    }

    // Function to get activities by date range
    static func getActivitiesByDateRange(userId: Int, startDate: Date, endDate: Date) async throws -> [Activity] {
        let activities: [Activity] = try await supabase
            .from("activities")
            .select(
                """
                id,
                name,
                athlete_id,
                activity_type_id,
                activity_types!inner(name),
                map_summary_polyline,
                distance,
                activity_date,
                elapsed_time
                """
            )
            .eq("athlete_id", value: userId)
            .gte("activity_date", value: startDate.iso8601String)
            .lte("activity_date", value: endDate.iso8601String)
            .order("activity_date", ascending: false)
            .execute()
            .value
        return activities
    }

    static func updateActivity(id: Int, endTime: Date, endLocationLongitude: Double, endLocationLatitude: Double, status: String) async throws {
        do {
            print("Updating activity with ID: \(id)")
            try await supabase.from("activities")
                .update([
                    "end_latitude": endLocationLatitude,
                    "end_longitude": endLocationLongitude,
                    // Note: The ERD shows activities don't have a 'status' field, 
                    // you may need to add this field to your database if needed
                    // "status": status
                ])
                .eq("id", value: id)
                .execute()
            print("Activity successfully updated")
            
            // Refresh widgets after updating activity
            WidgetRefreshService.refreshForActivityUpdate()
        } catch {
            print("Failed to update activity: \(error)")
            throw error  // Optionally rethrow to handle elsewhere
        }
    }
    
    // Function to delete an activity
    static func deleteActivity(id: Int) async throws {
        _ = try await supabase
            .from("activities")
            .delete()
            .eq("id", value: id)
            .execute()
            .value

        // Refresh widgets after deleting activity
        WidgetRefreshService.refreshForActivityUpdate()
    }

    // MARK: - Aggregated Stats (Database Functions)

    /// Response from get_yearly_running_stats database function
    struct YearlyRunningStats: Codable {
        let year: Int
        let total_runs: Int
        let total_distance_meters: Double
        let total_distance_miles: Double
        let total_moving_time_seconds: Int64
        let total_elapsed_time_seconds: Int64
        let total_elevation_gain_meters: Double
        let average_pace_per_mile_seconds: Double?
        let longest_run_meters: Double
        let fastest_pace_per_mile_seconds: Double?
    }

    /// Response from get_monthly_running_stats database function
    struct MonthlyRunningStats: Codable {
        let year: Int
        let month: Int
        let total_runs: Int
        let total_distance_meters: Double
        let total_distance_miles: Double
        let total_moving_time_seconds: Int64
        let total_elevation_gain_meters: Double
        let average_pace_per_mile_seconds: Double?
    }

    /// Get yearly running stats from database (not affected by pagination)
    static func getYearlyRunningStats(athleteId: Int, year: Int? = nil) async throws -> YearlyRunningStats {
        let targetYear = year ?? Calendar.current.component(.year, from: Date())

        let stats: [YearlyRunningStats] = try await supabase
            .rpc("get_yearly_running_stats", params: [
                "p_athlete_id": athleteId,
                "p_year": targetYear
            ])
            .execute()
            .value

        guard let result = stats.first else {
            // Return empty stats if no data
            return YearlyRunningStats(
                year: targetYear,
                total_runs: 0,
                total_distance_meters: 0,
                total_distance_miles: 0,
                total_moving_time_seconds: 0,
                total_elapsed_time_seconds: 0,
                total_elevation_gain_meters: 0,
                average_pace_per_mile_seconds: nil,
                longest_run_meters: 0,
                fastest_pace_per_mile_seconds: nil
            )
        }

        return result
    }

    /// Get monthly running stats from database
    static func getMonthlyRunningStats(athleteId: Int, year: Int? = nil, month: Int? = nil) async throws -> MonthlyRunningStats {
        let now = Date()
        let targetYear = year ?? Calendar.current.component(.year, from: now)
        let targetMonth = month ?? Calendar.current.component(.month, from: now)

        let stats: [MonthlyRunningStats] = try await supabase
            .rpc("get_monthly_running_stats", params: [
                "p_athlete_id": athleteId,
                "p_year": targetYear,
                "p_month": targetMonth
            ])
            .execute()
            .value

        guard let result = stats.first else {
            // Return empty stats if no data
            return MonthlyRunningStats(
                year: targetYear,
                month: targetMonth,
                total_runs: 0,
                total_distance_meters: 0,
                total_distance_miles: 0,
                total_moving_time_seconds: 0,
                total_elevation_gain_meters: 0,
                average_pace_per_mile_seconds: nil
            )
        }

        return result
    }
}
