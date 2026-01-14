//
//  OnboardingContainerView.swift
//  Runaway iOS
//
//  Created by Claude on 1/12/26.
//

import SwiftUI

// MARK: - Onboarding Container View

struct OnboardingContainerView: View {
    @EnvironmentObject var userSession: UserSession
    @StateObject private var viewModel = OnboardingViewModel()

    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress indicator
                if viewModel.currentStep != .welcome && viewModel.currentStep != .completion {
                    OnboardingProgressBar(
                        currentStep: viewModel.currentStep.rawValue,
                        totalSteps: OnboardingStep.totalSteps
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)
                }

                // Step content
                TabView(selection: $viewModel.currentStep) {
                    OnboardingWelcomeView(onContinue: viewModel.nextStep)
                        .tag(OnboardingStep.welcome)

                    OnboardingProfileSetupView(
                        firstName: $viewModel.firstName,
                        lastName: $viewModel.lastName,
                        onContinue: viewModel.nextStep
                    )
                    .tag(OnboardingStep.profileSetup)

                    OnboardingGoalsSetupView(
                        weeklyGoal: $viewModel.weeklyGoal,
                        monthlyGoal: $viewModel.monthlyGoal,
                        onContinue: viewModel.nextStep
                    )
                    .tag(OnboardingStep.goalsSetup)

                    OnboardingExperienceView(
                        selectedLevel: $viewModel.experienceLevel,
                        onContinue: viewModel.nextStep,
                        onSkip: viewModel.skipStep
                    )
                    .tag(OnboardingStep.experienceAssessment)

                    OnboardingMovementTestView(
                        onContinue: viewModel.nextStep,
                        onSkip: viewModel.skipStep,
                        onResult: viewModel.saveMovementResult
                    )
                    .tag(OnboardingStep.movementTest)

                    OnboardingLocationView(
                        onContinue: viewModel.nextStep,
                        onSkip: viewModel.skipStep,
                        onPermissionResult: viewModel.saveLocationPermission
                    )
                    .tag(OnboardingStep.locationPermission)

                    OnboardingCoachSelectionView(
                        selectedPersonality: $viewModel.coachPersonality,
                        onContinue: viewModel.nextStep
                    )
                    .tag(OnboardingStep.coachSelection)

                    OnboardingCompletionView(
                        experienceLevel: viewModel.experienceLevel,
                        coachPersonality: viewModel.coachPersonality,
                        onComplete: completeOnboarding
                    )
                    .tag(OnboardingStep.completion)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: viewModel.currentStep)
            }
        }
        .task {
            await viewModel.loadOnboardingState(for: userSession.userId)
        }
    }

    private func completeOnboarding() {
        Task {
            await viewModel.completeOnboarding()
            await MainActor.run {
                // Use markOnboardingCompleted to prevent re-checking from database
                userSession.markOnboardingCompleted()
            }
        }
    }
}

// MARK: - Onboarding View Model

@MainActor
class OnboardingViewModel: ObservableObject {
    @Published var currentStep: OnboardingStep = .welcome
    @Published var experienceLevel: ExperienceLevel = .intermediate
    @Published var coachPersonality: CoachPersonality = .balanced
    @Published var movementResult: MovementTestResult?
    @Published var locationPermissionGranted = false
    @Published var isLoading = false

    // Profile setup fields
    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var weeklyGoal: Double = 20.0
    @Published var monthlyGoal: Double = 80.0

    private var onboardingState: OnboardingState?
    private var hasLoadedInitialState = false
    private var athleteId: Int?

    // MARK: - Load State

    func loadOnboardingState(for userId: Int?) async {
        // Only load once - prevent re-loading from overwriting local navigation state
        guard !hasLoadedInitialState else { return }
        guard let userId = userId else { return }

        self.athleteId = userId
        isLoading = true
        defer { isLoading = false }

        do {
            let state = try await OnboardingService.getOrCreateOnboardingState(athleteId: userId)
            self.onboardingState = state
            self.hasLoadedInitialState = true

            // Restore state
            if let step = OnboardingStep(rawValue: state.currentStep) {
                currentStep = step
            }
            coachPersonality = state.coachPersonality
            if let level = state.experienceLevel {
                experienceLevel = level
            }
            locationPermissionGranted = state.locationPermissionGranted

            // Load existing goal settings
            let goalStore = GoalSettingsStore.shared
            weeklyGoal = goalStore.weeklyGoal
            monthlyGoal = goalStore.monthlyGoal
        } catch {
            print("❌ OnboardingViewModel: Failed to load state: \(error)")
            // Mark as loaded even on error to prevent infinite retry
            self.hasLoadedInitialState = true
        }
    }

