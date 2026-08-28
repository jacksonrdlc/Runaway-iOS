//
//  TrainingProfile.swift
//  Runaway iOS
//

import Foundation

enum TrainingActivity: String, Codable, CaseIterable, Identifiable, Sendable {
    case running, strength, cycling, swimming, walking, hiking, mobility

    var id: String { rawValue }
}

enum TrainingActivityRole: String, Codable, CaseIterable, Sendable {
    case primary, supporting, optional
}

struct TrainingActivityPreference: Codable, Equatable, Sendable, Identifiable {
    var activity: TrainingActivity
    var role: TrainingActivityRole
    var sessionsPerWeek: Int

    var id: TrainingActivity { activity }
}

enum StrengthEquipment: String, Codable, CaseIterable, Sendable {
    case bodyweight, dumbbells, fullGym, unspecified
}

enum TrainingExperience: String, Codable, CaseIterable, Sendable {
    case beginner, intermediate, advanced
}

struct TrainingProfile: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var activities: [TrainingActivityPreference]
    var trainingDaysPerWeek: Int
    var preferredLongRunWeekday: Int
    var unavailableWeekdays: Set<Int>
    var strengthEquipment: StrengthEquipment
    var strengthExperience: TrainingExperience

    static let runningFirstDefault = TrainingProfile(
        schemaVersion: currentSchemaVersion,
        activities: [
            TrainingActivityPreference(activity: .running, role: .primary, sessionsPerWeek: 3),
        ],
        trainingDaysPerWeek: 3,
        preferredLongRunWeekday: 7,
        unavailableWeekdays: [],
        strengthEquipment: .bodyweight,
        strengthExperience: .beginner
    )

    static var migrationSeed: TrainingProfile {
        var profile = runningFirstDefault
        profile.schemaVersion = 0
        return profile
    }

    var primaryActivity: TrainingActivity? {
        activities.first(where: { $0.role == .primary })?.activity
    }

    func preference(for activity: TrainingActivity) -> TrainingActivityPreference? {
        activities.first(where: { $0.activity == activity })
    }

    var fingerprint: String {
        let activityPart = activities.sorted { $0.activity.rawValue < $1.activity.rawValue }.map {
            "\($0.activity.rawValue):\($0.role.rawValue):\($0.sessionsPerWeek)"
        }.joined(separator: "|")
        let unavailablePart = unavailableWeekdays.sorted().map(String.init).joined(separator: ",")

        return [
            "activities=\(activityPart)",
            "trainingDays=\(trainingDaysPerWeek)",
            "longRunWeekday=\(preferredLongRunWeekday)",
            "unavailable=\(unavailablePart)",
            "strengthEquipment=\(strengthEquipment.rawValue)",
            "strengthExperience=\(strengthExperience.rawValue)",
        ].joined(separator: ";")
    }

    struct ValidationResult: Sendable {
        let profile: TrainingProfile
        let wasRepaired: Bool
        let repairReasons: [String]
    }

    func validated(existingPlan: WeeklyTrainingPlan? = nil) -> ValidationResult {
        var profile = self
        var repairReasons: [String] = []

        func recordRepair(_ reason: String) {
            repairReasons.append(reason)
        }

        if profile.schemaVersion < Self.currentSchemaVersion,
           let existingPlan,
           profile.activities == Self.runningFirstDefault.activities,
           profile.trainingDaysPerWeek == Self.runningFirstDefault.trainingDaysPerWeek,
           profile.preferredLongRunWeekday == Self.runningFirstDefault.preferredLongRunWeekday {
            let runs = existingPlan.workouts.filter { $0.workoutType.isRunning }
            let strength = existingPlan.workouts.filter { $0.workoutType.isStrength }
            if !runs.isEmpty {
                profile.activities = [
                    TrainingActivityPreference(
                        activity: .running,
                        role: .primary,
                        sessionsPerWeek: runs.count
                    )
                ]
                if !strength.isEmpty {
                    profile.activities.append(
                        TrainingActivityPreference(
                            activity: .strength,
                            role: .supporting,
                            sessionsPerWeek: strength.count
                        )
                    )
                }
                profile.trainingDaysPerWeek = min(7, runs.count + strength.count)
                if let longRun = runs.first(where: { $0.workoutType == .longRun }) {
                    profile.preferredLongRunWeekday = longRun.dayOfWeek.calendarWeekday
                }
                recordRepair("Training preferences were migrated from the existing plan.")
            }
        }

        if profile.schemaVersion != Self.currentSchemaVersion {
            profile.schemaVersion = Self.currentSchemaVersion
            recordRepair("Updated the training profile to the current version.")
        }

        let clampedTrainingDays = profile.trainingDaysPerWeek.clamped(to: 1...7)
        if clampedTrainingDays != profile.trainingDaysPerWeek {
            profile.trainingDaysPerWeek = clampedTrainingDays
            recordRepair("Training days per week were limited to 1 through 7.")
        }

        var seenActivities = Set<TrainingActivity>()
        let uniqueActivities = profile.activities.filter { preference in
            seenActivities.insert(preference.activity).inserted
        }
        if uniqueActivities.count != profile.activities.count {
            profile.activities = uniqueActivities
            recordRepair("Duplicate activities were removed.")
        }

        guard !profile.activities.isEmpty else {
            recordRepair("No activities were selected, so the running-first default was restored.")
            return ValidationResult(
                profile: .runningFirstDefault,
                wasRepaired: true,
                repairReasons: repairReasons
            )
        }

        let primaryIndexes = profile.activities.indices.filter { profile.activities[$0].role == .primary }
        if primaryIndexes.count != 1 {
            let primaryIndex: Int
            if let runningPrimaryIndex = primaryIndexes.first(where: {
                profile.activities[$0].activity == .running
            }) {
                primaryIndex = runningPrimaryIndex
            } else if let firstPrimaryIndex = primaryIndexes.first {
                primaryIndex = firstPrimaryIndex
            } else if let runningIndex = profile.activities.firstIndex(where: { $0.activity == .running }) {
                primaryIndex = runningIndex
            } else {
                primaryIndex = profile.activities.startIndex
            }

            for index in profile.activities.indices {
                if index == primaryIndex {
                    profile.activities[index].role = .primary
                } else if profile.activities[index].role == .primary {
                    profile.activities[index].role = .supporting
                }
            }
            recordRepair("Exactly one primary activity was selected.")
        }

        for index in profile.activities.indices {
            let clampedSessions = profile.activities[index].sessionsPerWeek.clamped(to: 0...7)
            if clampedSessions != profile.activities[index].sessionsPerWeek {
                profile.activities[index].sessionsPerWeek = clampedSessions
                recordRepair("Activity sessions were limited to 0 through 7 per week.")
            }
        }

        var excessSessions = profile.activities.reduce(0) { $0 + $1.sessionsPerWeek } - profile.trainingDaysPerWeek
        if excessSessions > 0 {
            for role in [TrainingActivityRole.optional, .supporting, .primary] where excessSessions > 0 {
                for index in profile.activities.indices where profile.activities[index].role == role && excessSessions > 0 {
                    let reduction = min(profile.activities[index].sessionsPerWeek, excessSessions)
                    profile.activities[index].sessionsPerWeek -= reduction
                    excessSessions -= reduction
                }
            }
            recordRepair("Activity sessions were reduced to fit the selected training days.")
        }

        let normalizedLongRunWeekday = profile.preferredLongRunWeekday.clamped(to: 1...7)
        if normalizedLongRunWeekday != profile.preferredLongRunWeekday {
            profile.preferredLongRunWeekday = normalizedLongRunWeekday
            recordRepair("The preferred long-run weekday was limited to Sunday through Saturday.")
        }

        let validUnavailableWeekdays = profile.unavailableWeekdays.filter { (1...7).contains($0) }
        if validUnavailableWeekdays != profile.unavailableWeekdays {
            profile.unavailableWeekdays = validUnavailableWeekdays
            recordRepair("Invalid unavailable weekdays were removed.")
        }

        return ValidationResult(
            profile: profile,
            wasRepaired: !repairReasons.isEmpty,
            repairReasons: repairReasons
        )
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
