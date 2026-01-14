//
//  CelebrationService.swift
//  Runaway iOS
//
//  Created by Claude on 1/12/26.
//

import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Celebration Service

/// Service for triggering celebration feedback (haptics, sounds, animations)
@MainActor
final class CelebrationService: ObservableObject {
    static let shared = CelebrationService()

    // Haptic generators
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    private let selectionFeedback = UISelectionFeedbackGenerator()

    // Published state for UI binding
    @Published var isShowingCelebration = false
    @Published var currentIntensity: CelebrationIntensity = .light

    private init() {
        prepareHaptics()
    }

    // MARK: - Haptic Preparation

    private func prepareHaptics() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        notificationFeedback.prepare()
        selectionFeedback.prepare()
    }

    // MARK: - Public Celebration Methods

    /// Trigger celebration based on commitment level
    func celebrate(for intensity: CelebrationIntensity) {
        currentIntensity = intensity
        isShowingCelebration = true

        switch intensity {
        case .light:
            triggerMicroCelebration()
        case .medium:
            triggerMiniCelebration()
        case .full:
            triggerFullCelebration()
        }
    }

    /// Trigger celebration for a commitment
    func celebrate(for commitment: DailyCommitment) {
        celebrate(for: commitment.celebrationIntensity)
    }

    /// Trigger streak celebration with special pattern
    func celebrateStreak(_ streakCount: Int) {
        if streakCount >= 7 {
            triggerStreakCelebration(count: streakCount)
        } else {
            triggerMiniCelebration()
        }
    }

    /// Dismiss celebration overlay
    func dismissCelebration() {
        isShowingCelebration = false
    }

    // MARK: - Micro Celebration (Light)

    /// Light celebration for micro-commitments
    /// Single light haptic + quick pulse animation
    func triggerMicroCelebration() {
        lightImpact.impactOccurred()

        // Double tap pattern for micro celebrations
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.lightImpact.impactOccurred(intensity: 0.5)
        }
    }

    // MARK: - Mini Celebration (Medium)

    /// Medium celebration for mini-commitments
    /// Medium haptic + confetti
    func triggerMiniCelebration() {
        mediumImpact.impactOccurred()

        // Success notification feel
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.notificationFeedback.notificationOccurred(.success)
        }
    }

    // MARK: - Full Celebration

    /// Full celebration for standard commitments
    /// Heavy haptic sequence + full confetti + sound
    func triggerFullCelebration() {
        // Initial heavy impact
        heavyImpact.impactOccurred()

        // Rising pattern
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.mediumImpact.impactOccurred()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.heavyImpact.impactOccurred()
        }

        // Success notification
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.notificationFeedback.notificationOccurred(.success)
        }
    }

    // MARK: - Streak Celebration

    /// Special celebration for streaks (7+ days)
    func triggerStreakCelebration(count: Int) {
        // Drumroll-like pattern
        let beatCount = min(count, 10) // Cap at 10 beats
        let beatInterval: TimeInterval = 0.08

        for i in 0..<beatCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + (beatInterval * Double(i))) { [weak self] in
                let intensity = CGFloat(i + 1) / CGFloat(beatCount)
                self?.mediumImpact.impactOccurred(intensity: intensity)
            }
        }

        // Final celebration burst
        DispatchQueue.main.asyncAfter(deadline: .now() + (beatInterval * Double(beatCount)) + 0.1) { [weak self] in
            self?.heavyImpact.impactOccurred()
            self?.notificationFeedback.notificationOccurred(.success)
        }
    }

    // MARK: - Selection Feedback

    /// Light selection feedback for UI interactions
    func selectionChanged() {
        selectionFeedback.selectionChanged()
    }

    /// Warning feedback
    func triggerWarning() {
        notificationFeedback.notificationOccurred(.warning)
    }

    /// Error feedback
    func triggerError() {
        notificationFeedback.notificationOccurred(.error)
    }
}

// MARK: - SwiftUI View Modifier

struct CelebrationModifier: ViewModifier {
    @ObservedObject var celebrationService = CelebrationService.shared
    let intensity: CelebrationIntensity

    func body(content: Content) -> some View {
        content
            .sensoryFeedback(.success, trigger: celebrationService.isShowingCelebration) { _, newValue in
                newValue && celebrationService.currentIntensity == intensity
            }
    }
}

extension View {
    func celebrationFeedback(for intensity: CelebrationIntensity) -> some View {
        modifier(CelebrationModifier(intensity: intensity))
    }
}

// MARK: - Celebration Configuration

struct CelebrationConfig {
    let hapticPattern: HapticPattern
    let confettiEnabled: Bool
    let soundEnabled: Bool
    let animationDuration: TimeInterval

    static let micro = CelebrationConfig(
        hapticPattern: .doubleTap,
        confettiEnabled: false,
        soundEnabled: false,
        animationDuration: 0.3
    )

    static let mini = CelebrationConfig(
        hapticPattern: .success,
        confettiEnabled: true,
        soundEnabled: false,
        animationDuration: 1.0
    )

    static let full = CelebrationConfig(
        hapticPattern: .celebration,
        confettiEnabled: true,
        soundEnabled: true,
        animationDuration: 2.0
    )

    static func config(for intensity: CelebrationIntensity) -> CelebrationConfig {
        switch intensity {
        case .light: return .micro
        case .medium: return .mini
        case .full: return .full
        }
    }
}

enum HapticPattern {
    case doubleTap
    case success
    case celebration
    case streak
}
