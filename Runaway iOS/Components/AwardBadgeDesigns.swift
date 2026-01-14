//
//  AwardBadgeDesigns.swift
//  Runaway iOS
//
//  Vibrant, detailed award badges with neon glow effects and animated borders
//

import SwiftUI

// MARK: - Main Custom Badge View

struct CustomAwardBadge: View {
    let award: AwardDefinition
    let isEarned: Bool
    let size: CGFloat

    @State private var animationPhase: CGFloat = 0

    init(award: AwardDefinition, isEarned: Bool, size: CGFloat = 80) {
        self.award = award
        self.isEarned = isEarned
        self.size = size
    }

    var body: some View {
        ZStack {
            // Outer glow for earned badges
            if isEarned {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [award.tier.glowColor.opacity(0.6), Color.clear],
                            center: .center,
                            startRadius: size * 0.3,
                            endRadius: size * 0.6
                        )
                    )
                    .frame(width: size * 1.2, height: size * 1.2)
                    .blur(radius: 8)
            }

            // Badge design based on category
            badgeDesign
                .frame(width: size, height: size)
                .opacity(isEarned ? 1.0 : 0.25)
                .saturation(isEarned ? 1.0 : 0.0)

            // Animated border for legendary tier
            if isEarned && award.tier.hasAnimation {
                AnimatedLegendaryBorder(size: size, phase: animationPhase)
            }
        }
        .onAppear {
            if award.tier.hasAnimation && isEarned {
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                    animationPhase = 1
                }
            }
        }
    }

    @ViewBuilder
    private var badgeDesign: some View {
        switch award.category {
        case .distance:
            DistanceBadgeV2(tier: award.tier, size: size, isEarned: isEarned)
        case .consistency:
            ConsistencyBadgeV2(tier: award.tier, size: size, isEarned: isEarned)
        case .speed:
            SpeedBadgeV2(tier: award.tier, size: size, isEarned: isEarned)
        case .milestone:
            MilestoneBadgeV2(tier: award.tier, size: size, isEarned: isEarned)
        case .special:
            SpecialBadgeV2(tier: award.tier, size: size, isEarned: isEarned)
        }
    }
}

// MARK: - Animated Legendary Border

struct AnimatedLegendaryBorder: View {
    let size: CGFloat
    let phase: CGFloat

    var body: some View {
        ZStack {
            // Rainbow rotating border
            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [
                            Color(red: 1.0, green: 0.2, blue: 0.2),
                            Color(red: 1.0, green: 0.6, blue: 0.0),
                            Color(red: 1.0, green: 1.0, blue: 0.0),
                            Color(red: 0.0, green: 1.0, blue: 0.5),
                            Color(red: 0.0, green: 0.8, blue: 1.0),
                            Color(red: 0.5, green: 0.2, blue: 1.0),
                            Color(red: 1.0, green: 0.2, blue: 0.8),
                            Color(red: 1.0, green: 0.2, blue: 0.2)
                        ],
                        center: .center,
                        startAngle: .degrees(360.0 * Double(phase)),
                        endAngle: .degrees(360.0 + 360.0 * Double(phase))
                    ),
                    lineWidth: size * 0.05
                )
                .frame(width: size * 1.08, height: size * 1.08)
                .blur(radius: 2)

            // Sharp border overlay
            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [
                            Color(red: 1.0, green: 0.9, blue: 0.4),
                            Color(red: 1.0, green: 0.75, blue: 0.0),
                            Color(red: 1.0, green: 0.9, blue: 0.4)
                        ],
                        center: .center,
                        startAngle: .degrees(360.0 * Double(phase)),
                        endAngle: .degrees(360.0 + 360.0 * Double(phase))
                    ),
                    lineWidth: size * 0.025
                )
                .frame(width: size * 1.05, height: size * 1.05)
        }
    }
}

// MARK: - Distance Badge (Mountain Trail themed)

struct DistanceBadgeV2: View {
    let tier: AwardTier
    let size: CGFloat
    let isEarned: Bool

