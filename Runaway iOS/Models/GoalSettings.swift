//
//  GoalSettings.swift
//  Runaway iOS
//
//  User-configurable weekly and monthly running goals
//

import Foundation
import SwiftUI

// MARK: - Goal Settings Model

struct GoalSettings: Codable, Equatable {
    /// Weekly distance goal in miles
    var weeklyGoalMiles: Double

    /// Monthly distance goal in miles
    var monthlyGoalMiles: Double

    /// Whether to show goals in the widget
    var showInWidget: Bool

    init(
        weeklyGoalMiles: Double = 20.0,
        monthlyGoalMiles: Double = 80.0,
        showInWidget: Bool = true
    ) {
        self.weeklyGoalMiles = weeklyGoalMiles
        self.monthlyGoalMiles = monthlyGoalMiles
        self.showInWidget = showInWidget
    }

    // MARK: - Computed Properties

    /// Weekly goal in kilometers
    var weeklyGoalKilometers: Double {
        weeklyGoalMiles * 1.60934
    }

    /// Monthly goal in kilometers
    var monthlyGoalKilometers: Double {
        monthlyGoalMiles * 1.60934
    }
}

// MARK: - Goal Settings Store

final class GoalSettingsStore: ObservableObject {

    static let shared = GoalSettingsStore()

    private let userDefaults: UserDefaults
    private let settingsKey = "goal_settings"

    // Keys for direct widget access (simpler than decoding full object)
    static let weeklyGoalKey = "weekly_goal_miles"
    static let monthlyGoalKey = "monthly_goal_miles"

    private init() {
        // Use app group for widget access
        self.userDefaults = UserDefaults(suiteName: "group.com.jackrudelic.runawayios") ?? .standard

        // Load initial settings
        if let data = userDefaults.data(forKey: settingsKey),
           let loaded = try? JSONDecoder().decode(GoalSettings.self, from: data) {
            self._settings = Published(initialValue: loaded)
        } else {
            self._settings = Published(initialValue: GoalSettings())
        }

        // Ensure widget keys are synced on init
        syncWidgetKeys()
    }

    /// Current settings (published for SwiftUI observation)
    @Published var settings: GoalSettings {
        didSet {
            saveSettings()
            syncWidgetKeys()
        }
    }

    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            userDefaults.set(data, forKey: settingsKey)
        }
    }

    /// Sync individual keys for easy widget access
    private func syncWidgetKeys() {
        userDefaults.set(settings.weeklyGoalMiles, forKey: GoalSettingsStore.weeklyGoalKey)
        userDefaults.set(settings.monthlyGoalMiles, forKey: GoalSettingsStore.monthlyGoalKey)
    }

    /// Reset to defaults
    func resetToDefaults() {
        settings = GoalSettings()
    }

    // MARK: - Convenience Accessors

    var weeklyGoal: Double {
        get { settings.weeklyGoalMiles }
        set { settings.weeklyGoalMiles = newValue }
    }

    var monthlyGoal: Double {
        get { settings.monthlyGoalMiles }
        set { settings.monthlyGoalMiles = newValue }
    }
}

// MARK: - Goal Settings View

struct GoalSettingsView: View {
    @ObservedObject var store = GoalSettingsStore.shared
    @ObservedObject var unitPreferences = UnitPreferences.shared
    @Environment(\.dismiss) var dismiss

    @State private var weeklyGoalText: String = ""
    @State private var monthlyGoalText: String = ""

    /// Convert miles to display unit (km if metric)
    private func toDisplayUnit(_ miles: Double) -> Double {
        unitPreferences.isMetric ? miles * 1.60934 : miles
    }

    /// Convert from display unit back to miles
    private func fromDisplayUnit(_ value: Double) -> Double {
        unitPreferences.isMetric ? value / 1.60934 : value
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Text("Weekly Goal")
                        Spacer()
                        TextField(UnitFormatter.distanceUnitName.capitalized, text: $weeklyGoalText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text(UnitFormatter.distanceUnitAbbreviation)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Monthly Goal")
                        Spacer()
                        TextField(UnitFormatter.distanceUnitName.capitalized, text: $monthlyGoalText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text(UnitFormatter.distanceUnitAbbreviation)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Distance Goals")
                } footer: {
                    Text("Set your weekly and monthly running distance targets. These will be displayed in the app and widget.")
                }

                Section {
                    Toggle("Show in Widget", isOn: $store.settings.showInWidget)
                } header: {
                    Text("Widget")
                } footer: {
                    Text("Display your goal progress in the home screen widget.")
                }

                Section {
                    Button("Reset to Defaults") {
                        store.resetToDefaults()
                        loadDisplayValues()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Running Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        saveAndDismiss()
                    }
                }
            }
            .onAppear {
                loadDisplayValues()
            }
        }
    }

    /// Load values from store and convert to display units
    private func loadDisplayValues() {
        let weeklyDisplay = toDisplayUnit(store.settings.weeklyGoalMiles)
        let monthlyDisplay = toDisplayUnit(store.settings.monthlyGoalMiles)
        weeklyGoalText = String(format: "%.0f", weeklyDisplay)
        monthlyGoalText = String(format: "%.0f", monthlyDisplay)
    }

    private func saveAndDismiss() {
        // Parse values and convert from display unit back to miles for storage
        if let weekly = Double(weeklyGoalText), weekly > 0 {
            store.settings.weeklyGoalMiles = fromDisplayUnit(weekly)
        }
        if let monthly = Double(monthlyGoalText), monthly > 0 {
            store.settings.monthlyGoalMiles = fromDisplayUnit(monthly)
        }
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    GoalSettingsView()
}
