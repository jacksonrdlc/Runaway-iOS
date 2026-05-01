//
//  UserService.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 6/19/25.
//

import Foundation
import Supabase

class UserService {
    private static let decoder = SupabaseDecoder.shared

    // Function to get athlete by auth user ID
    static func getUserByAuthId(authId: UUID) async throws -> User {
        let uuidUppercase = authId.uuidString
        let uuidLowercase = authId.uuidString.lowercased()

        #if DEBUG
        print("🔍 UserService: Looking up user with auth_user_id = \(uuidUppercase)")
        #endif

        // Try with uppercase UUID string format
        let response = try await supabase
            .from("athletes")
            .select()
            .eq("auth_user_id", value: uuidUppercase)
            .execute()

        let data = response.data
        let users = try decoder.decode([User].self, from: data)

        if let user = users.first {
            #if DEBUG
            print("✅ UserService: Found user with athlete ID \(user.userId) (uppercase)")
            #endif
            return user
        }

        // Try with lowercase UUID string (databases often store UUIDs lowercase)
        #if DEBUG
        print("🔄 UserService: Trying lowercase format...")
        #endif
        let response2 = try await supabase
            .from("athletes")
            .select()
            .eq("auth_user_id", value: uuidLowercase)
            .execute()

        let data2 = response2.data
        let users2 = try decoder.decode([User].self, from: data2)

        if let user = users2.first {
            #if DEBUG
            print("✅ UserService: Found user with athlete ID \(user.userId) (lowercase)")
            #endif
            return user
        }

        // Try with UUID directly (for UUID column type)
        #if DEBUG
        print("🔄 UserService: Trying UUID type format...")
        #endif
        let response3 = try await supabase
            .from("athletes")
            .select()
            .eq("auth_user_id", value: authId)
            .execute()

        let data3 = response3.data
        let users3 = try decoder.decode([User].self, from: data3)

        if let user = users3.first {
            #if DEBUG
            print("✅ UserService: Found user with athlete ID \(user.userId) (UUID type)")
            #endif
            return user
        }

        #if DEBUG
        print("❌ UserService: No athlete found for auth_user_id \(authId)")
        #endif
        throw UserServiceError.userNotFound
    }
}

enum UserServiceError: Error, LocalizedError {
    case userNotFound

    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "No athlete record found for this user"
        }
    }
}
