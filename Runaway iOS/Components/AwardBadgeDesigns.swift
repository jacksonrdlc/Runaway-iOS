//
//  AwardBadgeDesigns.swift
//  Runaway iOS
//
//  Custom SVG-style award badge designs for a premium look
//

import SwiftUI

// MARK: - Main Custom Badge View

struct CustomAwardBadge: View {
    let award: AwardDefinition
    let isEarned: Bool
    let size: CGFloat

    init(award: AwardDefinition, isEarned: Bool, size: CGFloat = 80) {
        self.award = award
        self.isEarned = isEarned
        self.size = size
    }

    var body: some View {
        ZStack {
            // Badge design based on category
            badgeDesign
                .frame(width: size, height: size)
                .opacity(isEarned ? 1.0 : 0.3)
                .saturation(isEarned ? 1.0 : 0.0)
        }
    }

    @ViewBuilder
    private var badgeDesign: some View {
        switch award.category {
        case .distance:
            DistanceBadge(tier: award.tier, size: size)
        case .consistency:
            ConsistencyBadge(tier: award.tier, size: size)
        case .speed:
            SpeedBadge(tier: award.tier, size: size)
        case .milestone:
            MilestoneBadge(tier: award.tier, size: size)
        case .special:
            SpecialBadge(tier: award.tier, size: size)
        }
    }
}

// MARK: - Distance Badge (Road/Path themed)

struct DistanceBadge: View {
    let tier: AwardTier
    let size: CGFloat

