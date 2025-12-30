//
//  Router.swift
//  Runaway iOS
//
//  Centralized navigation router for app-wide navigation management
//  Uses NavigationStack (iOS 16+) for programmatic navigation
//

import SwiftUI

@Observable
class AppRouter {
    var path = NavigationPath()

    // MARK: - Route Definitions

    enum Route: Hashable {
        // Activity Routes
        case activityDetail(Int) // Activity ID
        case activityList

        // Recording Routes
        case record // Pre-recording view
        case activeRecording // Active recording view

        // Profile & Settings Routes
        case settings
        case accountInfo
        case profile(Int) // Athlete ID

        // Commitment & Goals Routes
        case commitmentSetup
        case commitmentHistory
        case goalManagement
        case goalDetail(Int) // Goal ID

        // Journal Routes
        case journalEntry(Int?) // Activity ID
        case journalList

        // Strava Routes
        case stravaConnect
        case stravaSettings

        // Analysis Routes
        case activityInsights(Int) // Activity ID
    }

    // MARK: - Navigation Methods

    /// Navigate to a specific route
    func navigate(to route: Route) {
        path.append(route)
    }

    /// Pop the current view from the stack
    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    /// Pop to the root view
    func popToRoot() {
        path.removeLast(path.count)
    }

    /// Pop to a specific depth in the navigation stack
    func pop(count: Int) {
        guard count > 0, count <= path.count else { return }
        path.removeLast(count)
    }

    /// Replace the current route with a new one
    func replace(with route: Route) {
        if !path.isEmpty {
            path.removeLast()
        }
        path.append(route)
    }

    // MARK: - Deep Linking

    /// Handle deep link URLs
    func handleDeepLink(_ url: URL) {
        // Parse URL and navigate accordingly
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return
        }

        switch components.path {
        case "/activity":
            if let activityId = components.queryItems?.first(where: { $0.name == "id" })?.value {
                // Would need to fetch activity and navigate
                print("Deep link to activity: \(activityId)")
            }
        case "/settings":
            navigate(to: .settings)
        case "/commitment":
            navigate(to: .commitmentSetup)
        case "/goals":
            navigate(to: .goalManagement)
        case "/record", "/run", "/start-run":
            navigate(to: .record)
        default:
            break
        }
    }

    // MARK: - State Management

    /// Check if we're at the root
    var isAtRoot: Bool {
        path.isEmpty
    }

    /// Get the current depth of the navigation stack
    var depth: Int {
        path.count
    }
}

// MARK: - View Extensions

extension View {
    /// Configure navigation destinations for the app router
    func withAppRouter(_ router: AppRouter) -> some View {
        self
            .navigationDestination(for: AppRouter.Route.self) { route in
                router.destination(for: route)
            }
            .environment(router)
    }
}

// MARK: - Destination Builder

extension AppRouter {
    @ViewBuilder
    func destination(for route: Route) -> some View {
        switch route {
        case .activityDetail(let activityId):
            ActivityDetailPlaceholder(activityId: activityId)

        case .activityList:
            ActivitiesView()

        case .record:
            // Recording views are handled separately via MainView tabs
            // This case is for deep link navigation only
            Text("Opening recording view...")
                .onAppear {
                    NotificationCenter.default.post(name: .navigateToRecordTab, object: nil)
                }

        case .activeRecording:
            Text("Opening active recording...")
                .onAppear {
                    NotificationCenter.default.post(name: .navigateToRecordTab, object: nil)
                }

        case .settings:
            SettingsView()

        case .accountInfo:
            AccountInformationView()

        case .profile(let athleteId):
            ProfilePlaceholder(athleteId: athleteId)

        case .commitmentSetup:
            CommitmentSetupPlaceholder()

        case .commitmentHistory:
            CommitmentHistoryView()

        case .goalManagement:
            GoalManagementPlaceholder()

        case .goalDetail(let goalId):
            GoalDetailPlaceholder(goalId: goalId)

        case .journalEntry(let activityId):
            JournalEntryView(activityId: activityId)

        case .journalList:
            JournalListView()

        case .stravaConnect:
            StravaConnectView()

        case .stravaSettings:
            StravaSettingsView()

        case .activityInsights(let activityId):
            ActivityInsightsPlaceholder(activityId: activityId)
        }
    }
}

// MARK: - Placeholder Views (for routes not yet implemented)

private struct ActivityDetailPlaceholder: View {
    let activityId: Int

    var body: some View {
        Text("Activity Detail #\(activityId)")
            .navigationTitle("Activity")
    }
}

private struct ActivityInsightsPlaceholder: View {
    let activityId: Int

    var body: some View {
        Text("Activity Insights #\(activityId)")
            .navigationTitle("Insights")
    }
}

private struct CommitmentHistoryView: View {
    var body: some View {
        Text("Commitment History")
            .navigationTitle("History")
    }
}

private struct CommitmentSetupPlaceholder: View {
    var body: some View {
        Text("Daily Commitment Setup")
            .navigationTitle("Daily Commitment")
    }
}

private struct GoalManagementPlaceholder: View {
    var body: some View {
        Text("Goals Management")
            .navigationTitle("Goals")
    }
}

private struct ProfilePlaceholder: View {
    let athleteId: Int

    var body: some View {
        Text("Profile #\(athleteId)")
            .navigationTitle("Profile")
    }
}

private struct GoalDetailPlaceholder: View {
    let goalId: Int

    var body: some View {
        Text("Goal Detail #\(goalId)")
            .navigationTitle("Goal")
    }
}

private struct JournalEntryView: View {
    let activityId: Int?

    var body: some View {
        Text("Journal Entry")
            .navigationTitle("New Entry")
    }
}

private struct JournalListView: View {
    var body: some View {
        Text("Journal List")
            .navigationTitle("Training Journal")
    }
}

private struct StravaConnectView: View {
    var body: some View {
        Text("Connect to Strava")
            .navigationTitle("Strava")
    }
}

private struct StravaSettingsView: View {
    var body: some View {
        Text("Strava Settings")
            .navigationTitle("Strava")
    }
}

private struct ActivityInsightsView: View {
    let activity: Activity

    var body: some View {
        Text("Activity Insights")
            .navigationTitle("Insights")
    }
}
