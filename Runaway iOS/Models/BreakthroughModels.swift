//
//  BreakthroughModels.swift
//  Runaway iOS
//
//  Models for breakthrough milestone moments detected by the coach.
//

import Foundation

struct BreakthroughMilestone: Identifiable, Codable {
    /// Uses activity_id as the stable identifier
    let id: Int
    let type: String
    let title: String
    let coachMessage: String
    let detectedAt: Date
    let activityId: Int
}