    var body: some View {
        ZStack {
            // Outer medal ring
            Circle()
                .fill(
                    LinearGradient(
                        colors: [tier.color.opacity(0.9), tier.color.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Inner circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.black.opacity(0.1), Color.black.opacity(0.3)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(size * 0.1)

            // Road/path icon
            RoadPathShape()
                .fill(tier.color)
                .frame(width: size * 0.5, height: size * 0.5)

            // Shine effect
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.4), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
                .padding(size * 0.05)

            // Border
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [tier.color, tier.color.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: size * 0.04
                )
        }
    }
}

// MARK: - Consistency Badge (Calendar/Streak themed)

struct ConsistencyBadge: View {
    let tier: AwardTier
    let size: CGFloat

    var body: some View {
        ZStack {
            // Shield shape background
            ShieldShape()
                .fill(
                    LinearGradient(
                        colors: [tier.color, tier.color.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Inner shield
            ShieldShape()
                .fill(
                    LinearGradient(
                        colors: [Color.black.opacity(0.2), Color.black.opacity(0.4)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(size * 0.08)

            // Calendar grid
            VStack(spacing: size * 0.03) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: size * 0.03) {
                        ForEach(0..<3, id: \.self) { col in
                            RoundedRectangle(cornerRadius: size * 0.02)
                                .fill(tier.color)
                                .frame(width: size * 0.12, height: size * 0.1)
                        }
                    }
                }
            }
            .offset(y: size * 0.05)

            // Checkmark overlay
            Image(systemName: "checkmark")
                .font(.system(size: size * 0.25, weight: .bold))
                .foregroundColor(tier.color)
                .offset(y: size * 0.05)

            // Shine
            ShieldShape()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.3), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
                .padding(size * 0.02)

            // Border
            ShieldShape()
                .stroke(tier.color, lineWidth: size * 0.03)
        }
    }
}

// MARK: - Speed Badge (Lightning/Bolt themed)

struct SpeedBadge: View {
    let tier: AwardTier
    let size: CGFloat

    var body: some View {
        ZStack {
            // Hexagonal background
            HexagonShape()
                .fill(
                    LinearGradient(
                        colors: [tier.color, tier.color.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Inner hexagon
            HexagonShape()
                .fill(
                    LinearGradient(
                        colors: [Color.black.opacity(0.15), Color.black.opacity(0.35)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(size * 0.1)

            // Lightning bolt
            LightningBoltShape()
                .fill(
                    LinearGradient(
                        colors: [tier.color, Color.white.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.4, height: size * 0.55)

            // Speed lines
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(tier.color.opacity(0.6))
                    .frame(width: size * 0.15, height: size * 0.03)
                    .offset(x: -size * 0.25, y: CGFloat(i - 1) * size * 0.12)
            }

            // Shine
            HexagonShape()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.35), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
                .padding(size * 0.03)

            // Border
            HexagonShape()
                .stroke(tier.color, lineWidth: size * 0.035)
        }
    }
}

// MARK: - Milestone Badge (Trophy/Flag themed)

struct MilestoneBadge: View {
    let tier: AwardTier
    let size: CGFloat

    var body: some View {
        ZStack {
            // Star burst background
            StarBurstShape(points: 8)
                .fill(
                    LinearGradient(
                        colors: [tier.color, tier.color.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Inner circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.black.opacity(0.2), Color.black.opacity(0.4)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(size * 0.2)

            // Trophy icon
            TrophyShape()
                .fill(
                    LinearGradient(
                        colors: [tier.color, tier.color.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.4, height: size * 0.45)

            // Shine
            StarBurstShape(points: 8)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.3), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
                .padding(size * 0.02)
        }
    }
}

// MARK: - Special Badge (Star/Premium themed)

struct SpecialBadge: View {
    let tier: AwardTier
    let size: CGFloat

    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [tier.color.opacity(0.3), Color.clear],
                        center: .center,
                        startRadius: size * 0.3,
                        endRadius: size * 0.5
                    )
                )

            // Medal with ribbon
            VStack(spacing: 0) {
                // Ribbon
                RibbonShape()
                    .fill(
                        LinearGradient(
                            colors: [tier.color.opacity(0.8), tier.color.opacity(0.5)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size * 0.5, height: size * 0.25)

                // Medal
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [tier.color, tier.color.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.black.opacity(0.1), Color.black.opacity(0.3)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .padding(size * 0.06)

                    // Star
                    StarShape(points: 5)
                        .fill(
                            LinearGradient(
                                colors: [tier.color, Color.white.opacity(0.5)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: size * 0.35, height: size * 0.35)

                    // Shine
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.4), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .center
                            )
                        )
                        .padding(size * 0.03)

                    // Border
                    Circle()
                        .strokeBorder(tier.color, lineWidth: size * 0.025)
                }
                .frame(width: size * 0.7, height: size * 0.7)
            }
        }
    }
}

// MARK: - Custom Shapes

struct RoadPathShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        // Winding road
        path.move(to: CGPoint(x: width * 0.3, y: height))
        path.addQuadCurve(
            to: CGPoint(x: width * 0.7, y: height * 0.6),
            control: CGPoint(x: width * 0.1, y: height * 0.7)
        )
        path.addQuadCurve(
            to: CGPoint(x: width * 0.4, y: height * 0.2),
            control: CGPoint(x: width * 0.9, y: height * 0.4)
        )
        path.addLine(to: CGPoint(x: width * 0.5, y: 0))

        // Road width
        path.addLine(to: CGPoint(x: width * 0.6, y: height * 0.2))
        path.addQuadCurve(
            to: CGPoint(x: width * 0.8, y: height * 0.6),
            control: CGPoint(x: width * 0.95, y: height * 0.35)
        )
        path.addQuadCurve(
            to: CGPoint(x: width * 0.5, y: height),
            control: CGPoint(x: width * 0.2, y: height * 0.75)
        )
        path.closeSubpath()

        return path
    }
}

struct ShieldShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        path.move(to: CGPoint(x: width * 0.5, y: 0))
        path.addLine(to: CGPoint(x: width, y: height * 0.15))
        path.addLine(to: CGPoint(x: width, y: height * 0.6))
        path.addQuadCurve(
            to: CGPoint(x: width * 0.5, y: height),
            control: CGPoint(x: width * 0.9, y: height * 0.85)
        )
        path.addQuadCurve(
            to: CGPoint(x: 0, y: height * 0.6),
            control: CGPoint(x: width * 0.1, y: height * 0.85)
        )
        path.addLine(to: CGPoint(x: 0, y: height * 0.15))
        path.closeSubpath()

        return path
    }
}

struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let center = CGPoint(x: width / 2, y: height / 2)
        let radius = min(width, height) / 2

        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3 - .pi / 2
            let point = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()

        return path
    }
}

struct LightningBoltShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        path.move(to: CGPoint(x: width * 0.55, y: 0))
        path.addLine(to: CGPoint(x: width * 0.2, y: height * 0.45))
        path.addLine(to: CGPoint(x: width * 0.45, y: height * 0.45))
        path.addLine(to: CGPoint(x: width * 0.35, y: height))
        path.addLine(to: CGPoint(x: width * 0.8, y: height * 0.4))
        path.addLine(to: CGPoint(x: width * 0.55, y: height * 0.4))
        path.closeSubpath()

        return path
    }
}

struct StarBurstShape: Shape {
    let points: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.5

        for i in 0..<(points * 2) {
            let angle = CGFloat(i) * .pi / CGFloat(points) - .pi / 2
            let radius = i.isMultiple(of: 2) ? outerRadius : innerRadius
            let point = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()

        return path
    }
}

struct StarShape: Shape {
    let points: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.4

        for i in 0..<(points * 2) {
            let angle = CGFloat(i) * .pi / CGFloat(points) - .pi / 2
            let radius = i.isMultiple(of: 2) ? outerRadius : innerRadius
            let point = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()

        return path
    }
}

struct TrophyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        // Cup body
        path.move(to: CGPoint(x: width * 0.15, y: height * 0.1))
        path.addLine(to: CGPoint(x: width * 0.25, y: height * 0.55))
        path.addQuadCurve(
            to: CGPoint(x: width * 0.75, y: height * 0.55),
            control: CGPoint(x: width * 0.5, y: height * 0.65)
        )
        path.addLine(to: CGPoint(x: width * 0.85, y: height * 0.1))
        path.addLine(to: CGPoint(x: width * 0.15, y: height * 0.1))

        // Handle left
        path.move(to: CGPoint(x: width * 0.15, y: height * 0.15))
        path.addQuadCurve(
            to: CGPoint(x: width * 0.15, y: height * 0.4),
            control: CGPoint(x: 0, y: height * 0.27)
        )

        // Handle right
        path.move(to: CGPoint(x: width * 0.85, y: height * 0.15))
        path.addQuadCurve(
            to: CGPoint(x: width * 0.85, y: height * 0.4),
            control: CGPoint(x: width, y: height * 0.27)
        )

        // Stem
        path.move(to: CGPoint(x: width * 0.4, y: height * 0.55))
        path.addLine(to: CGPoint(x: width * 0.4, y: height * 0.75))
        path.addLine(to: CGPoint(x: width * 0.6, y: height * 0.75))
        path.addLine(to: CGPoint(x: width * 0.6, y: height * 0.55))

        // Base
        path.move(to: CGPoint(x: width * 0.25, y: height * 0.75))
        path.addLine(to: CGPoint(x: width * 0.25, y: height * 0.85))
        path.addLine(to: CGPoint(x: width * 0.2, y: height))
        path.addLine(to: CGPoint(x: width * 0.8, y: height))
        path.addLine(to: CGPoint(x: width * 0.75, y: height * 0.85))
        path.addLine(to: CGPoint(x: width * 0.75, y: height * 0.75))
        path.closeSubpath()

        return path
    }
}

struct RibbonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        // Left ribbon tail
        path.move(to: CGPoint(x: 0, y: height))
        path.addLine(to: CGPoint(x: width * 0.15, y: height * 0.5))
        path.addLine(to: CGPoint(x: width * 0.3, y: height))

