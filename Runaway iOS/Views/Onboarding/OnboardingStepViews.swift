//
//  OnboardingStepViews.swift
//  Runaway iOS
//
//  Created by Claude on 1/12/26.
//

import SwiftUI

// MARK: - Welcome View

struct OnboardingWelcomeView: View {
    let onContinue: () -> Void

    @State private var showContent = false

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Logo/Icon
            VStack(spacing: 16) {
                Image(systemName: "figure.run.circle.fill")
                    .font(.system(size: 100))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(showContent ? 1 : 0.5)
                    .opacity(showContent ? 1 : 0)

                Text("Welcome to Runaway")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .opacity(showContent ? 1 : 0)
            }

            // Tagline
            Text("Track your runs, crush your goals,\nand become the runner you want to be.")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .opacity(showContent ? 1 : 0)

            Spacer()

            // Features preview
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "chart.line.uptrend.xyaxis", title: "Smart Analytics", description: "AI-powered insights for your training")
                FeatureRow(icon: "flame.fill", title: "Daily Commitments", description: "Build habits that stick")
                FeatureRow(icon: "person.fill.checkmark", title: "Personal Coach", description: "Guidance tailored to you")
            }
            .padding(.horizontal, 32)
            .opacity(showContent ? 1 : 0)

            Spacer()

            // Continue button
            Button(action: onContinue) {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
            .opacity(showContent ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                showContent = true
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Experience Assessment View

struct OnboardingExperienceView: View {
    @Binding var selectedLevel: ExperienceLevel
    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "figure.run")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)

                Text("What's your running experience?")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("This helps us personalize your experience")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 40)

            // Options
            VStack(spacing: 12) {
                ForEach(ExperienceLevel.allCases.filter { $0 != .skip }, id: \.self) { level in
                    ExperienceLevelCard(
                        level: level,
                        isSelected: selectedLevel == level,
                        onSelect: { selectedLevel = level }
                    )
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            // Buttons
            VStack(spacing: 12) {
                Button(action: onContinue) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(16)
                }

                Button(action: onSkip) {
                    Text("Skip for now")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

struct ExperienceLevelCard: View {
    let level: ExperienceLevel
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                Image(systemName: level.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : level.color)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(isSelected ? level.color : level.color.opacity(0.1))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(level.displayName)
                        .font(.headline)
                        .foregroundColor(isSelected ? .white : .primary)

                    Text(level.description)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)

                    if !level.weeklyMilesRange.isEmpty {
                        Text(level.weeklyMilesRange)
                            .font(.caption2)
                            .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? level.color : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Movement Test View

struct OnboardingMovementTestView: View {
    let onContinue: () -> Void
    let onSkip: () -> Void
    let onResult: (MovementTestResult) -> Void

    @StateObject private var cadenceService = CadenceAssessmentService.shared

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 50))
                    .foregroundColor(.green)

                Text("Quick Movement Test")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("March in place for 30 seconds to assess your natural cadence")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top, 40)

            Spacer()

            // Test area
            if cadenceService.isRunning {
                // Running test
                VStack(spacing: 24) {
                    // Progress ring
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                            .frame(width: 150, height: 150)

                        Circle()
                            .trim(from: 0, to: cadenceService.progress)
                            .stroke(Color.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 150, height: 150)
                            .rotationEffect(.degrees(-90))

                        VStack {
                            Text("\(Int(cadenceService.progress * 30))s")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            Text("of 30s")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Live cadence
                    VStack(spacing: 4) {
                        Text("\(Int(cadenceService.currentCadence))")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                        Text("steps/min")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Text("Keep marching!")
                        .font(.headline)
                        .foregroundColor(.green)
                }
            } else if let result = cadenceService.testResult {
                // Results
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)

                    VStack(spacing: 8) {
                        Text("Your Cadence")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text("\(Int(result.averageCadence)) steps/min")
                            .font(.system(size: 36, weight: .bold, design: .rounded))

                        Text(result.cadenceAssessment.rawValue)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(result.cadenceAssessment.color)
                    }

                    Text(result.cadenceAssessment.recommendation)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else {
                // Ready to start
                VStack(spacing: 16) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 80))
                        .foregroundColor(.gray)

                    Text("Tap Start when ready")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    if !cadenceService.isAvailable {
                        Text("Motion sensors not available on this device")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }

            Spacer()

            // Buttons
            VStack(spacing: 12) {
                if cadenceService.isRunning {
                    Button(action: { cadenceService.cancelTest() }) {
                        Text("Cancel")
                            .font(.headline)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(16)
                    }
                } else if cadenceService.testResult != nil {
                    Button(action: {
                        if let result = cadenceService.testResult {
                            onResult(result)
                        }
                        onContinue()
                    }) {
                        Text("Continue")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(16)
                    }
                } else {
                    Button(action: { cadenceService.startTest() }) {
                        Text("Start Test")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(cadenceService.isAvailable ? Color.green : Color.gray)
                            .cornerRadius(16)
                    }
                    .disabled(!cadenceService.isAvailable)

                    Button(action: onSkip) {
                        Text("Skip this step")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Location Permission View

struct OnboardingLocationView: View {
    let onContinue: () -> Void
    let onSkip: () -> Void
    let onPermissionResult: (Bool) -> Void

    @State private var permissionGranted = false

    var body: some View {
        VStack(spacing: 24) {
            // Map preview placeholder
            ZStack {
                // Background gradient to simulate map
                LinearGradient(
                    colors: [Color.green.opacity(0.3), Color.blue.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Grid pattern to simulate streets
                VStack(spacing: 20) {
                    ForEach(0..<4, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.white.opacity(0.5))
                            .frame(height: 2)
                    }
                }

                HStack(spacing: 30) {
                    ForEach(0..<5, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.white.opacity(0.5))
                            .frame(width: 2)
                    }
                }

                // Route line
                Path { path in
                    path.move(to: CGPoint(x: 50, y: 150))
                    path.addCurve(
                        to: CGPoint(x: 300, y: 50),
                        control1: CGPoint(x: 100, y: 100),
                        control2: CGPoint(x: 200, y: 80)
                    )
                }
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))

                // Location pin
                VStack(spacing: 0) {
                    Image(systemName: "location.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                    Circle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 20, height: 10)
                }
                .offset(x: 50, y: -20)
            }
            .frame(height: 200)
            .cornerRadius(20)
            .padding(.horizontal)
            .padding(.top)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                    .padding(.horizontal)
                    .padding(.top)
            )

            // Header
            VStack(spacing: 8) {
                Image(systemName: "location.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)

                Text("Track Your Routes")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Enable location to map your runs and discover popular routes nearby")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Benefits
            VStack(alignment: .leading, spacing: 12) {
                OnboardingBenefitRow(icon: "map.fill", text: "See your run routes on a map")
                OnboardingBenefitRow(icon: "figure.run", text: "Track pace and distance accurately")
                OnboardingBenefitRow(icon: "star.fill", text: "Discover popular running routes")
            }
            .padding(.horizontal, 32)

            Spacer()

            // Buttons
            VStack(spacing: 12) {
                Button(action: requestLocationPermission) {
                    HStack {
                        Image(systemName: "location.fill")
                        Text("Enable Location")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(16)
                }

                Button(action: {
                    onPermissionResult(false)
                    onSkip()
                }) {
                    Text("Maybe later")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    private func requestLocationPermission() {
        LocationManager.shared.requestLocationPermission()

        // Check result after a moment
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let granted = LocationManager.shared.authorizationStatus == .authorizedWhenInUse ||
                         LocationManager.shared.authorizationStatus == .authorizedAlways
            permissionGranted = granted
            onPermissionResult(granted)
            onContinue()
        }
    }
}

struct OnboardingBenefitRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - Coach Selection View

struct OnboardingCoachSelectionView: View {
    @Binding var selectedPersonality: CoachPersonality
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "person.fill.questionmark")
                    .font(.system(size: 50))
                    .foregroundColor(.purple)

                Text("Choose Your Coach Style")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("How do you like to receive feedback?")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 40)

            // Options
            VStack(spacing: 16) {
                ForEach(CoachPersonality.allCases, id: \.self) { personality in
                    CoachPersonalityCard(
                        personality: personality,
                        isSelected: selectedPersonality == personality,
                        onSelect: { selectedPersonality = personality }
                    )
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            // Continue button
            Button(action: onContinue) {
                Text("Continue")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

struct CoachPersonalityCard: View {
    let personality: CoachPersonality
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: personality.icon)
                        .font(.title2)
                        .foregroundColor(isSelected ? .white : personality.color)

                    Text(personality.displayName)
                        .font(.headline)
                        .foregroundColor(isSelected ? .white : .primary)

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                    }
                }

                Text(personality.description)
                    .font(.subheadline)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)

                // Sample message
                Text(personality.sampleMessage)
                    .font(.caption)
                    .italic()
                    .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                    .padding(.top, 4)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? personality.color : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Completion View

struct OnboardingCompletionView: View {
    let experienceLevel: ExperienceLevel
    let coachPersonality: CoachPersonality
    let onComplete: () -> Void

    @State private var showContent = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Success animation
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                    .scaleEffect(showContent ? 1 : 0.5)

                Text("You're All Set!")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Your personalized running experience is ready")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(showContent ? 1 : 0)

            // Summary
            VStack(spacing: 16) {
                SummaryRow(
                    icon: experienceLevel.icon,
                    title: "Experience",
                    value: experienceLevel.displayName,
                    color: experienceLevel.color
                )

                SummaryRow(
                    icon: coachPersonality.icon,
                    title: "Coach Style",
                    value: coachPersonality.displayName,
                    color: coachPersonality.color
                )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.secondarySystemBackground))
            )
            .padding(.horizontal, 32)
            .opacity(showContent ? 1 : 0)

            Spacer()

            // Start button
            Button(action: onComplete) {
                Text("Start Running")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
            .opacity(showContent ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                showContent = true
            }
        }
    }
}

struct SummaryRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)

            Text(title)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - Previews

#Preview("Welcome") {
    OnboardingWelcomeView(onContinue: {})
}

#Preview("Experience") {
    OnboardingExperienceView(
        selectedLevel: .constant(.intermediate),
        onContinue: {},
        onSkip: {}
    )
}

#Preview("Coach Selection") {
    OnboardingCoachSelectionView(
        selectedPersonality: .constant(.balanced),
        onContinue: {}
    )
}

#Preview("Completion") {
    OnboardingCompletionView(
        experienceLevel: .intermediate,
        coachPersonality: .balanced,
        onComplete: {}
    )
}
