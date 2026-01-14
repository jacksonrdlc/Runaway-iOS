//
//  MicroCommitmentCard.swift
//  Runaway iOS
//
//  Created by Claude on 1/12/26.
//

import SwiftUI

// MARK: - Micro Commitment Selector

struct MicroCommitmentSelector: View {
    let onSelect: (MicroCommitmentType) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Micro-commitment options
                    VStack(spacing: 12) {
                        ForEach(MicroCommitmentType.progressionOrder, id: \.self) { type in
                            MicroCommitmentOptionCard(
                                type: type,
                                onSelect: {
                                    CelebrationService.shared.selectionChanged()
                                    onSelect(type)
                                    dismiss()
                                }
                            )
                        }
                    }
                    .padding(.horizontal)

                    // Info footer
                    footerSection
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Start Small")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.cyan, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Micro-Commitments")
                .font(.title2)
                .fontWeight(.bold)

            Text("Sometimes the smallest step is the hardest.\nPick one tiny action to get started.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var footerSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(.yellow)

            Text("Completing micro-commitments builds momentum for bigger workouts!")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal)
    }
}

// MARK: - Micro Commitment Option Card

struct MicroCommitmentOptionCard: View {
    let type: MicroCommitmentType
    let onSelect: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(type.color.opacity(0.15))
                        .frame(width: 50, height: 50)

                    Image(systemName: type.icon)
                        .font(.title2)
                        .foregroundColor(type.color)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    HStack(spacing: 8) {
                        Label(type.durationText, systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("•")
                            .foregroundColor(.secondary)

                        Text(type.motivationalMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Arrow
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .contentShape(Rectangle()) // Make entire card tappable
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Micro Commitment Card (Inline Display)

struct MicroCommitmentCard: View {
    let commitment: DailyCommitment
    let onComplete: () -> Void

    @State private var timeRemaining: Int = 0
    @State private var isTimerRunning = false
    @State private var timerProgress: CGFloat = 0

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Label("Micro-Commitment", systemImage: "sparkle")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.cyan)

                Spacer()

                if let microType = commitment.microCommitmentType {
                    Text(microType.durationText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Main content
            if let microType = commitment.microCommitmentType {
                HStack(spacing: 16) {
                    // Icon with progress ring
                    ZStack {
                        Circle()
                            .stroke(microType.color.opacity(0.2), lineWidth: 4)
                            .frame(width: 60, height: 60)

                        Circle()
                            .trim(from: 0, to: timerProgress)
                            .stroke(microType.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(-90))

                        Image(systemName: microType.icon)
                            .font(.title2)
                            .foregroundColor(microType.color)
                    }

                    // Text content
                    VStack(alignment: .leading, spacing: 4) {
                        Text(microType.displayName)
                            .font(.headline)

                        if isTimerRunning {
                            Text("\(timeRemaining) seconds remaining")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Text(microType.motivationalMessage)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()
                }
            }

            // Action button
            Button(action: handleAction) {
                HStack {
                    Image(systemName: isTimerRunning ? "checkmark.circle.fill" : "play.fill")
                    Text(isTimerRunning ? "Done!" : "Start")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isTimerRunning ? Color.green : Color.cyan)
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .onReceive(timer) { _ in
            if isTimerRunning && timeRemaining > 0 {
                timeRemaining -= 1
                updateProgress()
            }
        }
    }

    private func handleAction() {
        if isTimerRunning {
            // Complete the commitment
            onComplete()
        } else {
            // Start the timer
            if let microType = commitment.microCommitmentType {
                timeRemaining = microType.durationSeconds
                isTimerRunning = true
                CelebrationService.shared.selectionChanged()
            }
        }
    }

    private func updateProgress() {
        guard let microType = commitment.microCommitmentType else { return }
        let total = CGFloat(microType.durationSeconds)
        let elapsed = total - CGFloat(timeRemaining)
        withAnimation(.linear(duration: 1)) {
            timerProgress = elapsed / total
        }
    }
}

// MARK: - Previews

#Preview("Micro Commitment Selector") {
    MicroCommitmentSelector(onSelect: { type in
        print("Selected: \(type.displayName)")
    })
}

#Preview("Micro Commitment Card") {
    MicroCommitmentCard(
        commitment: DailyCommitment(
            athleteId: 1,
            microCommitmentType: .putOnShoes
        ),
        onComplete: {}
    )
    .padding()
}