        // Right ribbon tail
        path.move(to: CGPoint(x: width * 0.7, y: height))
        path.addLine(to: CGPoint(x: width * 0.85, y: height * 0.5))
        path.addLine(to: CGPoint(x: width, y: height))

        // Top connector
        path.move(to: CGPoint(x: width * 0.2, y: 0))
        path.addQuadCurve(
            to: CGPoint(x: width * 0.8, y: 0),
            control: CGPoint(x: width * 0.5, y: height * 0.3)
        )
        path.addLine(to: CGPoint(x: width * 0.7, y: height * 0.3))
        path.addQuadCurve(
            to: CGPoint(x: width * 0.3, y: height * 0.3),
            control: CGPoint(x: width * 0.5, y: height * 0.5)
        )
        path.closeSubpath()

        return path
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 30) {
            Text("Custom Award Badges")
                .font(.title.bold())

            ForEach(AwardCategory.allCases, id: \.self) { category in
                VStack(spacing: 10) {
                    Text(category.displayName)
                        .font(.headline)

                    HStack(spacing: 20) {
                        ForEach(AwardTier.allCases, id: \.self) { tier in
                            VStack {
                                CustomAwardBadge(
                                    award: AwardDefinition(
                                        id: "test",
                                        name: "Test",
                                        description: "Test",
                                        icon: "star",
                                        category: category,
                                        tier: tier,
                                        requirement: AwardRequirement(type: .totalDistance, value: 100, unit: "miles")
                                    ),
                                    isEarned: true,
                                    size: 60
                                )
                                Text(tier.displayName)
                                    .font(.caption2)
                            }
                        }
                    }
                }
            }

            Divider()

            Text("Unearned (Grayed Out)")
                .font(.headline)

            HStack(spacing: 20) {
                ForEach(AwardCategory.allCases, id: \.self) { category in
                    CustomAwardBadge(
                        award: AwardDefinition(
                            id: "test",
                            name: "Test",
                            description: "Test",
                            icon: "star",
                            category: category,
                            tier: .gold,
                            requirement: AwardRequirement(type: .totalDistance, value: 100, unit: "miles")
                        ),
                        isEarned: false,
                        size: 50
                    )
                }
            }
        }
        .padding()
    }
}
