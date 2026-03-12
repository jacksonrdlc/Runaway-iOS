//
//  CourseReconView.swift
//  Runaway iOS
//

import SwiftUI
import MapKit

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

// MARK: - Tactical Map View (3D terrain)

struct TacticalMapView: UIViewRepresentable {
    let course: RaceCourse
    @Binding var selectedMile: Double

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.overrideUserInterfaceStyle = .dark
        mapView.isPitchEnabled = true
        mapView.delegate = context.coordinator

        if #available(iOS 17.0, *) {
            mapView.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .realistic)
        }

        if let polylineStr = course.polyline {
            let coords = decodePolyline(polylineStr)
            if !coords.isEmpty {
                var mutableCoords = coords
                mapView.addOverlay(MKPolyline(coordinates: &mutableCoords, count: mutableCoords.count), level: .aboveRoads)
                let lats = coords.map(\.latitude), lons = coords.map(\.longitude)
                if let minLat = lats.min(), let maxLat = lats.max(),
                   let minLon = lons.min(), let maxLon = lons.max() {
                    let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
                    let span = MKCoordinateSpan(latitudeDelta: (maxLat - minLat) * 1.4, longitudeDelta: (maxLon - minLon) * 1.4)
                    mapView.setRegion(MKCoordinateRegion(center: center, span: span), animated: false)
                }
            }
        }

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            let renderer = MKPolylineRenderer(overlay: overlay)
            renderer.strokeColor = UIColor(AppTheme.Colors.accent)
            renderer.lineWidth = 4
            renderer.lineCap = .round
            return renderer
        }
    }

    private func decodePolyline(_ encoded: String) -> [CLLocationCoordinate2D] {
        var result: [CLLocationCoordinate2D] = []
        let chars = Array(encoded); var idx = 0, lat = 0, lng = 0
        while idx < chars.count {
            var shift = 0, res = 0, byte: Int
            repeat {
                if idx >= chars.count { break }
                byte = Int(chars[idx].asciiValue ?? 0) - 63
                res |= (byte & 0x1F) << shift; shift += 5; idx += 1
            } while byte >= 0x20
            lat += (res & 1) != 0 ? ~(res >> 1) : (res >> 1)
            shift = 0; res = 0
            repeat {
                if idx >= chars.count { break }
                byte = Int(chars[idx].asciiValue ?? 0) - 63
                res |= (byte & 0x1F) << shift; shift += 5; idx += 1
            } while byte >= 0x20
            lng += (res & 1) != 0 ? ~(res >> 1) : (res >> 1)
            result.append(CLLocationCoordinate2D(latitude: Double(lat) / 1e5, longitude: Double(lng) / 1e5))
        }
        return result
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
