//
//  MapSnapshotView.swift
//  RunawayUI
//
//  Created by Jack Rudelic on 7/29/24.
//

import SwiftUI
import MapboxMaps
import CoreLocation

struct MapSnapshotView: View {
    let location: CLLocationCoordinate2D
    let span: CLLocationDegrees
    let coordinates: [CLLocationCoordinate2D]?

    @State private var snapshotImage: UIImage? = nil

    var body: some View {
        GeometryReader { geometry in
            Group {
                if let image = snapshotImage {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(uiImage: image)
                            Spacer()
                        }
                        Spacer()
                    }
                }
                else {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .background(Color(UIColor.secondarySystemBackground))
                            Spacer()
                        }
                        Spacer()
                    }
                }
            }
            .onAppear {
                generateSnapshot(width: geometry.size.width, height: 400)
            }
        }
    }

    func generateSnapshot(width: CGFloat, height: CGFloat) {
        // Create a temporary MapView for rendering
        let mapInitOptions = MapInitOptions(styleURI: .standard)
        let mapView = MapView(frame: CGRect(x: 0, y: 0, width: width, height: height), mapInitOptions: mapInitOptions)

        // Calculate zoom from span (approximate conversion)
        let zoom = log2(360 / span) - 1

        // Set camera to center on location
        let cameraOptions = CameraOptions(
            center: location,
            zoom: zoom
        )
        mapView.mapboxMap.setCamera(to: cameraOptions)

        // Wait for style to load before adding route and capturing snapshot
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // Add route if coordinates are provided
            if let coordinates = self.coordinates, coordinates.count > 1 {
                // Create LineString from coordinates
                let lineString = LineString(coordinates)

                // Create GeoJSON source for route
                var routeSource = GeoJSONSource(id: "snapshot-route-source")
                routeSource.data = .geometry(.lineString(lineString))

                // Add route source to map
                try? mapView.mapboxMap.addSource(routeSource)

                // Create line layer for the route
                var lineLayer = LineLayer(id: "snapshot-route-layer", source: "snapshot-route-source")
                lineLayer.lineColor = .constant(StyleColor(UIColor(AppTheme.Colors.LightMode.accent)))
                lineLayer.lineWidth = .constant(6)
                lineLayer.lineCap = .constant(.round)
                lineLayer.lineJoin = .constant(.round)

                // Add route layer to map
                try? mapView.mapboxMap.addLayer(lineLayer)
            }

            // Wait a bit more for route to render
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Capture the map as an image
                let renderer = UIGraphicsImageRenderer(size: mapView.bounds.size)
                let snapshot = renderer.image { context in
                    mapView.drawHierarchy(in: mapView.bounds, afterScreenUpdates: true)
                }

                self.snapshotImage = snapshot
            }
        }
    }
}
