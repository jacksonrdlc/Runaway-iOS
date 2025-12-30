//
//  LiveActivityService.swift
//  Runaway iOS
//
//  Created by Claude on 12/28/25.
//

import Foundation
import ActivityKit

// MARK: - Activity Attributes (Shared with Widget Extension)

/// Attributes for the running Live Activity
/// Note: This must match the definition in RunawayWidgetLiveActivity.swift
struct RunawayWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic state updated during the activity
        var elapsedTime: TimeInterval
        var distance: Double // meters
        var currentPace: Double // seconds per mile
        var averagePace: Double // seconds per mile
        var isPaused: Bool
    }

    // Fixed properties set when activity starts
    var activityType: String
    var startTime: Date
}

// MARK: - Live Activity Service

/// Manages Live Activity for tracking runs on lock screen and Dynamic Island
@MainActor
final class LiveActivityService: ObservableObject {

    // MARK: - Published State

    @Published private(set) var isActivityActive: Bool = false

    // MARK: - Private Properties

    private var currentActivity: ActivityKit.Activity<RunawayWidgetAttributes>?
    private var updateTimer: Timer?

    // MARK: - Singleton

    static let shared = LiveActivityService()

    private init() {}

    // MARK: - Public Methods

    /// Start a new Live Activity for an activity recording
    func startActivity(activityType: String, startTime: Date) {
        // Check if Live Activities are supported
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("LiveActivityService: Live Activities not enabled")
            return
        }

        // End any existing activity
        if currentActivity != nil {
            endActivity()
        }

        // Create attributes and initial state
        let attributes = RunawayWidgetAttributes(
            activityType: activityType,
            startTime: startTime
        )

        let initialState = RunawayWidgetAttributes.ContentState(
            elapsedTime: 0,
            distance: 0,
            currentPace: 0,
            averagePace: 0,
            isPaused: false
        )

        do {
            let activity = try ActivityKit.Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
            isActivityActive = true
            print("LiveActivityService: Started Live Activity with ID: \(activity.id)")
        } catch {
            print("LiveActivityService: Failed to start Live Activity: \(error)")
        }
    }

    /// Update the Live Activity with current recording data
    func updateActivity(
        elapsedTime: TimeInterval,
        distance: Double,
        currentPace: Double,
        averagePace: Double,
        isPaused: Bool
    ) {
        guard let activity = currentActivity else { return }

        let updatedState = RunawayWidgetAttributes.ContentState(
            elapsedTime: elapsedTime,
            distance: distance,
            currentPace: currentPace,
            averagePace: averagePace,
            isPaused: isPaused
        )

        Task {
            await activity.update(
                ActivityContent(
                    state: updatedState,
                    staleDate: Date().addingTimeInterval(60)
                )
            )
        }
    }

    /// End the Live Activity
    func endActivity() {
        guard let activity = currentActivity else { return }

        Task {
            await activity.end(
                ActivityContent(
                    state: activity.content.state,
                    staleDate: nil
                ),
                dismissalPolicy: .immediate
            )
        }

        currentActivity = nil
        isActivityActive = false
        print("LiveActivityService: Ended Live Activity")
    }

    /// End with final stats displayed for a period
    func endActivityWithSummary(
        elapsedTime: TimeInterval,
        distance: Double,
        averagePace: Double
    ) {
        guard let activity = currentActivity else { return }

        let finalState = RunawayWidgetAttributes.ContentState(
            elapsedTime: elapsedTime,
            distance: distance,
            currentPace: 0,
            averagePace: averagePace,
            isPaused: false
        )

        Task {
            await activity.end(
                ActivityContent(
                    state: finalState,
                    staleDate: nil
                ),
                dismissalPolicy: .after(.now + 300) // Show for 5 minutes after completion
            )
        }

        currentActivity = nil
        isActivityActive = false
        print("LiveActivityService: Ended Live Activity with summary")
    }
}
