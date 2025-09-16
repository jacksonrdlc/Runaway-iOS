//
//  WidgetRefreshService.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 7/10/25.
//

import Foundation
import WidgetKit

class WidgetRefreshService {
    static let shared = WidgetRefreshService()
    
    private init() {}
    
    // MARK: - Widget Refresh Methods
    
    /// Refresh all widgets immediately
    static func refreshAllWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
        print("🔄 All widgets refreshed")
    }
    
    /// Refresh specific widget kind
    static func refreshWidget(kind: String) {
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
        print("🔄 Widget '\(kind)' refreshed")
    }
    
    /// Refresh widgets after a delay (useful for batch operations)
    static func refreshWidgetsAfterDelay(_ delay: TimeInterval = 0.5) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            refreshAllWidgets()
        }
    }
    
    // MARK: - Data-Specific Refresh Methods
    
    /// Refresh widgets after activity data changes
    static func refreshForActivityUpdate() {
        refreshAllWidgets()
    }
    
    /// Refresh widgets after goal changes
    static func refreshForGoalUpdate() {
        refreshAllWidgets()
    }
    
    /// Refresh widgets after user profile changes
    static func refreshForUserUpdate() {
        refreshAllWidgets()
    }
    
    /// Refresh widgets after authentication changes
    static func refreshForAuthUpdate() {
        refreshAllWidgets()
    }
    
    /// Refresh widgets after location changes
    static func refreshForLocationUpdate() {
        refreshAllWidgets()
    }
}

// MARK: - Widget Refresh Convenience Extensions

extension ActivityService {
    /// Refresh widgets after activity operations
    private static func refreshWidgets() {
        WidgetRefreshService.refreshForActivityUpdate()
    }
}

extension GoalService {
    /// Refresh widgets after goal operations
    private static func refreshWidgets() {
        WidgetRefreshService.refreshForGoalUpdate()
    }
}