//
//  Runaway_iOSTests.swift
//  Runaway iOSTests
//
//  Created by Jack Rudelic on 2/18/25.
//

import Foundation
import Testing
@testable import Runaway_iOS

struct Runaway_iOSTests {

    @Test func primaryTabsFollowTheRunnerJourney() {
        #expect(RunawayTab.allCases.map(\.title) == ["Today", "Activities", "Plan", "You"])
        #expect(RunawayTab.today.systemImage == "sun.max.fill")
        #expect(RunawayTab.plan.systemImage == "calendar.badge.clock")
    }

    @Test func athleteAccountRowsResolveToActions() {
        #expect(AthleteAccountItem.devicesAndSensors.action == .systemSettings)
        #expect(AthleteAccountItem.trainingPreferences.action == .trainingPreferences)
        #expect(AthleteAccountItem.notifications.action == .systemSettings)
    }

    @Test func manualRaceEditKeepsIdentityAndPrefillsDraft() throws {
        let race = AthleteRace(
            id: 42,
            athleteId: 7,
            runsignupRaceId: nil,
            eventId: 0,
            raceName: "Skippo",
            raceDate: "2026-11-02",
            city: nil,
            state: nil,
            countryCode: nil,
            logoUrl: nil,
            externalUrl: nil,
            distanceMiles: 19,
            source: "manual",
            syncedAt: nil
        )

        let edit = try #require(ManualRaceEdit(race: race))

        #expect(edit.raceID == 42)
        #expect(edit.draft.name == "Skippo")
        #expect(edit.draft.distanceMiles == 19)
        #expect(edit.draft.date == race.parsedDate)
    }

    @Test func importedRaceCannotBeEditedAsManualRace() {
        let race = AthleteRace(
            id: 42,
            athleteId: 7,
            runsignupRaceId: 99,
            eventId: 12,
            raceName: "Imported Race",
            raceDate: "2026-11-02",
            city: nil,
            state: nil,
            countryCode: nil,
            logoUrl: nil,
            externalUrl: nil,
            distanceMiles: 13.1,
            source: "runsignup",
            syncedAt: nil
        )

        #expect(ManualRaceEdit(race: race) == nil)
    }

    @Test func supportedDeepLinksResolveToConcreteRoutes() throws {
        let activityURL = try #require(URL(string: "runaway://open/activity?id=42"))
        let commitmentURL = try #require(URL(string: "runaway://open/commitment"))
        let goalsURL = try #require(URL(string: "runaway://open/goals"))

        #expect(AppRouter.deepLinkRoute(for: activityURL) == .activityDetail(42))
        #expect(AppRouter.deepLinkRoute(for: commitmentURL) == .commitmentSetup)
        #expect(AppRouter.deepLinkRoute(for: goalsURL) == .goalManagement)
    }

    @Test func runningClassifierRecognizesRunVariantsWithoutCountingOtherSports() {
        #expect(AppConstants.ActivityTypes.isRunning("Run"))
        #expect(AppConstants.ActivityTypes.isRunning("Trail Run"))
        #expect(AppConstants.ActivityTypes.isRunning("VirtualRun"))
        #expect(!AppConstants.ActivityTypes.isRunning("Walk"))
        #expect(!AppConstants.ActivityTypes.isRunning("Bike Ride"))
        #expect(!AppConstants.ActivityTypes.isRunning(nil))
    }

    @Test func weeklyStatsExcludeNonRunningActivities() {
        let now = Date().timeIntervalSince1970
        let activities = [
            Activity(
                id: 1,
                name: "Morning Run",
                type: "Run",
                distance: 1_609.34,
                start_date: now,
                elapsed_time: 600,
                activity_date: now
            ),
            Activity(
                id: 2,
                name: "Bike Ride",
                type: "Bike Ride",
                distance: 16_093.4,
                start_date: now,
                elapsed_time: 1_800,
                activity_date: now
            )
        ]

        let stats = WeeklyActivityStats(activities: activities)

        #expect(stats.activityCount == 1)
        #expect(abs(stats.totalMiles - 1) < 0.001)
        #expect(stats.totalSeconds == 600)
    }

    @Test func manualRaceDraftRequiresANameFutureDateAndDistance() {
        let futureDate = Date().addingTimeInterval(86_400)

        #expect(ManualRaceDraft(name: "City Half", distanceMiles: 13.1, date: futureDate).isValid)
        #expect(!ManualRaceDraft(name: "", distanceMiles: 13.1, date: futureDate).isValid)
        #expect(!ManualRaceDraft(name: "City Half", distanceMiles: 0, date: futureDate).isValid)
        #expect(!ManualRaceDraft(name: "City Half", distanceMiles: 13.1, date: Date.distantPast).isValid)
    }

    @Test func manualAthleteRaceDecodesWithoutRunSignupIdentifier() throws {
        let data = try #require(
            """
            {
              "id": 12,
              "athlete_id": 7,
              "runsignup_race_id": null,
              "event_id": 0,
              "race_name": "City Half",
              "race_date": "2026-10-18",
              "distance_miles": 13.1,
              "source": "manual"
            }
            """.data(using: .utf8)
        )

        let race = try JSONDecoder().decode(AthleteRace.self, from: data)

        #expect(race.runsignupRaceId == nil)
        #expect(race.distanceMiles == 13.1)
        #expect(race.source == "manual")
    }

    @Test func readinessNormalizesOnlyAvailableFactors() {
        let weightedScore = (70.0 * 0.20) + (75.0 * 0.20)
        #expect(
            ReadinessService.normalizedScore(weightedScore: weightedScore, availableWeight: 0.40) == 73
        )
    }

    @Test func readinessScoreIsClamped() {
        #expect(ReadinessService.normalizedScore(weightedScore: 120, availableWeight: 1) == 100)
        #expect(ReadinessService.normalizedScore(weightedScore: -10, availableWeight: 1) == 0)
    }

    @Test func readinessIncludesRunsAndExcludesOtherActivities() {
        #expect(ReadinessService.isReadinessActivity(activityType: "Run"))
        #expect(!ReadinessService.isReadinessActivity(activityType: "Ride"))
    }

    @Test func raceDateRoundTripsWithoutChangingCalendarDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Chicago"))
        let date = try #require(RaceDateCodec.date(from: "2026-11-02", calendar: calendar))
        #expect(RaceDateCodec.string(from: date, calendar: calendar) == "2026-11-02")
    }

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

}
