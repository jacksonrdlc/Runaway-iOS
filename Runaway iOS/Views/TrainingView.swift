//
//  TrainingView.swift
//  Runaway iOS
//
//  Training view with streamlined hierarchy:
//  Action-first → Readiness → Progress → Details
//
//  Based on UX research for athletic apps:
//  - Eastern Peak fitness app best practices
//  - Output Sports athlete monitoring dashboards
//  - Strava case study by Samantha Marin
//

import SwiftUI

struct TrainingView: View {
    @Environment(DataManager.self) var dataManager
    @Environment(AppRouter.self) private var router

    private var greetingPrefix: String {
        let h = Calendar.current.component(.hour, from: Date())
        if h < 12 { return "Morning" }
        if h < 17 { return "Afternoon" }
        return "Evening"
    }

    private var firstName: String { dataManager.athlete?.firstname ?? "there" }
    private var avatarInitial: String {
        String((dataManager.athlete?.firstname ?? "?").prefix(1)).uppercased()
    }

    var body: some View {
        ZStack {
            AppTheme.Colors.DarkMode.background.ignoresSafeArea()

            if dataManager.activities.isEmpty {
                EmptyInsightsStateView()
            } else {
                ScrollView {
                    VStack(spacing: 16) {

                        // ── 1. Greeting header ─────────────────────────────
                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(Date(), format: .dateTime.weekday(.wide).month(.abbreviated).day())
                                    .font(AppTheme.Typography.subheadline)
                                    .foregroundColor(AppTheme.Colors.DarkMode.textSecondary)
                                Text("\(greetingPrefix), \(firstName)")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(AppTheme.Colors.warmAmber.opacity(0.16))
                                    .frame(width: 40, height: 40)
                                    .overlay(Circle().stroke(AppTheme.Colors.Semantic.border, lineWidth: 1))
                                Text(avatarInitial)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundColor(AppTheme.Colors.warmAmber)
                            }
                        }
                        .padding(.horizontal, AppTheme.Spacing.lg)
                        .padding(.top, AppTheme.Spacing.sm)

                        // ── 2. Readiness ring card ─────────────────────────
                        ReadinessBanner()

                        // ── 3. This Week (hero mileage + goal) ─────────────
                        WeeklyStatsCard()

                        // ── 4. Next Up (planned workout or ready prompt) ───
                        TodaysFocusCard()

                        // ── 5. Latest activity ─────────────────────────────
                        latestSection
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .padding(.bottom, 100) // clear FAB
                }
            }

        }
        .navigationBarHidden(true)
        .refreshable { await dataManager.refreshActivities() }
    }

    // MARK: - Latest section

    @ViewBuilder
    private var latestSection: some View {
        if let latest = dataManager.activities.first {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    EyebrowLabel(text: "LATEST")
                    Spacer()
                    Button(action: {}) {
                        Text("See all")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(AppTheme.Colors.warmAmber)
                    }
                }
                .padding(.horizontal, 2)

                let previousSlice = Array(dataManager.activities.dropFirst().prefix(10).map { toLocal($0) })
                CardView(
                    activity: toLocal(latest),
                    previousActivities: previousSlice
                )
            }
        }
    }

    private func toLocal(_ a: Activity) -> LocalActivity {
        LocalActivity(
            id: a.id,
            name: a.name ?? "Activity",
            type: a.type ?? "",
            summary_polyline: a.summary_polyline ?? "",
            distance: a.distance ?? 0,
            start_date: (a.start_date).map { Date(timeIntervalSince1970: $0) },
            elapsed_time: a.elapsed_time ?? 0
        )
    }
}

// MARK: - Notification for Coach Navigation

extension Notification.Name {
    static let navigateToCoachTab = Notification.Name("navigateToCoachTab")
}

// MARK: - Empty State

struct EmptyInsightsStateView: View {
    private var colors: (textPrimary: Color, textSecondary: Color) {
        (AppTheme.Colors.adaptiveTextPrimary, AppTheme.Colors.adaptiveTextSecondary)
    }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.xl) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 80))
                .foregroundColor(AppTheme.Colors.accent)

            VStack(spacing: AppTheme.Spacing.sm) {
                Text("No Insights Available")
                    .font(AppTheme.Typography.title)
                    .foregroundColor(colors.textPrimary)

                Text("Start logging activities to see AI-powered insights and performance analytics.")
                    .font(AppTheme.Typography.body)
                    .foregroundColor(colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(AppTheme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Loading State

struct LoadingInsightsStateView: View {
    @State private var animationPhase = 0.0

    private var colors: (textPrimary: Color, textSecondary: Color) {
        (AppTheme.Colors.adaptiveTextPrimary, AppTheme.Colors.adaptiveTextSecondary)
    }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(AppTheme.Colors.accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(animationPhase))
                    .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: animationPhase)
            }

            VStack(spacing: AppTheme.Spacing.sm) {
                Text("Loading Insights")
                    .font(AppTheme.Typography.title)
                    .foregroundColor(colors.textPrimary)

                Text("Analyzing your performance data...")
                    .font(AppTheme.Typography.body)
                    .foregroundColor(colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppTheme.Spacing.xxl)
        .onAppear {
            animationPhase = 360
        }
    }
}

// MARK: - Preview

struct TrainingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            TrainingView()
                .environment(DataManager.shared)
        }
    }
}
