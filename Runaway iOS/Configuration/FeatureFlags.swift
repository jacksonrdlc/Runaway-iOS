//
//  FeatureFlags.swift
//  Runaway iOS
//
//  Debug and development feature flags
//

import Foundation

/// Feature flags for debugging and development
enum FeatureFlags {
    private static let userDefaults = UserDefaults.standard

    private enum Keys {
        static let debugSyncLogging = "feature.debug.syncLogging"
    }

    // MARK: - Debug Flags

    /// Enable verbose sync logging for debugging
    static var debugSyncLogging: Bool {
        get { userDefaults.bool(forKey: Keys.debugSyncLogging) }
        set { userDefaults.set(newValue, forKey: Keys.debugSyncLogging) }
    }
}