    var body: some View {
        ZStack {
            // Background circle with gradient sky
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.1, green: 0.1, blue: 0.2),
                            Color(red: 0.15, green: 0.15, blue: 0.3)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Mountain silhouette background
            MountainRangeShape()
                .fill(
                    LinearGradient(
                        colors: [tier.color.opacity(0.4), tier.color.opacity(0.2)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.85, height: size * 0.5)
                .offset(y: size * 0.15)

            // Main mountain peak
            MountainPeakShape()
                .fill(
                    LinearGradient(
                        colors: [tier.color, tier.accentColor],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.5, height: size * 0.45)
                .offset(y: size * 0.1)

            // Snow cap
            SnowCapShape()
                .fill(Color.white.opacity(0.9))
                .frame(width: size * 0.2, height: size * 0.12)
                .offset(y: -size * 0.12)

            // Trail path
            TrailPathShape()
                .stroke(
                    LinearGradient(
                        colors: [tier.accentColor, tier.color],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: size * 0.02, lineCap: .round, dash: [size * 0.03, size * 0.02])
                )
                .frame(width: size * 0.3, height: size * 0.35)
                .offset(y: size * 0.15)

            // Stars in sky
            ForEach(0..<5, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: size * 0.02, height: size * 0.02)
                    .offset(
                        x: CGFloat.random(in: -size * 0.3...size * 0.3),
                        y: CGFloat.random(in: -size * 0.35 ... -size * 0.2)
                    )
            }

            // Neon glow border
            if isEarned {
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [tier.glowColor, tier.color, tier.glowColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: size * 0.035
                    )
                    .shadow(color: tier.glowColor.opacity(0.8), radius: 4)
            }

            // Outer ring
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [tier.color.opacity(0.8), tier.accentColor.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: size * 0.02
                )
        }
    }
}

// MARK: - Consistency Badge (Flame Streak themed)

struct ConsistencyBadgeV2: View {
    let tier: AwardTier
    let size: CGFloat
    let isEarned: Bool

