//
//  UnitPreferences.swift
//  Runaway iOS
//
//  Centralized unit preferences for metric/imperial display
//

import Foundation
import Combine

/// Manages user's preferred unit system (metric/imperial)
final class UnitPreferences: ObservableObject {

    static let shared = UnitPreferences()

    private let userDefaults: UserDefaults
    private let unitKey = "preferred_distance_unit"

    @Published var distanceUnit: DistanceUnit {
        didSet {
            save()
        }
    }

    private init() {
        // Use app group for widget access
        self.userDefaults = UserDefaults(suiteName: "group.com.jackrudelic.runawayios") ?? .standard

        // Load saved preference, default to miles (imperial)
        if let savedValue = userDefaults.string(forKey: unitKey),
           let unit = DistanceUnit(rawValue: savedValue) {
            self.distanceUnit = unit
        } else {
            self.distanceUnit = .miles
        }
    }

    private func save() {
        userDefaults.set(distanceUnit.rawValue, forKey: unitKey)
    }

    // MARK: - Convenience Properties

    var isMetric: Bool {
        distanceUnit == .kilometers
    }

    var isImperial: Bool {
        distanceUnit == .miles
    }
}

// MARK: - Unit Formatter

/// Centralized formatting for distances, paces, and speeds
struct UnitFormatter {

    /// Format distance from meters to user's preferred unit
    /// - Parameters:
    ///   - meters: Distance in meters
    ///   - decimals: Number of decimal places (default 2)
    ///   - includeUnit: Whether to append unit abbreviation (default true)
    /// - Returns: Formatted distance string
    static func formatDistance(_ meters: Double, decimals: Int = 2, includeUnit: Bool = true) -> String {
        let unit = UnitPreferences.shared.distanceUnit
        let value = meters / unit.metersPerUnit
        let formatted = String(format: "%.\(decimals)f", value)
        return includeUnit ? "\(formatted)\(unit.abbreviation)" : formatted
    }

    /// Format distance value (already in user units) with unit label
    static func formatDistanceValue(_ value: Double, decimals: Int = 2, includeUnit: Bool = true) -> String {
        let unit = UnitPreferences.shared.distanceUnit
        let formatted = String(format: "%.\(decimals)f", value)
        return includeUnit ? "\(formatted)\(unit.abbreviation)" : formatted
    }

    /// Format pace from seconds per meter to MM:SS per unit
    /// - Parameter secondsPerMeter: Pace in seconds per meter
    /// - Returns: Formatted pace string (e.g., "8:30/mi" or "5:17/km")
    static func formatPace(secondsPerMeter: Double) -> String {
        let unit = UnitPreferences.shared.distanceUnit
        let secondsPerUnit = secondsPerMeter * unit.metersPerUnit

        guard secondsPerUnit > 0 && secondsPerUnit < 60 * 60 else { return "--:--" }

        let minutes = Int(secondsPerUnit) / 60
        let seconds = Int(secondsPerUnit) % 60
        return String(format: "%d:%02d/\(unit.abbreviation)", minutes, seconds)
    }

    /// Format pace from minutes per mile to MM:SS per user's unit
    /// - Parameter minutesPerMile: Pace in minutes per mile (as Double, e.g., 8.5 = 8:30/mi)
    /// - Returns: Formatted pace string
    static func formatPace(minutesPerMile: Double) -> String {
        guard minutesPerMile > 0 && minutesPerMile < 999 else { return "--:--" }

        let unit = UnitPreferences.shared.distanceUnit

        // Convert to user's preferred unit if needed
        let minutesPerUnit: Double
        if unit == .kilometers {
            // Convert min/mile to min/km (divide by 1.60934)
            minutesPerUnit = minutesPerMile / 1.60934
        } else {
            minutesPerUnit = minutesPerMile
        }

        let minutes = Int(minutesPerUnit)
        let seconds = Int((minutesPerUnit - Double(minutes)) * 60)
        return String(format: "%d:%02d/\(unit.abbreviation)", minutes, seconds)
    }

    /// Format pace with just the time portion (no unit suffix)
    static func formatPaceTime(minutesPerMile: Double) -> String {
        guard minutesPerMile > 0 && minutesPerMile < 999 else { return "--:--" }

        let unit = UnitPreferences.shared.distanceUnit

        let minutesPerUnit: Double
        if unit == .kilometers {
            minutesPerUnit = minutesPerMile / 1.60934
        } else {
            minutesPerUnit = minutesPerMile
        }

        let minutes = Int(minutesPerUnit)
        let seconds = Int((minutesPerUnit - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Format speed from meters per second
    /// - Parameter metersPerSecond: Speed in m/s
    /// - Returns: Formatted speed string (e.g., "7.5mph" or "12.1km/h")
    static func formatSpeed(_ metersPerSecond: Double) -> String {
        let unit = UnitPreferences.shared.distanceUnit

        let speed: Double
        let suffix: String

        if unit == .miles {
            speed = metersPerSecond * 2.23694 // m/s to mph
            suffix = "mph"
        } else {
            speed = metersPerSecond * 3.6 // m/s to km/h
            suffix = "km/h"
        }

        return String(format: "%.1f%@", speed, suffix)
    }

    /// Format speed value only (no unit suffix)
    static func formatSpeedValue(_ metersPerSecond: Double) -> String {
        let unit = UnitPreferences.shared.distanceUnit

        let speed: Double
        if unit == .miles {
            speed = metersPerSecond * 2.23694
        } else {
            speed = metersPerSecond * 3.6
        }

        return String(format: "%.1f", speed)
    }

    /// Get the speed unit label
    static var speedUnitLabel: String {
        UnitPreferences.shared.distanceUnit == .miles ? "mph" : "km/h"
    }

    /// Get the pace unit label (e.g., "/mi" or "/km")
    static var paceUnitLabel: String {
        "/\(UnitPreferences.shared.distanceUnit.abbreviation)"
    }

    /// Get the distance unit abbreviation
    static var distanceUnitAbbreviation: String {
        UnitPreferences.shared.distanceUnit.abbreviation
    }

    /// Get the full distance unit name
    static var distanceUnitName: String {
        UnitPreferences.shared.distanceUnit.displayName.lowercased()
    }

    /// Convert meters to user's preferred unit (value only)
    static func metersToPreferredUnit(_ meters: Double) -> Double {
        meters / UnitPreferences.shared.distanceUnit.metersPerUnit
    }
}
