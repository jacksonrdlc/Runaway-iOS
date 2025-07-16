//
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
        return try await supabase
            .from("activities")
            .select("*")
            .order("start_date", ascending: false)
            .execute().value
    }
    
    // Function to get all activities for a user in a time range
    static func getAllActivitiesByUser(userId: Int) async throws -> [Activity] {
        let startOfMonthMinusSevenDays = Date().startOfLastMonth
        let endOfMonth = Date().endOfMonth
        print("Start of month: \(startOfMonthMinusSevenDays)")
        print("End of month: \(endOfMonth)")
        return try await supabase
            .from("activities_with_maps")
            .select(
                """
                id,
                name,
                type,
                summary_polyline,
                distance,
                start_date,
                elapsed_time
                """
            )
            .eq("user_id", value: userId)
            .gte("start_date", value: startOfMonthMinusSevenDays)
//            .lte("start_date", value: endOfMonth)
            .order("start_date", ascending: false)
            .execute().value
    }
    
    // Function to get a single activity by ID
    static func getActivityById(id: Int) async throws -> Activity {
        return try await supabase
            .from("activities")
            .select("*")
            .eq("id", value: id)
            .single()
            .execute().value
    }
    
    // Function to create an activity
    static func createActivity(activity: Activity) async throws -> Activity {
        let activity: Activity = try await supabase.from("activities")
            .insert(activity)
            .select()
            .single()
            .execute()
            .value
        
        // Refresh widgets after creating activity
        WidgetRefreshService.refreshForActivityUpdate()
        
        return activity
    }
    
    // Function to create an activity with custom data (for recording)
    static func createActivity(data: [String: AnyEncodable]) async throws -> Activity {
        let activity: Activity = try await supabase.from("activities")
            .insert(data)
            .select(
                """
                id,
                name,
                type,
                summary_polyline,
                distance,
                start_date,
                elapsed_time
                """
            )
            .single()
            .execute()
            .value
        
        // Refresh widgets after creating activity
        WidgetRefreshService.refreshForActivityUpdate()
        
        return activity
    }
    
    static func updateActivity(id: Int, endTime: Date, endLocationLongitude: Double, endLocationLatitude: Double, status: String) async throws {
        do {
            print("Updating activity with ID: \(id)")
            try await supabase.from("activities")
                .update([
                    "end_time": endTime.iso8601String,
                    "end_location_longitude": String(endLocationLongitude),
                    "end_location_latitude": String(endLocationLatitude),
                    "status": status
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
            .execute().value
        
        // Refresh widgets after deleting activity
        WidgetRefreshService.refreshForActivityUpdate()
    }
}


extension Date {
    var iso8601String: String {
        return ISO8601DateFormatter().string(from: self)
    }
}
