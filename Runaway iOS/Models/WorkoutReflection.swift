import Foundation

enum ReflectionBodyState: String, Codable, CaseIterable, Sendable {
    case good
    case tight
    case sore
    case pain
}

enum ReflectionMood: String, Codable, CaseIterable, Sendable {
    case better
    case same
    case lower
}

enum ReflectionCondition: String, Codable, CaseIterable, Sendable {
    case heat
    case hills
    case wind
    case poorSleep = "poor_sleep"
    case stress
}

struct WorkoutActivitySummary: Equatable, Sendable {
    let distanceMeters: Double?
    let elapsedSeconds: TimeInterval?
    let sportType: String
}

struct WorkoutReflection: Codable, Identifiable, Equatable {
    enum ValidationError: Error, Equatable {
        case invalidEffort
        case noteTooLong
    }

    let id: UUID
    let activityId: Int
    let userId: UUID
    let athleteId: Int
    var perceivedEffort: Int
    var bodyState: ReflectionBodyState
    var mood: ReflectionMood
    var conditionTags: [ReflectionCondition]
    var note: String?
    var localDebrief: String
    var serverDebrief: String?
    let createdAt: Date
    var updatedAt: Date
    var syncMetadata: SyncMetadata

    static func validated(
        id: UUID,
        activityId: Int,
        userId: UUID,
        athleteId: Int,
        perceivedEffort: Int,
        bodyState: ReflectionBodyState,
        mood: ReflectionMood,
        conditionTags: [ReflectionCondition],
        note: String?,
        now: Date
    ) throws -> WorkoutReflection {
        guard (1...10).contains(perceivedEffort) else {
            throw ValidationError.invalidEffort
        }

        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (trimmedNote?.count ?? 0) <= 1_000 else {
            throw ValidationError.noteTooLong
        }

        var seenConditions = Set<ReflectionCondition>()
        let uniqueConditions = conditionTags.filter { seenConditions.insert($0).inserted }

        return WorkoutReflection(
            id: id,
            activityId: activityId,
            userId: userId,
            athleteId: athleteId,
            perceivedEffort: perceivedEffort,
            bodyState: bodyState,
            mood: mood,
            conditionTags: uniqueConditions,
            note: trimmedNote?.isEmpty == false ? trimmedNote : nil,
            localDebrief: "",
            serverDebrief: nil,
            createdAt: now,
            updatedAt: now,
            syncMetadata: SyncMetadata(lastModifiedLocally: now)
        )
    }
}
