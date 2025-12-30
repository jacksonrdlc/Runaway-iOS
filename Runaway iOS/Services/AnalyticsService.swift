//
//  AnalyticsService.swift
//  Runaway iOS
//
//  Created by Claude on 12/28/25.
//

import Foundation
import UIKit

// MARK: - Analytics Event Categories

enum AnalyticsCategory: String {
    case activity = "activity"
    case audioCoaching = "audio_coaching"
    case navigation = "navigation"
    case authentication = "authentication"
    case strava = "strava"
    case chat = "chat"
    case insights = "insights"
    case goals = "goals"
    case settings = "settings"
    case widget = "widget"
    case liveActivity = "live_activity"
    case error = "error"
    case engagement = "engagement"
}

// MARK: - Predefined Event Names

enum AnalyticsEvent: String {
    // Activity Recording
    case activityStarted = "activity_started"
    case activityPaused = "activity_paused"
    case activityResumed = "activity_resumed"
    case activityStopped = "activity_stopped"
    case activitySaved = "activity_saved"
    case activityDiscarded = "activity_discarded"
    case activityAutoPaused = "activity_auto_paused"
    case activityAutoResumed = "activity_auto_resumed"

    // Audio Coaching
    case audioCoachingEnabled = "audio_coaching_enabled"
    case audioCoachingDisabled = "audio_coaching_disabled"
    case audioPromptSpoken = "audio_prompt_spoken"
    case audioSplitAnnounced = "audio_split_announced"
    case audioPaceAlert = "audio_pace_alert"
    case audioCheckIn = "audio_check_in"
    case voiceInputStarted = "voice_input_started"
    case voiceInputCompleted = "voice_input_completed"
    case voiceCommandRecognized = "voice_command_recognized"

    // Navigation / Screens
    case screenViewed = "screen_viewed"
    case tabSelected = "tab_selected"
    case modalOpened = "modal_opened"
    case modalClosed = "modal_closed"

    // Authentication
    case loginStarted = "login_started"
    case loginCompleted = "login_completed"
    case loginFailed = "login_failed"
    case logoutCompleted = "logout_completed"
    case signupStarted = "signup_started"
    case signupCompleted = "signup_completed"

    // Strava
    case stravaConnectStarted = "strava_connect_started"
    case stravaConnected = "strava_connected"
    case stravaDisconnected = "strava_disconnected"
    case stravaSyncStarted = "strava_sync_started"
    case stravaSyncCompleted = "strava_sync_completed"
    case stravaSyncFailed = "strava_sync_failed"

    // Chat / AI
    case chatMessageSent = "chat_message_sent"
    case chatResponseReceived = "chat_response_received"
    case chatError = "chat_error"

    // Insights
    case insightViewed = "insight_viewed"
    case analysisRequested = "analysis_requested"
    case analysisCompleted = "analysis_completed"

    // Goals
    case goalCreated = "goal_created"
    case goalUpdated = "goal_updated"
    case goalCompleted = "goal_completed"
    case goalDeleted = "goal_deleted"
    case commitmentCreated = "commitment_created"
    case commitmentFulfilled = "commitment_fulfilled"
    case commitmentDeleted = "commitment_deleted"

    // Settings
    case settingChanged = "setting_changed"
    case notificationPermissionRequested = "notification_permission_requested"
    case locationPermissionRequested = "location_permission_requested"

    // Widget
    case widgetRefreshed = "widget_refreshed"
    case widgetTapped = "widget_tapped"

    // Live Activity
    case liveActivityStarted = "live_activity_started"
    case liveActivityUpdated = "live_activity_updated"
    case liveActivityEnded = "live_activity_ended"

    // Errors
    case errorOccurred = "error_occurred"
    case apiError = "api_error"
    case networkError = "network_error"

    // Engagement
    case appOpened = "app_opened"
    case appBackgrounded = "app_backgrounded"
    case sessionStarted = "session_started"
    case sessionEnded = "session_ended"
    case featureUsed = "feature_used"
}

// MARK: - Analytics Service

@MainActor
final class AnalyticsService {

    // MARK: - Singleton

    static let shared = AnalyticsService()

    // MARK: - Properties