    // MARK: - Navigation

    func nextStep() {
        guard let next = currentStep.next else { return }
        currentStep = next
        Task {
            await saveCurrentStep()
        }
    }

    func previousStep() {
        guard let previous = currentStep.previous else { return }
        currentStep = previous
        Task {
            await saveCurrentStep()
        }
    }

    func skipStep() {
        nextStep()
    }

    // MARK: - Save Methods

    private func saveCurrentStep() async {
        guard let stateId = onboardingState?.id else { return }

        do {
            try await OnboardingService.updateCurrentStep(stateId: stateId, step: currentStep.rawValue)
        } catch {
            print("❌ OnboardingViewModel: Failed to save current step: \(error)")
        }
    }

    func saveExperienceLevel() {
        guard let stateId = onboardingState?.id else { return }

        Task {
            try? await OnboardingService.updateExperienceLevel(stateId: stateId, level: experienceLevel)
        }
    }

    func saveMovementResult(_ result: MovementTestResult) {
        movementResult = result

        guard let stateId = onboardingState?.id else { return }

        Task {
            try? await OnboardingService.updateMovementTestResults(
                stateId: stateId,
                cadence: result.averageCadence,
                variance: result.variance
            )
        }
    }

    func saveLocationPermission(_ granted: Bool) {
        locationPermissionGranted = granted

        guard let stateId = onboardingState?.id else { return }

        Task {
            try? await OnboardingService.updateLocationPermission(stateId: stateId, granted: granted)
        }
    }

    func saveCoachPersonality() {
        guard let stateId = onboardingState?.id else { return }

        Task {
            try? await OnboardingService.updateCoachPersonality(stateId: stateId, personality: coachPersonality)
        }
    }

    func completeOnboarding() async {
        guard let stateId = onboardingState?.id else { return }

        do {
            // Save final preferences
            saveExperienceLevel()
            saveCoachPersonality()

            // Save profile info to athlete record
            await saveProfileData()

            // Save goals to GoalSettingsStore
            saveGoals()

            // Mark as complete
            let completedState = try await OnboardingService.completeOnboarding(stateId: stateId)
            self.onboardingState = completedState
            print("✅ OnboardingViewModel: Onboarding completed!")
        } catch {
            print("❌ OnboardingViewModel: Failed to complete onboarding: \(error)")
        }
    }

    // MARK: - Profile Data Saving

    private func saveProfileData() async {
        guard let athleteId = athleteId else {
            print("⚠️ OnboardingViewModel: No athlete ID, skipping profile save")
            return
        }

        do {
            try await AthleteService.shared.updateAthlete(
                athleteId: athleteId,
                firstname: firstName.trimmingCharacters(in: .whitespaces),
                lastname: lastName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : lastName.trimmingCharacters(in: .whitespaces),
                profileURL: nil
            )
            print("✅ OnboardingViewModel: Profile data saved")
        } catch {
            print("❌ OnboardingViewModel: Failed to save profile data: \(error)")
        }
    }

    private func saveGoals() {
        let goalStore = GoalSettingsStore.shared
        goalStore.weeklyGoal = weeklyGoal
        goalStore.monthlyGoal = monthlyGoal
        print("✅ OnboardingViewModel: Goals saved - Weekly: \(weeklyGoal)mi, Monthly: \(monthlyGoal)mi")
    }
}

// MARK: - Progress Bar

struct OnboardingProgressBar: View {
    let currentStep: Int
    let totalSteps: Int

    private var progress: Double {
        return Double(currentStep) / Double(totalSteps - 1)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 4)

                // Progress
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * progress, height: 4)
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Preview

#Preview {
    OnboardingContainerView()
        .environmentObject(UserSession.shared)
}
