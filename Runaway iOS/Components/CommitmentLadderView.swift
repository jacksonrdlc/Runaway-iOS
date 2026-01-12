//
//  CommitmentLadderView.swift
//  Runaway iOS
//
//  Created by Claude on 1/12/26.
//

import SwiftUI

// MARK: - Commitment Ladder View

/// Visual representation of the commitment progression ladder
struct CommitmentLadderView: View {
    let currentLevel: CommitmentLevel
    let microCompletedCount: Int
    let miniCompletedCount: Int
    let standardCompletedCount: Int

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Your Progress")
                    .font(.headline)

                Spacer()

                Text("Level: \(currentLevel.displayName)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(currentLevel.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(currentLevel.color.opacity(0.15))
                    )
            }

            // Ladder visualization
            HStack(spacing: 12) {
                // Micro level
                LadderStepView(
                    level: .micro,
                    completedCount: microCompletedCount,
                    isCurrentLevel: currentLevel == .micro,
                    isUnlocked: true
                )

                // Arrow
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Mini level
                LadderStepView(
                    level: .mini,
                    completedCount: miniCompletedCount,
                    isCurrentLevel: currentLevel == .mini,
                    isUnlocked: microCompletedCount >= 3 || currentLevel != .micro
                )

                // Arrow
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Standard level
                LadderStepView(
                    level: .standard,
                    completedCount: standardCompletedCount,
                    isCurrentLevel: currentLevel == .standard,
                    isUnlocked: miniCompletedCount >= 3 || currentLevel == .standard
                )
            }

            // Progress message
            progressMessage
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var progressMessage: some View {
        Group {
            switch currentLevel {
            case .micro:
                let remaining = max(0, 3 - microCompletedCount)
                if remaining > 0 {
                    Text("Complete \(remaining) more micro-commitment\(remaining == 1 ? "" : "s") to unlock mini!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("You've unlocked mini-commitments!")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            case .mini:
                let remaining = max(0, 3 - miniCompletedCount)
                if remaining > 0 {
                    Text("Complete \(remaining) more mini-commitment\(remaining == 1 ? "" : "s") to unlock full!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("You've unlocked full commitments!")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            case .standard:
                Text("You're at the highest level! Keep crushing it!")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
    }
}

// MARK: - Ladder Step View

struct LadderStepView: View {
    let level: CommitmentLevel
    let completedCount: Int
    let isCurrentLevel: Bool
    let isUnlocked: Bool

    var body: some View {
        VStack(spacing: 8) {
            // Icon with ring
            ZStack {
                // Background circle
                Circle()
                    .fill(isUnlocked ? level.color.opacity(0.15) : Color.gray.opacity(0.1))
                    .frame(width: 50, height: 50)

                // Progress ring (if unlocked)
                if isUnlocked && completedCount > 0 {
                    Circle()
                        .trim(from: 0, to: min(CGFloat(completedCount) / 3.0, 1.0))
                        .stroke(level.color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))
                }

                // Current level indicator
                if isCurrentLevel {
                    Circle()
                        .stroke(level.color, lineWidth: 2)
                        .frame(width: 56, height: 56)
                }

                // Icon
                Image(systemName: isUnlocked ? level.icon : "lock.fill")
                    .font(.title3)
                    .foregroundColor(isUnlocked ? level.color : .gray)
            }

            // Label
            Text(level.displayName)
                .font(.caption2)
                .fontWeight(isCurrentLevel ? .bold : .regular)
                .foregroundColor(isUnlocked ? .primary : .secondary)

            // Count
            if isUnlocked {
                Text("\(completedCount)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .opacity(isUnlocked ? 1.0 : 0.5)
    }
}

// MARK: - Compact Ladder View (for inline display)

struct CompactCommitmentLadder: View {
    let currentLevel: CommitmentLevel

    var body: some View {
        HStack(spacing: 4) {
            ForEach(CommitmentLevel.allCases, id: \.self) { level in
                Circle()
                    .fill(level == currentLevel ? level.color : level.color.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }
}

// MARK: - Preview

#Preview("Commitment Ladder") {
    VStack(spacing: 20) {
        CommitmentLadderView(
            currentLevel: .micro,
            microCompletedCount: 1,
            miniCompletedCount: 0,
            standardCompletedCount: 0
        )

        CommitmentLadderView(
            currentLevel: .mini,
            microCompletedCount: 5,
            miniCompletedCount: 2,
            standardCompletedCount: 0
        )

        CommitmentLadderView(
            currentLevel: .standard,
            microCompletedCount: 10,
            miniCompletedCount: 8,
            standardCompletedCount: 15
        )
    }
    .padding()
}

#Preview("Compact Ladder") {
    HStack(spacing: 20) {
        CompactCommitmentLadder(currentLevel: .micro)
        CompactCommitmentLadder(currentLevel: .mini)
        CompactCommitmentLadder(currentLevel: .standard)
    }
    .padding()
}