    var body: some View {
        ZStack {
            // Shield background
            ShieldShapeV2()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.12, green: 0.12, blue: 0.18),
                            Color(red: 0.08, green: 0.08, blue: 0.12)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Inner shield glow
            ShieldShapeV2()
                .fill(
                    RadialGradient(
                        colors: [tier.color.opacity(0.3), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.4
                    )
                )
                .padding(size * 0.08)

            // Flame illustration
            FlameShape()
                .fill(
                    LinearGradient(
                        colors: [
                            tier.accentColor,
                            tier.color,
                            tier.color.opacity(0.8)
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(width: size * 0.4, height: size * 0.5)
                .offset(y: -size * 0.02)

            // Inner flame
            FlameShape()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.9), tier.accentColor],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(width: size * 0.2, height: size * 0.28)
                .offset(y: size * 0.05)

            // Streak number indicator
            Text("\u{221E}")
                .font(.system(size: size * 0.15, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.white, tier.color],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .offset(y: size * 0.28)

            // Neon border
            if isEarned {
                ShieldShapeV2()
                    .stroke(
                        LinearGradient(
                            colors: [tier.glowColor, tier.color, tier.glowColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: size * 0.03
                    )
                    .shadow(color: tier.glowColor.opacity(0.7), radius: 5)
            }

            // Outer border
            ShieldShapeV2()
                .stroke(
                    LinearGradient(
                        colors: [tier.color, tier.accentColor],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: size * 0.02
                )
        }
    }
}

// MARK: - Speed Badge (Lightning themed)

struct SpeedBadgeV2: View {
    let tier: AwardTier
    let size: CGFloat
    let isEarned: Bool

    var body: some View {
        ZStack {
            // Hexagon background
            HexagonShapeV2()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.1, green: 0.1, blue: 0.15),
                            Color(red: 0.05, green: 0.05, blue: 0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Electric field effect
            ForEach(0..<3, id: \.self) { i in
                HexagonShapeV2()
                    .stroke(tier.color.opacity(0.2), lineWidth: 1)
                    .padding(size * CGFloat(i + 1) * 0.08)
            }

            // Speed lines background
            ForEach(0..<4, id: \.self) { i in
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [tier.accentColor.opacity(0.6), Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: size * 0.25, height: size * 0.025)
                    .offset(x: -size * 0.22, y: CGFloat(i - 2) * size * 0.1 + size * 0.05)
            }

            // Main lightning bolt
            LightningBoltShapeV2()
                .fill(
                    LinearGradient(
                        colors: [Color.white, tier.color, tier.accentColor],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.35, height: size * 0.55)
                .shadow(color: tier.glowColor.opacity(0.8), radius: 8)

            // Electric sparks
            ForEach(0..<6, id: \.self) { i in
                Circle()
                    .fill(tier.glowColor)
                    .frame(width: size * 0.03, height: size * 0.03)
                    .offset(
                        x: cos(CGFloat(i) * .pi / 3) * size * 0.28,
                        y: sin(CGFloat(i) * .pi / 3) * size * 0.28
                    )
                    .blur(radius: 1)
            }

            // Neon border
            if isEarned {
                HexagonShapeV2()
                    .stroke(
                        LinearGradient(
                            colors: [tier.glowColor, tier.color, tier.glowColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: size * 0.03
                    )
                    .shadow(color: tier.glowColor.opacity(0.8), radius: 6)
            }

            // Outer border
            HexagonShapeV2()
                .stroke(
                    LinearGradient(
                        colors: [tier.color, tier.accentColor],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: size * 0.02
                )
        }
    }
}

// MARK: - Milestone Badge (Trophy Sunrise themed)

struct MilestoneBadgeV2: View {
    let tier: AwardTier
    let size: CGFloat
    let isEarned: Bool

    var body: some View {
        ZStack {
            // Starburst background
            StarBurstShapeV2(points: 12)
                .fill(
                    RadialGradient(
                        colors: [
                            tier.color.opacity(0.4),
                            Color(red: 0.1, green: 0.1, blue: 0.15)
                        ],
                        center: .center,
                        startRadius: size * 0.1,
                        endRadius: size * 0.5
                    )
                )

            // Sunrise rays
            ForEach(0..<8, id: \.self) { i in
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [tier.accentColor.opacity(0.6), Color.clear],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: size * 0.03, height: size * 0.35)
                    .offset(y: -size * 0.1)
                    .rotationEffect(.degrees(Double(i) * 45))
            }

            // Inner circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.12, green: 0.12, blue: 0.18),
                            Color(red: 0.08, green: 0.08, blue: 0.12)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.7, height: size * 0.7)

            // Trophy illustration
            TrophyShapeV2()
                .fill(
                    LinearGradient(
                        colors: [tier.color, tier.accentColor, tier.color],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size * 0.4, height: size * 0.45)
                .shadow(color: tier.glowColor.opacity(0.5), radius: 4)

            // Trophy shine
            TrophyShapeV2()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.4), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
                .frame(width: size * 0.4, height: size * 0.45)

            // Achievement number
            Text("1")
                .font(.system(size: size * 0.12, weight: .black, design: .rounded))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.15))
                .offset(y: -size * 0.08)

            // Neon glow inner ring
            if isEarned {
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [tier.glowColor.opacity(0.8), tier.color.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: size * 0.02
                    )
                    .frame(width: size * 0.72, height: size * 0.72)
                    .shadow(color: tier.glowColor.opacity(0.6), radius: 4)
            }

            // Outer starburst border
            if isEarned {
                StarBurstShapeV2(points: 12)
                    .stroke(
                        LinearGradient(
                            colors: [tier.glowColor, tier.color],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: size * 0.025
                    )
                    .shadow(color: tier.glowColor.opacity(0.7), radius: 5)
            }
        }
    }
}

// MARK: - Special Badge (Crown Gem themed)

struct SpecialBadgeV2: View {
    let tier: AwardTier
    let size: CGFloat
    let isEarned: Bool

    var body: some View {
        ZStack {
            // Outer glow aura
            Circle()
                .fill(
                    RadialGradient(
                        colors: [tier.color.opacity(0.4), Color.clear],
                        center: .center,
                        startRadius: size * 0.2,
                        endRadius: size * 0.5
                    )
                )

            // Diamond/gem background
            DiamondShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.1, green: 0.1, blue: 0.18),
                            Color(red: 0.15, green: 0.12, blue: 0.22)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.95, height: size * 0.95)

            // Prismatic inner shine
            DiamondShape()
                .fill(
                    AngularGradient(
                        colors: [
                            tier.color.opacity(0.3),
                            tier.accentColor.opacity(0.2),
                            Color.white.opacity(0.1),
                            tier.color.opacity(0.3)
                        ],
                        center: .center
                    )
                )
                .frame(width: size * 0.8, height: size * 0.8)

            // Crown illustration
            CrownShape()
                .fill(
                    LinearGradient(
                        colors: [tier.color, tier.accentColor, tier.color],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: size * 0.5, height: size * 0.35)
                .offset(y: -size * 0.05)
                .shadow(color: tier.glowColor.opacity(0.6), radius: 5)

            // Crown jewels
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white, tier.accentColor],
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.04
                        )
                    )
                    .frame(width: size * 0.08, height: size * 0.08)
                    .offset(x: CGFloat(i - 1) * size * 0.15, y: -size * 0.15)
            }

            // Star emblem below crown
            StarShapeV2(points: 5)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.9), tier.color],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.2, height: size * 0.2)
                .offset(y: size * 0.18)

