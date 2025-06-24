//
//  UserService.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 6/19/25.
//

import Foundation
import Supabase

class UserService {
    // Function to get athlete by user ID
    static func getUserByAuthId(authId: UUID) async throws -> User {
        return try await supabase
            .from("profiles")
            .select()
            .eq("auth_id", value: authId)
            .single()
            .execute()
            .value
    }
}
