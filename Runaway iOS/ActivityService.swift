//
//  ActivityService.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 3/14/25.
//


//
//  ActivityService.swift
//  PathPrize
//
//  Created by nagesh sairam on 4/25/24.
//

import Foundation
import Supabase

class ActivityService {
    
    // Function to get all activities
    static func getAllActivities() async throws -> [Activity] {
        return try await supabase
            .from("activities")
            .select("*")
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
    }
}


extension Date {
    var iso8601String: String {
        return ISO8601DateFormatter().string(from: self)
    }
}