            // Neon border
            if isEarned {
                DiamondShape()
                    .stroke(
                        LinearGradient(
                            colors: [tier.glowColor, tier.color, tier.accentColor, tier.glowColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: size * 0.03
                    )
                    .frame(width: size * 0.95, height: size * 0.95)
                    .shadow(color: tier.glowColor.opacity(0.8), radius: 6)
            }

            // Sparkle effects
            ForEach(0..<4, id: \.self) { i in
                Image(systemName: "sparkle")
                    .font(.system(size: size * 0.08))
                    .foregroundColor(Color.white.opacity(0.8))
                    .offset(
                        x: cos(CGFloat(i) * .pi / 2 + .pi / 4) * size * 0.35,
                        y: sin(CGFloat(i) * .pi / 2 + .pi / 4) * size * 0.35
                    )
            }
        }
    }
}

// MARK: - Custom Shapes V2

struct MountainRangeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: 0, y: h))
        path.addLine(to: CGPoint(x: w * 0.15, y: h * 0.5))
        path.addLine(to: CGPoint(x: w * 0.25, y: h * 0.7))
        path.addLine(to: CGPoint(x: w * 0.4, y: h * 0.3))
        path.addLine(to: CGPoint(x: w * 0.55, y: h * 0.6))
        path.addLine(to: CGPoint(x: w * 0.7, y: h * 0.2))
        path.addLine(to: CGPoint(x: w * 0.85, y: h * 0.55))
        path.addLine(to: CGPoint(x: w, y: h * 0.4))
        path.addLine(to: CGPoint(x: w, y: h))
        path.closeSubpath()

        return path
    }
}

struct MountainPeakShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: w * 0.5, y: 0))
        path.addLine(to: CGPoint(x: w * 0.15, y: h))
        path.addLine(to: CGPoint(x: w * 0.35, y: h * 0.7))
        path.addLine(to: CGPoint(x: w * 0.5, y: h))
        path.addLine(to: CGPoint(x: w * 0.65, y: h * 0.7))
        path.addLine(to: CGPoint(x: w * 0.85, y: h))
        path.closeSubpath()

        return path
    }
}

struct SnowCapShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: w * 0.5, y: 0))
        path.addLine(to: CGPoint(x: w * 0.2, y: h * 0.8))
        path.addQuadCurve(to: CGPoint(x: w * 0.4, y: h * 0.6), control: CGPoint(x: w * 0.3, y: h))
        path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.9))
        path.addLine(to: CGPoint(x: w * 0.6, y: h * 0.6))
        path.addQuadCurve(to: CGPoint(x: w * 0.8, y: h * 0.8), control: CGPoint(x: w * 0.7, y: h))
        path.closeSubpath()

        return path
    }
}

struct TrailPathShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: w * 0.5, y: 0))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.3, y: h * 0.4),
            control: CGPoint(x: w * 0.7, y: h * 0.2)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.6, y: h * 0.7),
            control: CGPoint(x: w * 0.1, y: h * 0.6)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.4, y: h),
            control: CGPoint(x: w * 0.9, y: h * 0.85)
        )

        return path
    }
}

struct ShieldShapeV2: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: w * 0.5, y: 0))
        path.addLine(to: CGPoint(x: w, y: h * 0.12))
        path.addLine(to: CGPoint(x: w, y: h * 0.55))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.5, y: h),
            control: CGPoint(x: w * 0.85, y: h * 0.85)
        )
        path.addQuadCurve(
            to: CGPoint(x: 0, y: h * 0.55),
            control: CGPoint(x: w * 0.15, y: h * 0.85)
        )
        path.addLine(to: CGPoint(x: 0, y: h * 0.12))
        path.closeSubpath()

        return path
    }
}

struct FlameShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: w * 0.5, y: 0))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.15, y: h * 0.5),
            control: CGPoint(x: w * 0.1, y: h * 0.2)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.35, y: h * 0.65),
            control: CGPoint(x: w * 0.2, y: h * 0.6)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.5, y: h),
            control: CGPoint(x: w * 0.3, y: h * 0.9)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.65, y: h * 0.65),
            control: CGPoint(x: w * 0.7, y: h * 0.9)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.85, y: h * 0.5),
            control: CGPoint(x: w * 0.8, y: h * 0.6)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.5, y: 0),
            control: CGPoint(x: w * 0.9, y: h * 0.2)
        )
        path.closeSubpath()

        return path
    }
}

struct HexagonShapeV2: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

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

