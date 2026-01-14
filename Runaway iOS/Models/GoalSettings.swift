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
    @Environment(\.dismiss) var dismiss

    @State private var weeklyGoalText: String = ""
    @State private var monthlyGoalText: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Text("Weekly Goal")
                        Spacer()
                        TextField("Miles", text: $weeklyGoalText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("mi")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Monthly Goal")
                        Spacer()
                        TextField("Miles", text: $monthlyGoalText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("mi")
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
                        weeklyGoalText = String(format: "%.0f", store.settings.weeklyGoalMiles)
                        monthlyGoalText = String(format: "%.0f", store.settings.monthlyGoalMiles)
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
                weeklyGoalText = String(format: "%.0f", store.settings.weeklyGoalMiles)
                monthlyGoalText = String(format: "%.0f", store.settings.monthlyGoalMiles)
            }
        }
    }

    private func saveAndDismiss() {
        // Parse and save values
        if let weekly = Double(weeklyGoalText), weekly > 0 {
            store.settings.weeklyGoalMiles = weekly
        }
        if let monthly = Double(monthlyGoalText), monthly > 0 {
            store.settings.monthlyGoalMiles = monthly
        }
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    GoalSettingsView()
}
