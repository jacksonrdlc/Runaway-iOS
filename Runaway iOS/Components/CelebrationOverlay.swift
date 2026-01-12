//
//  CelebrationOverlay.swift
//  Runaway iOS
//
//  Created by Claude on 1/12/26.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Celebration Overlay

struct CelebrationOverlay: View {
    let intensity: CelebrationIntensity
    let message: String
    let onDismiss: () -> Void

    @State private var confettiPieces: [ConfettiPiece] = []
    @State private var showMessage = false
    @State private var messageScale: CGFloat = 0.5
    @State private var messageOpacity: CGFloat = 0

    private let confettiColors: [Color] = [
        .red, .orange, .yellow, .green, .blue, .purple, .pink, .cyan
    ]

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(intensity == .full ? 0.3 : 0.1)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            // Confetti layer
            if intensity != .light {
                ForEach(confettiPieces) { piece in
                    ConfettiView(piece: piece)
                }
            }

            // Message layer
            VStack(spacing: 16) {
                // Icon
                celebrationIcon
                    .font(.system(size: iconSize))
                    .foregroundStyle(iconGradient)
                    .scaleEffect(messageScale)
                    .opacity(messageOpacity)

                // Message
                Text(message)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .scaleEffect(messageScale)
                    .opacity(messageOpacity)

                // Subtitle based on intensity
                Text(subtitleText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .opacity(messageOpacity)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .shadow(radius: 20)
            )
            .scaleEffect(messageScale)
            .opacity(messageOpacity)
        }
        .onAppear {
            startAnimation()
        }
    }

    // MARK: - Computed Properties

    private var iconSize: CGFloat {
        switch intensity {
        case .light: return 40
        case .medium: return 50
        case .full: return 60
        }
    }

    private var celebrationIcon: some View {
        Group {
            switch intensity {
            case .light:
                Image(systemName: "sparkle")
            case .medium:
                Image(systemName: "star.fill")
            case .full:
                Image(systemName: "party.popper.fill")
            }
        }
    }

    private var iconGradient: LinearGradient {
        switch intensity {
        case .light:
            return LinearGradient(
                colors: [.cyan, .blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .medium:
            return LinearGradient(
                colors: [.orange, .yellow],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .full:
            return LinearGradient(
                colors: [.pink, .purple, .blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var subtitleText: String {
        switch intensity {
        case .light: return "Small step, big impact!"
        case .medium: return "You're building momentum!"
        case .full: return "Commitment crushed!"
        }
    }

    // MARK: - Animation

    private func startAnimation() {
        // Generate confetti
        if intensity != .light {
            generateConfetti()
        }

        // Animate message
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            messageScale = 1.0
            messageOpacity = 1.0
        }

        // Auto-dismiss based on intensity
        let dismissDelay: TimeInterval = CelebrationConfig.config(for: intensity).animationDuration + 0.5
        DispatchQueue.main.asyncAfter(deadline: .now() + dismissDelay) {
            withAnimation(.easeOut(duration: 0.3)) {
                messageOpacity = 0
                messageScale = 0.8
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onDismiss()
            }
        }
    }

    private func generateConfetti() {
        let count = intensity == .full ? 50 : 25

        for i in 0..<count {
            let piece = ConfettiPiece(
                id: i,
                color: confettiColors.randomElement() ?? .blue,
                x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                y: -20,
                rotation: Double.random(in: 0...360),
                scale: CGFloat.random(in: 0.5...1.0)
            )
            confettiPieces.append(piece)
        }
    }
}

// MARK: - Confetti Piece Model

struct ConfettiPiece: Identifiable {
    let id: Int
    let color: Color
    let x: CGFloat
    let y: CGFloat
    let rotation: Double
    let scale: CGFloat
}

// MARK: - Confetti View

struct ConfettiView: View {
    let piece: ConfettiPiece

    @State private var offsetY: CGFloat = 0
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1

    var body: some View {
        confettiShape
            .fill(piece.color)
            .frame(width: 10 * piece.scale, height: 10 * piece.scale)
            .rotationEffect(.degrees(rotation))
            .offset(x: piece.x - UIScreen.main.bounds.width / 2, y: offsetY)
            .opacity(opacity)
            .onAppear {
                animate()
            }
    }

    private var confettiShape: some Shape {
        // Random shape selection
        let shapes: [AnyShape] = [
            AnyShape(Circle()),
            AnyShape(Rectangle()),
            AnyShape(RoundedRectangle(cornerRadius: 2))
        ]
        return shapes.randomElement() ?? AnyShape(Circle())
    }

    private func animate() {
        let duration = Double.random(in: 1.5...2.5)
        let delay = Double.random(in: 0...0.3)

        withAnimation(
            .easeIn(duration: duration)
            .delay(delay)
        ) {
            offsetY = UIScreen.main.bounds.height + 50
            rotation = piece.rotation + Double.random(in: 180...720)
        }

        withAnimation(
            .easeIn(duration: duration * 0.8)
            .delay(delay + duration * 0.2)
        ) {
            opacity = 0
        }
    }
}

// MARK: - AnyShape Helper

struct AnyShape: Shape {
    private let pathBuilder: (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        pathBuilder = { rect in
            shape.path(in: rect)
        }
    }

    func path(in rect: CGRect) -> Path {
        pathBuilder(rect)
    }
}

// MARK: - Preview

#Preview("Light Celebration") {
    CelebrationOverlay(
        intensity: .light,
        message: "Shoes are on!",
        onDismiss: {}
    )
}

#Preview("Medium Celebration") {
    CelebrationOverlay(
        intensity: .medium,
        message: "Quick walk done!",
        onDismiss: {}
    )
}

#Preview("Full Celebration") {
    CelebrationOverlay(
        intensity: .full,
        message: "LET'S GO!",
        onDismiss: {}
    )
}

// MARK: - Celebration View Modifier

struct CelebrationOverlayModifier: ViewModifier {
    @Binding var isPresented: Bool
    let intensity: CelebrationIntensity
    let message: String

    func body(content: Content) -> some View {
        ZStack {
            content

            if isPresented {
                CelebrationOverlay(
                    intensity: intensity,
                    message: message,
                    onDismiss: {
                        isPresented = false
                    }
                )
                .transition(.opacity)
                .zIndex(100)
            }
        }
    }
}

extension View {
    func celebrationOverlay(
        isPresented: Binding<Bool>,
        intensity: CelebrationIntensity,
        message: String
    ) -> some View {
        modifier(CelebrationOverlayModifier(
            isPresented: isPresented,
            intensity: intensity,
            message: message
        ))
    }
}
