//
//  AppIntent.swift
//  RunawayWidget
//
//  Created by Jack Rudelic on 2/18/25.
//

import WidgetKit
import AppIntents
import SwiftUI

// Activity Type Entity for App Intents
struct ActivityTypeEntity: AppEntity {
    var id: String
    var name: String
    var color: String // Hex color string

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Activity Type")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    static var defaultQuery = ActivityTypeQuery()
}

// Query to provide available activity types
struct ActivityTypeQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ActivityTypeEntity] {
        availableActivityTypes.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [ActivityTypeEntity] {
        availableActivityTypes
    }

    // All available activity types with their colors
    var availableActivityTypes: [ActivityTypeEntity] {
        [
            ActivityTypeEntity(id: "run", name: "Run", color: "#3399FF"),
            ActivityTypeEntity(id: "walk", name: "Walk", color: "#66CC66"),
            ActivityTypeEntity(id: "weight_training", name: "Weight Training", color: "#FFB300"),
            ActivityTypeEntity(id: "yoga", name: "Yoga", color: "#CC66CC"),
            ActivityTypeEntity(id: "bike_ride", name: "Bike Ride", color: "#FF6B6B"),
            ActivityTypeEntity(id: "hike", name: "Hike", color: "#8B4513"),
            ActivityTypeEntity(id: "swim", name: "Swim", color: "#00CED1"),
            ActivityTypeEntity(id: "elliptical", name: "Elliptical", color: "#9370DB"),
            ActivityTypeEntity(id: "rowing", name: "Rowing", color: "#FF8C00"),
            ActivityTypeEntity(id: "stairmaster", name: "Stairmaster", color: "#32CD32")
        ]
    }
}

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Configuration" }
    static var description: IntentDescription { "Choose which activities to display in your widget." }

    @Parameter(title: "Activities to Display", description: "Select up to 4 activities", size: .init(exactly: 4))
    var selectedActivities: [ActivityTypeEntity]?

    init() {
        // Default to Run, Walk, Weight Training, Yoga
        self.selectedActivities = [
            ActivityTypeEntity(id: "run", name: "Run", color: "#3399FF"),
            ActivityTypeEntity(id: "walk", name: "Walk", color: "#66CC66"),
            ActivityTypeEntity(id: "weight_training", name: "Weight Training", color: "#FFB300"),
            ActivityTypeEntity(id: "yoga", name: "Yoga", color: "#CC66CC")
        ]
    }

    init(selectedActivities: [ActivityTypeEntity]?) {
        self.selectedActivities = selectedActivities
    }
}