    private var sessionId: UUID = UUID()
    private var deviceId: String
    private var eventBuffer: [[String: Any]] = []
    private let bufferSize = 10 // Flush after this many events
    private let flushInterval: TimeInterval = 30 // Or every 30 seconds
    private var flushTimer: Timer?
    private var isEnabled = true

    // Device info (cached)
    private let appVersion: String
    private let osVersion: String
    private let deviceModel: String

    // MARK: - Initialization

    private init() {
        // Get or create persistent device ID
        if let existingId = UserDefaults.standard.string(forKey: "analytics_device_id") {
            self.deviceId = existingId
        } else {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: "analytics_device_id")
            self.deviceId = newId
        }

        // Cache device info
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        self.osVersion = UIDevice.current.systemVersion
        self.deviceModel = UIDevice.current.model

        // Start flush timer
        startFlushTimer()

        print("AnalyticsService: Initialized with device ID: \(deviceId)")
    }

    // MARK: - Public API

    /// Track a simple event
    func track(_ event: AnalyticsEvent, category: AnalyticsCategory) {
        track(event, category: category, properties: nil)
    }

    /// Track an event with properties
    func track(_ event: AnalyticsEvent, category: AnalyticsCategory, properties: [String: Any]?) {
        guard isEnabled else { return }

        let eventData = buildEventData(
            eventName: event.rawValue,
            category: category.rawValue,
            properties: properties
        )

        bufferEvent(eventData)
    }

    /// Track a custom event (for one-off events not in the enum)
    func trackCustom(_ eventName: String, category: AnalyticsCategory, properties: [String: Any]? = nil) {
        guard isEnabled else { return }

        let eventData = buildEventData(
            eventName: eventName,
            category: category.rawValue,
            properties: properties
        )

        bufferEvent(eventData)
    }

    /// Track screen view
    func trackScreen(_ screenName: String, properties: [String: Any]? = nil) {
        var props = properties ?? [:]
        props["screen_name"] = screenName

        track(.screenViewed, category: .navigation, properties: props)
    }

    /// Track an error
    func trackError(_ error: Error, context: String, properties: [String: Any]? = nil) {
        var props = properties ?? [:]
        props["error_message"] = error.localizedDescription
        props["error_context"] = context
        props["error_type"] = String(describing: type(of: error))

        track(.errorOccurred, category: .error, properties: props)
    }

    /// Start a new session (call on app launch/foreground)
    func startSession() {
        sessionId = UUID()
        track(.sessionStarted, category: .engagement, properties: [
            "previous_session": UserDefaults.standard.string(forKey: "last_session_id") ?? "none"
        ])
        UserDefaults.standard.set(sessionId.uuidString, forKey: "last_session_id")
    }

    /// End session (call on app background)
    func endSession() {
        track(.sessionEnded, category: .engagement)
        flush() // Ensure events are sent
    }

    /// Enable/disable analytics
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if !enabled {
            eventBuffer.removeAll()
        }
    }

    /// Force flush all buffered events
    func flush() {
        guard !eventBuffer.isEmpty else { return }

        let eventsToSend = eventBuffer
        eventBuffer.removeAll()

        Task {
            await sendEvents(eventsToSend)
        }
    }

    // MARK: - Convenience Methods for Common Events

    // Activity Events
    func trackActivityStarted(type: String, name: String) {
        track(.activityStarted, category: .activity, properties: [
            "activity_type": type,
            "activity_name": name
        ])
    }

    func trackActivitySaved(type: String, distance: Double, duration: TimeInterval) {
        track(.activitySaved, category: .activity, properties: [
            "activity_type": type,
            "distance_meters": distance,
            "duration_seconds": duration,
            "distance_miles": distance / 1609.34,
            "average_pace": duration > 0 && distance > 0 ? duration / (distance / 1609.34) : 0
        ])
    }

    // Audio Coaching Events
    func trackAudioPrompt(type: String, message: String, elapsedTime: TimeInterval, distance: Double) {
        track(.audioPromptSpoken, category: .audioCoaching, properties: [
            "prompt_type": type,
            "message": message,
            "elapsed_time": elapsedTime,
            "distance_meters": distance
        ])
    }

    func trackSplitAnnounced(splitNumber: Int, pace: TimeInterval, distance: Double) {
        track(.audioSplitAnnounced, category: .audioCoaching, properties: [
            "split_number": splitNumber,
            "pace_seconds": pace,
            "total_distance": distance
        ])
    }

    // Chat Events
    func trackChatMessage(messageLength: Int, hasContext: Bool) {
        track(.chatMessageSent, category: .chat, properties: [
            "message_length": messageLength,
            "has_context": hasContext
        ])
    }

    // Strava Events
    func trackStravaSync(activitiesCount: Int, success: Bool, error: String? = nil) {
        let event: AnalyticsEvent = success ? .stravaSyncCompleted : .stravaSyncFailed
        var props: [String: Any] = [
            "activities_synced": activitiesCount,
            "success": success
        ]
        if let error = error {
            props["error"] = error
        }
        track(event, category: .strava, properties: props)
    }

    // MARK: - Private Methods

    private func buildEventData(eventName: String, category: String, properties: [String: Any]?) -> [String: Any] {
        var data: [String: Any] = [
            "event_name": eventName,
            "event_category": category,
            "created_at": ISO8601DateFormatter().string(from: Date()),
            "device_id": deviceId,
            "session_id": sessionId.uuidString,
            "app_version": appVersion,
            "os_version": osVersion,
            "device_model": deviceModel
        ]

        // Add user ID if available (userId is an Int/BIGINT)
        if let userId = UserSession.shared.userId {
            data["athlete_id"] = userId
        }

        // Add properties as JSON
        if let props = properties {
            data["properties"] = props
        }

        return data
    }

    private func bufferEvent(_ eventData: [String: Any]) {
        eventBuffer.append(eventData)

        #if DEBUG
        print("Analytics: Buffered event '\(eventData["event_name"] ?? "unknown")' (\(eventBuffer.count)/\(bufferSize))")
        #endif

        // Flush if buffer is full
        if eventBuffer.count >= bufferSize {
            flush()
        }
    }

    private func sendEvents(_ events: [[String: Any]]) async {
        guard !events.isEmpty else { return }

        do {
            // Convert events to AnalyticsEventRecord for proper encoding
            let records = events.compactMap { event -> AnalyticsEventRecord? in
                guard let eventName = event["event_name"] as? String,
                      let eventCategory = event["event_category"] as? String else {
                    return nil
                }

                // Convert properties to JSON string
                var propertiesJson: String? = nil
                if let props = event["properties"] as? [String: Any],
                   let jsonData = try? JSONSerialization.data(withJSONObject: props),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    propertiesJson = jsonString
                }

                return AnalyticsEventRecord(
                    event_name: eventName,
                    event_category: eventCategory,
                    properties: propertiesJson,
                    athlete_id: event["athlete_id"] as? Int,
                    device_id: event["device_id"] as? String,
                    session_id: event["session_id"] as? String,
                    app_version: event["app_version"] as? String,
                    os_version: event["os_version"] as? String,
                    device_model: event["device_model"] as? String
                )
            }

            guard !records.isEmpty else { return }

            // Insert batch to Supabase
            try await supabase
                .from("analytics_events")
                .insert(records)
                .execute()

            #if DEBUG
            print("Analytics: Sent \(records.count) events to Supabase")
            #endif

        } catch {
            #if DEBUG
            print("Analytics: Failed to send events: \(error)")
            #endif

            // Re-buffer failed events (with limit to prevent infinite growth)
            if eventBuffer.count < 100 {
                eventBuffer.append(contentsOf: events)
            }
        }
    }
    private func startFlushTimer() {
        flushTimer = Timer.scheduledTimer(withTimeInterval: flushInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.flush()
            }
        }
    }

    deinit {
        flushTimer?.invalidate()
    }
}

// MARK: - Analytics Event Record (for Supabase encoding)

private struct AnalyticsEventRecord: Encodable {
    let event_name: String
    let event_category: String
    let properties: String?
    let athlete_id: Int?
    let device_id: String?
    let session_id: String?
    let app_version: String?
    let os_version: String?
    let device_model: String?
}

// MARK: - SwiftUI View Extension for Screen Tracking

import SwiftUI

extension View {
    /// Track when this view appears
    func trackScreen(_ name: String, properties: [String: Any]? = nil) -> some View {
        self.onAppear {
            Task { @MainActor in
                AnalyticsService.shared.trackScreen(name, properties: properties)
            }
        }
    }
}
