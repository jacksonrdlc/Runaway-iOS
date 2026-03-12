//
//  CourseReconView.swift
//  Runaway iOS
//

import SwiftUI
import MapboxMaps

struct CourseReconView: View {
    let race: AthleteRace
    @State private var course: RaceCourse?
    @State private var isLoading = true
    @State private var selectedMile: Double = 0
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.Colors.DarkMode.background.ignoresSafeArea()
                
                if isLoading {
                    ProgressView("Analyzing Course Terrain...")
                        .tint(AppTheme.Colors.accent)
                } else if let course = course {
                    VStack(spacing: 0) {
                        // 3D Map Flyover
                        TacticalMapView(course: course, selectedMile: $selectedMile)
                            .frame(height: 350)
                            .overlay(alignment: .topTrailing) {
                                Text("Mile \(String(format: "%.1f", selectedMile))")
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .padding(8)
                                    .background(.black.opacity(0.6))
                                    .cornerRadius(8)
                                    .padding()
                            }

                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                // Elevation Profile
                                ElevationChart(course: course, selectedMile: $selectedMile)
                                    .frame(height: 120)
                                    .padding(.top)

                                // Tactical Insights
                                Text("TWIN STRATEGY")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(AppTheme.Colors.DarkMode.textSecondary)
                                    .tracking(1.5)
                                    .padding(.horizontal)

                                if let insights = course.tacticalInsights {
                                    ForEach(insights) { insight in
                                        TacticalInsightRow(insight: insight)
                                    }
                                } else {
                                    Text("Analyzing elevation for tactical cruxes...")
                                        .font(AppTheme.Typography.body)
                                        .foregroundColor(AppTheme.Colors.DarkMode.textSecondary)
                                        .padding(.horizontal)
                                }
                            }
                            .padding(.bottom, 40)
                        }
                    }
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 60))
                            .foregroundColor(AppTheme.Colors.accent.opacity(0.5))
                        Text("No Course Data Available")
                            .font(AppTheme.Typography.headline)
                        Text("We couldn't find a spatial map for this race yet. You can upload a GPX file via the web platform to enable Course Recon.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(AppTheme.Colors.DarkMode.textSecondary)
                            .padding(.horizontal, 40)
                    }
                }
            }
            .navigationTitle(race.raceName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            await loadCourse()
        }
    }

    private func loadCourse() async {
        do {
            course = try await CourseReconService.shared.fetchCourse(
                raceId: race.runsignupRaceId, 
                eventId: race.eventId ?? 0
            )
        } catch {
            print("❌ CourseRecon: Failed to load: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Tactical Map View (3D)

struct TacticalMapView: UIViewRepresentable {
    let course: RaceCourse
    @Binding var selectedMile: Double

    func makeUIView(context: Context) -> MapView {
        let options = MapInitOptions(
            cameraOptions: CameraOptions(zoom: 12),
            styleURI: .dark
        )
        let mapView = MapView(frame: .zero, mapInitOptions: options)
        
        // Enable Terrain
        try? mapView.mapboxMap.setTerrain(Terrain(sourceId: "mapbox-dem"))
        
        // Add DEM source
        var demSource = RasterDemSource(id: "mapbox-dem")
        demSource.url = "mapbox://mapbox.mapbox-terrain-dem-v1"
        demSource.tileSize = 512
        demSource.maxzoom = 14
        try? mapView.mapboxMap.addSource(demSource)
        
        return mapView
    }

    func updateUIView(_ uiView: MapView, context: Context) {
        // Here we would update the camera position based on selectedMile
    }
}

// MARK: - Components

struct ElevationChart: View {
    let course: RaceCourse
    @Binding var selectedMile: Double

    var body: some View {
        Rectangle()
            .fill(AppTheme.Colors.DarkMode.cardBackground)
            .overlay(Text("Elevation Chart Placeholder").font(.caption))
            .cornerRadius(12)
            .padding(.horizontal)
    }
}

struct TacticalInsightRow: View {
    let insight: TacticalInsight

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack {
                Text("Mile")
                    .font(.system(size: 10, weight: .bold))
                Text("\(String(format: "%.1f", insight.mile))")
                    .font(.system(size: 16, weight: .heavy, design: .monospaced))
            }
            .foregroundColor(AppTheme.Colors.accent)
            .frame(width: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text(insight.description)
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.DarkMode.textPrimary)
            }
        }
        .padding()
        .background(AppTheme.Colors.DarkMode.cardBackground)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.07), lineWidth: 1))
        .padding(.horizontal)
    }
}
