//
//  Router.swift
//  Runaway iOS
//
//  Centralized navigation router for app-wide navigation management
//

import SwiftUI

@Observable
class AppRouter {
    var path = NavigationPath()

    // MARK: - Route Definitions

    enum Route: Hashable {
        // Activity Routes
        case activityDetail(Int)
        case activityList

        // Profile & Settings Routes
        case settings
        case accountInfo
        case profile(Int)

        // Commitment & Goals Routes
        case commitmentSetup
        case commitmentHistory
        case goalManagement
        case goalDetail(Int)

        // Journal Routes
        case journalEntry(Int?)
        case journalList

        // Strava Routes
        case stravaConnect
        case stravaSettings

        // Analysis Routes
        case activityInsights(Int)

        // Awards Routes
        case awards
    }

    // MARK: - Navigation Methods

    func navigate(to route: Route) { path.append(route) }
    func pop() { guard !path.isEmpty else { return }; path.removeLast() }
    func popToRoot() { path.removeLast(path.count) }
    func pop(count: Int) { guard count > 0, count <= path.count else { return }; path.removeLast(count) }
    func replace(with route: Route) { if !path.isEmpty { path.removeLast() }; path.append(route) }

    var isAtRoot: Bool { path.isEmpty }
    var depth: Int { path.count }

    // MARK: - Deep Linking

    func handleDeepLink(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return }

        switch components.path {
        case "/activity":
            if let id = components.queryItems?.first(where: { $0.name == "id" })?.value,
               let activityId = Int(id) {
                navigate(to: .activityDetail(activityId))
            }
        case "/settings":
            navigate(to: .settings)
        case "/commitment":
            navigate(to: .commitmentSetup)
        case "/goals":
            navigate(to: .goalManagement)
        case "/awards", "/achievements":
            navigate(to: .awards)
        default:
            break
        }
    }
}

// MARK: - Destination Builder

extension AppRouter {
    @ViewBuilder
    func destination(for route: Route) -> some View {
        switch route {
        case .activityDetail(let activityId):
            ActivityDetailView(activityId: activityId)

        case .activityList:
            ActivitiesView()

        case .settings:
            SettingsView()

        case .accountInfo:
            AccountInformationView()

        case .profile(let athleteId):
            Text("Profile #\(athleteId)").navigationTitle("Profile")

        case .commitmentSetup:
            Text("Daily Commitment Setup").navigationTitle("Daily Commitment")

        case .commitmentHistory:
            Text("Commitment History").navigationTitle("History")

        case .goalManagement:
            Text("Goals Management").navigationTitle("Goals")

        case .goalDetail(let goalId):
            Text("Goal Detail #\(goalId)").navigationTitle("Goal")

        case .journalEntry(let activityId):
            Text("Journal Entry").navigationTitle("New Entry")

        case .journalList:
            Text("Journal List").navigationTitle("Training Journal")

        case .stravaConnect:
            Text("Connect to Strava").navigationTitle("Strava")

        case .stravaSettings:
            Text("Strava Settings").navigationTitle("Strava")

        case .activityInsights(let activityId):
            Text("Activity Insights #\(activityId)").navigationTitle("Insights")

        case .awards:
            AwardsView()
        }
    }
}

// MARK: - View Extension

extension View {
    func withAppRouter(_ router: AppRouter) -> some View {
        self
            .navigationDestination(for: AppRouter.Route.self) { route in
                router.destination(for: route)
            }
            .environment(router)
    }
}
