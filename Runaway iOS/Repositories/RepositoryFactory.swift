//
//  RepositoryFactory.swift
//  Runaway iOS
//
//  Factory for creating repositories based on feature flags
//

import Foundation

/// Factory for creating the appropriate repository implementation
/// based on feature flags and configuration
@MainActor
enum RepositoryFactory {

    // MARK: - Shared Instances

    private static var _hybridActivityRepository: HybridActivityRepository?
    private static var _localActivityRepository: LocalActivityRepository?

    // MARK: - Activity Repository

    /// Get the activity repository (hybrid local + remote)
    static func activityRepository(syncEngine: SyncEngine? = nil) -> any ActivityRepositoryProtocol {
        return hybridActivityRepository(syncEngine: syncEngine)
    }

    /// Get hybrid activity repository (local + remote)
    static func hybridActivityRepository(syncEngine: SyncEngine? = nil) -> HybridActivityRepository {
        if let existing = _hybridActivityRepository {
            return existing
        }

        let syncEngine = syncEngine ?? .shared

        let repository = HybridActivityRepository(
            localRepository: localActivityRepository(),
            remoteRepository: SupabaseActivityRepository.shared,
            syncEngine: syncEngine
        )
        _hybridActivityRepository = repository
        return repository
    }

    /// Get local-only activity repository
    static func localActivityRepository() -> LocalActivityRepository {
        if let existing = _localActivityRepository {
            return existing
        }

        let repository = LocalActivityRepository()
        _localActivityRepository = repository
        return repository
    }

    /// Get remote-only activity repository
    static func remoteActivityRepository() -> SupabaseActivityRepository {
        return SupabaseActivityRepository.shared
    }

    // MARK: - Reset (for testing)

    /// Reset all cached repositories
    static func reset() {
        _hybridActivityRepository = nil
        _localActivityRepository = nil
    }

    // MARK: - Debug

    static func printConfiguration() {
        #if DEBUG
        print("[RepositoryFactory] Using HybridActivityRepository (SwiftData + Supabase)")
        #endif
    }
}

// MARK: - Repository Provider Protocol

/// Protocol for objects that can provide repositories
@MainActor protocol RepositoryProvider {
    var activityRepository: any ActivityRepositoryProtocol { get }
}

/// Default implementation using RepositoryFactory
@MainActor
final class DefaultRepositoryProvider: RepositoryProvider {
    static let shared = DefaultRepositoryProvider()

    private let syncEngine: SyncEngine

    init(syncEngine: SyncEngine? = nil) {
        self.syncEngine = syncEngine ?? .shared
    }

    var activityRepository: any ActivityRepositoryProtocol {
        RepositoryFactory.activityRepository(syncEngine: syncEngine)
    }
}