struct LightningBoltShapeV2: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: w * 0.6, y: 0))
        path.addLine(to: CGPoint(x: w * 0.2, y: h * 0.45))
        path.addLine(to: CGPoint(x: w * 0.45, y: h * 0.45))
        path.addLine(to: CGPoint(x: w * 0.35, y: h))
        path.addLine(to: CGPoint(x: w * 0.85, y: h * 0.38))
        path.addLine(to: CGPoint(x: w * 0.55, y: h * 0.38))
        path.closeSubpath()

        return path
    }
}

struct StarBurstShapeV2: Shape {
    let points: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.6

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

struct TrophyShapeV2: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Cup body
        path.move(to: CGPoint(x: w * 0.12, y: h * 0.08))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.25, y: h * 0.52),
            control: CGPoint(x: w * 0.08, y: h * 0.35)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.75, y: h * 0.52),
            control: CGPoint(x: w * 0.5, y: h * 0.62)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.88, y: h * 0.08),
            control: CGPoint(x: w * 0.92, y: h * 0.35)
        )
        path.addLine(to: CGPoint(x: w * 0.12, y: h * 0.08))

        // Stem
        path.move(to: CGPoint(x: w * 0.42, y: h * 0.52))
        path.addLine(to: CGPoint(x: w * 0.42, y: h * 0.72))
        path.addLine(to: CGPoint(x: w * 0.58, y: h * 0.72))
        path.addLine(to: CGPoint(x: w * 0.58, y: h * 0.52))

        // Base
        path.move(to: CGPoint(x: w * 0.25, y: h * 0.72))
        path.addLine(to: CGPoint(x: w * 0.2, y: h * 0.85))
        path.addLine(to: CGPoint(x: w * 0.15, y: h))
        path.addLine(to: CGPoint(x: w * 0.85, y: h))
        path.addLine(to: CGPoint(x: w * 0.8, y: h * 0.85))
        path.addLine(to: CGPoint(x: w * 0.75, y: h * 0.72))
        path.closeSubpath()

        return path
    }
}

struct DiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: w * 0.5, y: 0))
        path.addLine(to: CGPoint(x: w, y: h * 0.35))
        path.addLine(to: CGPoint(x: w * 0.5, y: h))
        path.addLine(to: CGPoint(x: 0, y: h * 0.35))
        path.closeSubpath()

        return path
    }
}

struct CrownShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: 0, y: h))
        path.addLine(to: CGPoint(x: 0, y: h * 0.4))
        path.addLine(to: CGPoint(x: w * 0.2, y: h * 0.55))
        path.addLine(to: CGPoint(x: w * 0.35, y: 0))
        path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.35))
        path.addLine(to: CGPoint(x: w * 0.65, y: 0))
        path.addLine(to: CGPoint(x: w * 0.8, y: h * 0.55))
        path.addLine(to: CGPoint(x: w, y: h * 0.4))
        path.addLine(to: CGPoint(x: w, y: h))
        path.closeSubpath()

        return path
    }
}

struct StarShapeV2: Shape {
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

// MARK: - Preview

#Preview("All Badges") {
    ScrollView {
        VStack(spacing: 30) {
            Text("Vibrant Award Badges")
                .font(.title.bold())
                .foregroundStyle(
                    LinearGradient(
                        colors: [.cyan, .purple, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            ForEach(AwardCategory.allCases, id: \.self) { category in
                VStack(spacing: 12) {
                    Text(category.displayName)
                        .font(.headline)
                        .foregroundColor(.white)

                    HStack(spacing: 16) {
                        ForEach(AwardTier.allCases, id: \.self) { tier in
                            VStack(spacing: 6) {
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
                                    size: 70
                                )
                                Text(tier.displayName)
                                    .font(.caption2)
                                    .foregroundColor(tier.color)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(white: 0.1).cornerRadius(16))
            }

            Divider()
                .background(Color.gray)

            Text("Unearned (Locked)")
                .font(.headline)
                .foregroundColor(.gray)

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
                        size: 55
                    )
                }
            }
        }
        .padding()
    }
    .background(Color(red: 0.05, green: 0.05, blue: 0.08))
}

#Preview("Large Badge Detail") {
    VStack(spacing: 30) {
        CustomAwardBadge(
            award: AwardDefinition(
                id: "legendary",
                name: "Legendary",
                description: "Ultimate achievement",
                icon: "crown",
                category: .special,
                tier: .platinum,
                requirement: AwardRequirement(type: .totalDistance, value: 1000, unit: "miles")
            ),
            isEarned: true,
            size: 150
        )

        Text("Legendary Achievement")
            .font(.title2.bold())
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.75, blue: 0.0),
                        Color(red: 1.0, green: 0.95, blue: 0.4)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }
    .padding(40)
    .background(Color(red: 0.05, green: 0.05, blue: 0.08))
}
