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
    
    // Function to get all activities for a user in a time range
    static func getAllActivitiesByUser(userId: Int) async throws -> [Activity] {
        let startOfThisYear = Date().startOfThisYear
        print("🔍 ActivityService: Start of year: \(startOfThisYear)")
        print("🔍 ActivityService: Fetching activities for user \(userId)")

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
            .execute()
            .value

        print("🔍 ActivityService: Successfully fetched \(activities.count) activities")
        if let firstActivity = activities.first {
            print("🔍 ActivityService: First activity type: '\(firstActivity.type ?? "nil")'")
        }

        return activities
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
}
