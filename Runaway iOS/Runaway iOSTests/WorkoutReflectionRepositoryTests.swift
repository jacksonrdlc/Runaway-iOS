import Foundation
import SwiftData
import Testing
@testable import Runaway_iOS

@MainActor
struct WorkoutReflectionRepositoryTests {
    @Test
    func upsertMaintainsOneReflectionPerUserAndActivity() throws {
        let store = try makeRepository()
        let repository = store.repository
        let context = store.context
        var reflection = try makeReflection()
        try repository.upsert(reflection)

        reflection.perceivedEffort = 8
        reflection.updatedAt = Date(timeIntervalSince1970: 1_787_601_700)
        try repository.upsert(reflection)

        let fetched = try repository.reflection(
            activityId: reflection.activityId,
            userId: reflection.userId
        )
        let stored = try #require(fetched)
        #expect(stored.id == reflection.id)
        #expect(stored.perceivedEffort == 8)
        #expect(try context.fetchCount(FetchDescriptor<SDWorkoutReflection>()) == 1)
    }

    @Test
    func editingSyncedReflectionMarksItPendingAndIncrementsVersion() throws {
        let store = try makeRepository()
        let repository = store.repository
        let original = try makeReflection()
        try repository.upsert(original)
        try repository.markSynced(
            localID: original.id,
            serverUpdatedAt: Date(timeIntervalSince1970: 1_787_601_650)
        )

        let fetchedEdit = try repository.reflection(localID: original.id)
        var edit = try #require(fetchedEdit)
        let syncedVersion = edit.syncMetadata.localVersion
        edit.perceivedEffort = 9
        edit.updatedAt = Date(timeIntervalSince1970: 1_787_601_700)
        try repository.upsert(edit)

        let fetchedStored = try repository.reflection(localID: original.id)
        let stored = try #require(fetchedStored)
        #expect(stored.perceivedEffort == 9)
        #expect(stored.syncMetadata.syncStatus == .pendingUpload)
        #expect(stored.syncMetadata.localVersion == syncedVersion + 1)
    }

    @Test
    func serverDebriefDoesNotReplaceUserEnteredFields() throws {
        let store = try makeRepository()
        let repository = store.repository
        let original = try makeReflection()
        try repository.upsert(original)

        try repository.applyServerDebrief(
            localID: original.id,
            content: "Your enriched debrief.",
            generatedAt: Date(timeIntervalSince1970: 1_787_601_800)
        )

        let fetched = try repository.reflection(localID: original.id)
        let stored = try #require(fetched)
        #expect(stored.perceivedEffort == original.perceivedEffort)
        #expect(stored.bodyState == original.bodyState)
        #expect(stored.note == original.note)
        #expect(stored.serverDebrief == "Your enriched debrief.")
    }

    @Test
    func deleteRemovesOnlyTheCurrentUsersActivityReflection() throws {
        let store = try makeRepository()
        let repository = store.repository
        let first = try makeReflection()
        let second = try makeReflection(
            id: UUID(uuidString: "C3D6F421-E050-44E4-8078-0429356AA09B")!,
            userId: UUID(uuidString: "C2745163-D097-4A55-B412-80FB531838F3")!
        )
        try repository.upsert(first)
        try repository.upsert(second)

        try repository.delete(activityId: first.activityId, userId: first.userId)

        #expect(try repository.reflection(activityId: first.activityId, userId: first.userId) == nil)
        #expect(try repository.reflection(activityId: second.activityId, userId: second.userId) != nil)
    }

    private func makeRepository() throws -> TestStore {
        try TestStore()
    }

    @MainActor
    private final class TestStore {
        let container: ModelContainer
        let context: ModelContext
        let repository: LocalWorkoutReflectionRepository

        init() throws {
            let schema = Schema([SDWorkoutReflection.self])
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                allowsSave: true
            )
            let container = try ModelContainer(for: schema, configurations: [configuration])
            self.container = container
            self.context = container.mainContext
            self.repository = LocalWorkoutReflectionRepository(context: container.mainContext)
        }
    }

    private func makeReflection(
        id: UUID = UUID(uuidString: "B1BB54CB-7A0A-4B48-BCB3-627BB23E53A1")!,
        userId: UUID = UUID(uuidString: "2769E3EF-B753-4EE6-8DA2-D370A57BF7B6")!
    ) throws -> WorkoutReflection {
        var reflection = try WorkoutReflection.validated(
            id: id,
            activityId: 42,
            userId: userId,
            athleteId: 7,
            perceivedEffort: 6,
            bodyState: .good,
            mood: .better,
            conditionTags: [.heat],
            note: "Warm evening run",
            now: Date(timeIntervalSince1970: 1_787_601_600)
        )
        reflection.localDebrief = "Local guidance."
        return reflection
    }
}
