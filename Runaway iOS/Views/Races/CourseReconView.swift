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
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(AppTheme.Colors.accent)
                        Text("Analyzing Terrain...")
                            .font(AppTheme.Typography.body)
                            .foregroundColor(AppTheme.Colors.DarkMode.textSecondary)
                    }
                } else if let course = course {
                    VStack(spacing: 0) {
                        TacticalMapView(course: course, selectedMile: $selectedMile)
                            .frame(height: 350)
                            .overlay(alignment: .topTrailing) {
                                mileBadge
                            }

                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {
                                ElevationChart(course: course, selectedMile: $selectedMile)
                                    .frame(height: 140)
                                    .padding(.top)

                                sectionHeader("TWIN STRATEGY")

                                if let insights = course.tacticalInsights, !insights.isEmpty {
                                    ForEach(insights) { insight in
                                        TacticalInsightRow(insight: insight)
                                    }
                                } else {
                                    emptyInsightsCard
                                }
                            }
                            .padding(.bottom, 40)
                        }
                    }
                } else {
                    noCourseState
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
        .task { await loadCourse() }
    }

    private var mileBadge: some View {
        Text("Mile " + String(format: "%.1f", selectedMile))
            .font(.system(size: 14, weight: .bold, design: .monospaced))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.black.opacity(0.75))
            .foregroundColor(.white)
            .cornerRadius(8)
            .padding()
    }

    private var emptyInsightsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(AppTheme.Colors.accent)
                Text("Analyzing terrain...")
                    .font(AppTheme.Typography.body)
            }
            Text("I'm identifying technical cruxes based on the elevation profile.")
                .font(.system(size: 13))
                .foregroundColor(AppTheme.Colors.DarkMode.textSecondary)
        }
        .padding()
        .background(AppTheme.Colors.DarkMode.cardBackground)
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(AppTheme.Colors.DarkMode.textSecondary)
            .tracking(1.5)
            .padding(.horizontal)
    }

    private var noCourseState: some View {
        VStack(spacing: 20) {
            Image(systemName: "map.fill")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.Colors.accent.opacity(0.5))
            Text("No Course Data Available")
                .font(AppTheme.Typography.headline)
            Text("We couldn't find a spatial map for this race yet.")
                .multilineTextAlignment(.center)
                .foregroundColor(AppTheme.Colors.DarkMode.textSecondary)
                .padding(.horizontal, 40)
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

struct TacticalMapView: UIViewRepresentable {
    let course: RaceCourse
    @Binding var selectedMile: Double

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.overrideUserInterfaceStyle = .dark
        mapView.isPitchEnabled = true
        mapView.showsBuildings = true
        mapView.delegate = context.coordinator
        
        if #available(iOS 17.0, *) {
            mapView.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .realistic)
        }

        if let poly = course.polyline {
            let coords = decodePolyline(poly)
            if !coords.isEmpty {
                // Filter out any points that are obviously out of bounds (sanity check for St. Louis area)
                let lats = coords.map { $0.latitude }
                let lons = coords.map { $0.longitude }
                let minLat = lats.min()!, maxLat = lats.max()!
                let minLon = lons.min()!, maxLon = lons.max()!
                
                let centerLat = (minLat + maxLat) / 2
                let centerLon = (minLon + maxLon) / 2
                
                // If a point is more than 0.5 degrees (~35 miles) from center, it's likely a decoding artifact
                let filteredCoords = coords.filter { 
                    abs($0.latitude - centerLat) < 0.5 && abs($0.longitude - centerLon) < 0.5 
                }
                
                if !filteredCoords.isEmpty {
                    var mutableCoords = filteredCoords
                    let overlay = MKPolyline(coordinates: &mutableCoords, count: filteredCoords.count)
                    mapView.addOverlay(overlay)
                    
                    let fLats = filteredCoords.map { $0.latitude }
                    let fLons = filteredCoords.map { $0.longitude }
                    let region = MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: (fLats.min()! + fLats.max()!) / 2, longitude: (fLons.min()! + fLons.max()!) / 2),
                        span: MKCoordinateSpan(latitudeDelta: (fLats.max()! - fLats.min()!) * 1.4, longitudeDelta: (fLons.max()! - fLons.min()!) * 1.4)
                    )
                    mapView.setRegion(region, animated: false)
                    
                    let camera = MKMapCamera(lookingAtCenter: region.center, fromDistance: 4500, pitch: 65, heading: 0)
                    mapView.setCamera(camera, animated: true)
                }
            }
        }
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {}
    
    func makeCoordinator() -> Coordinator { Coordinator() }
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(AppTheme.Colors.accent)
                renderer.lineWidth = 4
                renderer.lineCap = .round
                return renderer
            }
            return MKOverlayRenderer()
        }
    }

    private func decodePolyline(_ encoded: String) -> [CLLocationCoordinate2D] {
        let bytes = encoded.utf8.map { Int8($0) - 63 }
        var index = 0
        var lat: Int32 = 0
        var lng: Int32 = 0
        var coordinates: [CLLocationCoordinate2D] = []

        while index < bytes.count {
            func decode() -> Int32? {
                var res: UInt32 = 0
                var shift: UInt32 = 0
                var byte: Int8 = 0
                repeat {
                    if index >= bytes.count { return nil }
                    byte = bytes[index]
                    index += 1
                    res |= UInt32(byte & 0x1F) << shift
                    shift += 5
                } while byte >= 0x20
                return (res & 1) != 0 ? ~Int32(res >> 1) : Int32(res >> 1)
            }
            guard let dLat = decode(), let dLng = decode() else { break }
            lat += dLat
            lng += dLng
            coordinates.append(CLLocationCoordinate2D(latitude: Double(lat) * 1e-5, longitude: Double(lng) * 1e-5))
        }
        return coordinates
    }
}

struct ElevationChart: View {
    let course: RaceCourse
    @Binding var selectedMile: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ELEVATION PROFILE (FT)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(AppTheme.Colors.DarkMode.textSecondary)
                .padding(.leading)

            if let data = course.elevationData, !data.isEmpty {
                let elevations = data.map { $0.elevation }
                let minEle = elevations.min() ?? 0
                let maxEle = elevations.max() ?? 100
                let range = max(1, maxEle - minEle)
                
                GeometryReader { geo in
                    HStack(alignment: .bottom, spacing: geo.size.width / CGFloat(data.count) * 0.1) {
                        ForEach(0..<data.count, id: \.self) { i in
                            let point = data[i]
                            // Convert meters to feet for display
                            let normalizedHeight = CGFloat((point.elevation - minEle) / range)
                            
                            Rectangle()
                                .fill(AppTheme.Colors.accent.opacity(0.6))
                                .frame(height: max(2, normalizedHeight * geo.size.height))
                                .onTapGesture {
                                    selectedMile = point.distance / 1609.34
                                }
                        }
                    }
                }
                .padding(.horizontal)
            } else {
                Text("Elevation data unavailable")
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}

struct TacticalInsightRow: View {
    let insight: TacticalInsight
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack {
                Text("Mile")
                    .font(.system(size: 10, weight: .bold))
                Text(String(format: "%.1f", insight.mile))
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
