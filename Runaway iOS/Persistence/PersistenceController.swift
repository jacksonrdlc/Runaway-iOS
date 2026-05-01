//
//  PersistenceController.swift
//  Runaway iOS
//
//  Manages SwiftData ModelContainer with App Group support for widget sharing
//

import Foundation
import SwiftData

/// Manages SwiftData persistence with App Group support for widget data sharing
@MainActor
final class PersistenceController {
    // MARK: - Singleton

    static let shared = PersistenceController()

    // MARK: - Properties

    /// App Group identifier for data sharing with widget
    static let appGroupIdentifier = "group.com.jackrudelic.runawayios"

    /// The SwiftData model container
    let container: ModelContainer

    /// Convenience accessor for the main context
    var mainContext: ModelContext {
        container.mainContext
    }

    // MARK: - Schema

    /// All SwiftData models in the schema
    static let schema: [any PersistentModel.Type] = [
        SDActivity.self,
        SDAthlete.self,
        SDDailyCommitment.self
    ]

    // MARK: - Initialization

    private init() {
        do {
            let schema = Schema(Self.schema)
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                groupContainer: .identifier(Self.appGroupIdentifier)
            )

            container = try ModelContainer(for: schema, configurations: [modelConfiguration])

            // Configure main context
            container.mainContext.autosaveEnabled = true

            #if DEBUG
            print("[PersistenceController] Initialized with App Group: \(Self.appGroupIdentifier)")
            #endif
        } catch {
            fatalError("[PersistenceController] Failed to create ModelContainer: \(error)")
        }
    }

    // MARK: - Preview/Testing Support

    /// Creates an in-memory container for previews and testing
    static func preview() -> PersistenceController {
        let controller = PersistenceController(inMemory: true)
        return controller
    }

    /// Private initializer for in-memory testing
    private init(inMemory: Bool) {
        do {
            let schema = Schema(Self.schema)
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: inMemory,
                allowsSave: true
            )

            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            container.mainContext.autosaveEnabled = true
        } catch {
            fatalError("[PersistenceController] Failed to create in-memory ModelContainer: \(error)")
        }
    }

    // MARK: - Context Operations

    /// Creates a new background context for async operations
    func newBackgroundContext() -> ModelContext {
        ModelContext(container)
    }

    /// Save the main context
    func save() throws {
        if mainContext.hasChanges {
            try mainContext.save()
        }
    }

    /// Save a specific context
    func save(context: ModelContext) throws {
        if context.hasChanges {
            try context.save()
        }
    }

    // MARK: - Utility Methods

    /// Delete all data (for testing or reset)
    func deleteAllData() throws {
        for modelType in Self.schema {
            try mainContext.delete(model: modelType)
        }
        try save()
        #if DEBUG
        print("[PersistenceController] All data deleted")
        #endif
    }

    /// Get counts for debugging
    func debugPrintCounts() {
        do {
            let activityCount = try mainContext.fetchCount(FetchDescriptor<SDActivity>())
            let athleteCount = try mainContext.fetchCount(FetchDescriptor<SDAthlete>())
            let commitmentCount = try mainContext.fetchCount(FetchDescriptor<SDDailyCommitment>())

            #if DEBUG
            print("[PersistenceController] Data counts:")
            print("  Activities: \(activityCount)")
            print("  Athletes: \(athleteCount)")
            print("  Commitments: \(commitmentCount)")
            #endif
        } catch {
            #if DEBUG
            print("[PersistenceController] Error getting counts: \(error)")
            #endif
        }
    }

    /// Get pending sync count
    func pendingSyncCount() -> Int {
        do {
            let activityCount = try mainContext.fetchCount(
                FetchDescriptor<SDActivity>(predicate: SDActivity.pendingSyncPredicate)
            )
            let commitmentCount = try mainContext.fetchCount(
                FetchDescriptor<SDDailyCommitment>(predicate: SDDailyCommitment.pendingSyncPredicate)
            )
            return activityCount + commitmentCount
        } catch {
            #if DEBUG
            print("[PersistenceController] Error getting pending sync count: \(error)")
            #endif
            return 0
        }
    }
}

// MARK: - ModelContext Extensions

extension ModelContext {
    /// Fetch or create pattern for upsert operations
    func fetchOrCreate<T: PersistentModel>(
        _ type: T.Type,
        predicate: Predicate<T>,
        create: () -> T
    ) throws -> T {
        var descriptor = FetchDescriptor<T>(predicate: predicate)
        descriptor.fetchLimit = 1

        if let existing = try fetch(descriptor).first {
            return existing
        }

        let new = create()
        insert(new)
        return new
    }
}
