//  ActivityTypeService.swift
//  Runaway iOS
//
//  Created by Assistant on 9/29/25.
//

import Foundation
import Supabase

// MARK: - Activity Type Models
struct ActivityType: Identifiable, Codable {
    let id: Int
    let name: String
    let category: String?
    let description: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, category, description
    }
}

class ActivityTypeService {
    
    // Function to get all activity types
    static func getAllActivityTypes() async throws -> [ActivityType] {
        return try await supabase
            .from("activity_types")
            .select("*")
            .order("name", ascending: true)
            .execute().value
    }
    
    // Function to get activity types by category
    static func getActivityTypesByCategory(category: String) async throws -> [ActivityType] {
        return try await supabase
            .from("activity_types")
            .select("*")
            .eq("category", value: category)
            .order("name", ascending: true)
            .execute().value
    }
    
    // Function to get a single activity type by ID
    static func getActivityTypeById(id: Int) async throws -> ActivityType {
        return try await supabase
            .from("activity_types")
            .select("*")
            .eq("id", value: id)
            .single()
            .execute().value
    }
    
    // Function to get activity type by name
    static func getActivityTypeByName(name: String) async throws -> ActivityType? {
        let result: [ActivityType] = try await supabase
            .from("activity_types")
            .select("*")
            .eq("name", value: name)
            .execute().value
        
        return result.first
    }
    
    // Function to create an activity type
    static func createActivityType(name: String, category: String? = nil, description: String? = nil) async throws -> ActivityType {
        struct CreateActivityTypeData: Encodable {
            let name: String
            let category: String?
            let description: String?
        }

        let data = CreateActivityTypeData(name: name, category: category, description: description)

        return try await supabase.from("activity_types")
            .insert(data)
            .select()
            .single()
            .execute()
            .value
    }
    
    // Function to update an activity type
    static func updateActivityType(id: Int, name: String? = nil, category: String? = nil, description: String? = nil) async throws {
        struct UpdateActivityTypeData: Encodable {
            let name: String?
            let category: String?
            let description: String?

            var isEmpty: Bool {
                return name == nil && category == nil && description == nil
            }
        }

        let data = UpdateActivityTypeData(name: name, category: category, description: description)
        guard !data.isEmpty else { return } // No updates to make

        try await supabase.from("activity_types")
            .update(data)
            .eq("id", value: id)
            .execute()
    }
    
    // Function to delete an activity type
    static func deleteActivityType(id: Int) async throws {
        _ = try await supabase
            .from("activity_types")
            .delete()
            .eq("id", value: id)
            .execute().value
    }
}