//
//  TrainingProfileStore.swift
//  Runaway iOS
//

import Combine
import Foundation

@MainActor
final class TrainingProfileStore: ObservableObject {
    static let shared = TrainingProfileStore()

    private static let profileKey = "trainingProfile.v1"
    private static let personalizedKey = "trainingProfile.personalized.v1"
    private static let promptDismissedKey = "trainingProfile.promptDismissed.v1"

    @Published private(set) var profile: TrainingProfile
    @Published private(set) var needsPersonalization: Bool
    @Published private(set) var hasPersonalizedProfile: Bool

    private let defaults: UserDefaults
    private let existingPlan: WeeklyTrainingPlan?

    init(defaults: UserDefaults = .standard, existingPlan: WeeklyTrainingPlan? = nil) {
        self.defaults = defaults
        let migrationPlan = existingPlan
            ?? TrainingPlanService.cachedPlanForProfileMigration(defaults: defaults)
        self.existingPlan = migrationPlan

        guard let data = defaults.data(forKey: Self.profileKey),
              let decodedProfile = try? JSONDecoder().decode(TrainingProfile.self, from: data) else {
            profile = TrainingProfile.migrationSeed.validated(existingPlan: migrationPlan).profile
            hasPersonalizedProfile = false
            needsPersonalization = true
            persistInferredProfile(profile, defaults: defaults)
            return
        }

        profile = decodedProfile.validated(existingPlan: migrationPlan).profile
        let hasSavedPersonalization = defaults.bool(forKey: Self.personalizedKey)
        hasPersonalizedProfile = hasSavedPersonalization
        needsPersonalization = !hasSavedPersonalization && !defaults.bool(forKey: Self.promptDismissedKey)
    }

    func save(_ profile: TrainingProfile) throws {
        let validation = profile.validated(existingPlan: existingPlan)
        let data = try JSONEncoder().encode(validation.profile)

        defaults.set(data, forKey: Self.profileKey)
        defaults.set(true, forKey: Self.personalizedKey)
        defaults.set(false, forKey: Self.promptDismissedKey)
        self.profile = validation.profile
        hasPersonalizedProfile = true
        needsPersonalization = false
    }

    func reloadFromPersistence(existingPlan migrationPlan: WeeklyTrainingPlan? = nil) {
        let plan = migrationPlan
            ?? existingPlan
            ?? TrainingPlanService.cachedPlanForProfileMigration(defaults: defaults)
        guard let data = defaults.data(forKey: Self.profileKey),
              let decodedProfile = try? JSONDecoder().decode(TrainingProfile.self, from: data) else {
            profile = TrainingProfile.migrationSeed.validated(existingPlan: plan).profile
            hasPersonalizedProfile = false
            needsPersonalization = true
            persistInferredProfile(profile, defaults: defaults)
            return
        }

        profile = decodedProfile.validated(existingPlan: plan).profile
        hasPersonalizedProfile = defaults.bool(forKey: Self.personalizedKey)
        needsPersonalization = !hasPersonalizedProfile && !defaults.bool(forKey: Self.promptDismissedKey)
    }

    func resetToDefault() {
        let defaultProfile = TrainingProfile.runningFirstDefault.validated(existingPlan: existingPlan).profile
        if let data = try? JSONEncoder().encode(defaultProfile) {
            defaults.set(data, forKey: Self.profileKey)
        }
        defaults.set(false, forKey: Self.personalizedKey)
        defaults.set(false, forKey: Self.promptDismissedKey)
        profile = defaultProfile
        hasPersonalizedProfile = false
        needsPersonalization = true
    }

    func dismissPersonalizationPrompt() {
        defaults.set(true, forKey: Self.promptDismissedKey)
        needsPersonalization = false
    }

    private func persistInferredProfile(_ profile: TrainingProfile, defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: Self.profileKey)
        defaults.set(false, forKey: Self.personalizedKey)
        defaults.set(false, forKey: Self.promptDismissedKey)
    }
}
