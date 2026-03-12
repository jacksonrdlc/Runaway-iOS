//
//  MapBaseView.swift
//  Runaway iOS
//
//  MapKit base wrapper view with dark mode support
//  Foundation component for all map visualizations in the app
//

import SwiftUI
import MapKit
import CoreLocation

// MARK: - Map Configuration

/// Map camera configuration
struct MapCameraConfig: Equatable {
    let center: CLLocationCoordinate2D
    let span: MKCoordinateSpan
    let pitch: CGFloat
    let heading: CLLocationDirection

    static func == (lhs: MapCameraConfig, rhs: MapCameraConfig) -> Bool {
        lhs.center.latitude == rhs.center.latitude &&
        lhs.center.longitude == rhs.center.longitude &&
        lhs.span.latitudeDelta == rhs.span.latitudeDelta &&
        lhs.pitch == rhs.pitch &&
        lhs.heading == rhs.heading
    }

    init(
        center: CLLocationCoordinate2D,
        spanDelta: CLLocationDegrees = 0.05,
        pitch: CGFloat = 0,
        heading: CLLocationDirection = 0
    ) {
        self.center = center
        self.span = MKCoordinateSpan(latitudeDelta: spanDelta, longitudeDelta: spanDelta)
        self.pitch = pitch
        self.heading = heading
    }

    static let `default` = MapCameraConfig(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    )
}

/// Map configuration
struct MapConfig: Equatable {
    let enableGestures: Bool
    let showUserLocation: Bool
    let show3DTerrain: Bool
    let cameraConfig: MapCameraConfig

    init(
        enableGestures: Bool = true,
        showUserLocation: Bool = true,
        show3DTerrain: Bool = false,
        cameraConfig: MapCameraConfig = .default
    ) {
        self.enableGestures = enableGestures
        self.showUserLocation = showUserLocation
        self.show3DTerrain = show3DTerrain
        self.cameraConfig = cameraConfig
    }

    static let darkMode = MapConfig(enableGestures: true, showUserLocation: true)
    static let recording = MapConfig(enableGestures: true, showUserLocation: true)
    static let detail = MapConfig(enableGestures: true, showUserLocation: false)
}

// MARK: - MapKit Base View

/// SwiftUI wrapper for MKMapView with dark mode and optional 3D terrain
struct MapBaseView: UIViewRepresentable {
    let config: MapConfig
    @Binding var cameraPosition: MapCameraConfig?
    let currentLocation: CLLocation?
    var onMapLoaded: (() -> Void)?
    var onCameraChanged: ((MapCameraConfig) -> Void)?

    init(
        config: MapConfig = .darkMode,
        cameraPosition: Binding<MapCameraConfig?> = .constant(nil),
        currentLocation: CLLocation? = nil,
        onMapLoaded: (() -> Void)? = nil,
        onCameraChanged: ((MapCameraConfig) -> Void)? = nil
    ) {
        self.config = config
        self._cameraPosition = cameraPosition
        self.currentLocation = currentLocation
        self.onMapLoaded = onMapLoaded
        self.onCameraChanged = onCameraChanged
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.overrideUserInterfaceStyle = .dark
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = config.showUserLocation
        mapView.isZoomEnabled = config.enableGestures
        mapView.isScrollEnabled = config.enableGestures
        mapView.isRotateEnabled = config.enableGestures
        mapView.isPitchEnabled = false

        if #available(iOS 17.0, *), config.show3DTerrain {
            mapView.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .realistic)
        }

        let region = MKCoordinateRegion(
            center: config.cameraConfig.center,
            span: config.cameraConfig.span
        )
        mapView.setRegion(region, animated: false)

        DispatchQueue.main.async { self.onMapLoaded?() }

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        if let newPosition = cameraPosition {
            let region = MKCoordinateRegion(center: newPosition.center, span: newPosition.span)
            mapView.setRegion(region, animated: true)
        }
        if config.showUserLocation, let location = currentLocation, !context.coordinator.hasCenteredOnUser {
            context.coordinator.hasCenteredOnUser = true
            let region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            mapView.setRegion(region, animated: true)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(owner: self) }

    class Coordinator: NSObject, MKMapViewDelegate {
        var hasCenteredOnUser = false
        let owner: MapBaseView

        init(owner: MapBaseView) { self.owner = owner }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            let config = MapCameraConfig(
                center: mapView.region.center,
                spanDelta: mapView.region.span.latitudeDelta
            )
            owner.onCameraChanged?(config)
        }
    }
}
