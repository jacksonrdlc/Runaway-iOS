//
//  AppConstants.swift
//  Runaway iOS
//
//  Shared constants used across app and widget targets.
//

import Foundation

enum AppConstants {

    enum AppGroup {
        static let identifier = "group.com.jackrudelic.runawayios"
    }

    enum Conversion {
        static let metersToMiles: Double = 0.000621371
        static let secondsToMinutes: Double = 1.0 / 60.0
    }

    enum WidgetKeys {
        static let yearlyMiles = "miles"
        static let monthlyMiles = "monthlyMiles"
        static let totalRuns = "runs"
        static let weeklyGoalMiles = "weekly_goal_miles"
        static let monthlyGoalMiles = "monthly_goal_miles"
        static let preferredDistanceUnit = "preferred_distance_unit"
        static let athleteId = "widget_athlete_id"
        static let supabaseURL = "widget_supabase_url"
        static let supabaseKey = "widget_supabase_key"
        static let todaysCommitmentType = "todays_commitment_type"
        static let todaysCommitmentFulfilled = "todays_commitment_fulfilled"
        static let currentLocation = "currentLocation"

        // Training Phase & Race Keys
        static let currentPhase = "current_training_phase"
        static let currentPhaseIcon = "current_phase_icon"
        static let daysUntilRace = "days_until_race"
        static let nextRaceName = "next_race_name"
        static let twinMessage = "widget_twin_message"
        static let volumeChange = "widget_volume_change"

        static let dayKeys: [String: String] = [
            "Sunday": "sunArray",
            "Monday": "monArray",
            "Tuesday": "tueArray",
            "Wednesday": "wedArray",
            "Thursday": "thuArray",
            "Friday": "friArray",
            "Saturday": "satArray"
        ]

        static let allDayKeys = ["sunArray", "monArray", "tueArray", "wedArray", "thuArray", "friArray", "satArray"]
    }

    enum ActivityTypes {
        static let widgetRelevant: Set<String> = [
            "run", "trail run", "trailrun", "trail_run", "walk",
            "weight training", "weighttraining", "yoga",
            "bike ride", "bike_ride", "hike", "swim",
            "elliptical", "rowing", "stairmaster", "golf"
        ]

        static func normalize(_ raw: String) -> String {
            switch raw.lowercased() {
            case "weighttraining": return "Weight Training"
            case "trailrun": return "Trail Run"
            default: return raw
            }
        }
    }

    enum RealtimeMonitoring {
        static let heartbeatInterval: TimeInterval = 30
        static let healthyThreshold: TimeInterval = 60
        static let degradedThreshold: TimeInterval = 300
    }

    enum Mindset {
        static let coreValuePresets: [String] = [
            "consistency", "mental health", "stress relief", "community",
            "competition", "adventure", "fitness", "routine", "solitude", "speed"
        ]
    }
}
