//
//  MapBoxBaseView.swift
//  Runaway iOS
//
//  MapBox base wrapper view with Standard Style and dark mode support
//  Foundation component for all MapBox map visualizations in the app
//

import SwiftUI
import MapboxMaps
import CoreLocation
import Combine

// MARK: - MapBox Configuration

/// MapBox style configuration
enum MapBoxStyle: String {
    case standard = "mapbox://styles/mapbox/standard"
    case dark = "mapbox://styles/mapbox/dark-v11"
    case light = "mapbox://styles/mapbox/light-v11"
    case outdoors = "mapbox://styles/mapbox/outdoors-v12"
    case satellite = "mapbox://styles/mapbox/satellite-streets-v12"

    var uri: String {
        return self.rawValue
    }
}

/// MapBox lighting preset for Standard Style
enum MapBoxLightingPreset: String {
    case day = "day"
    case dusk = "dusk"
    case dawn = "dawn"
    case night = "night"

    var configValue: String {
        return self.rawValue
    }
}

/// MapBox camera configuration
struct MapBoxCameraConfig: Equatable {
    let center: CLLocationCoordinate2D
    let zoom: Double
    let bearing: Double
    let pitch: Double

    static func == (lhs: MapBoxCameraConfig, rhs: MapBoxCameraConfig) -> Bool {
        return lhs.center.latitude == rhs.center.latitude &&
               lhs.center.longitude == rhs.center.longitude &&
               lhs.zoom == rhs.zoom &&
               lhs.bearing == rhs.bearing &&
               lhs.pitch == rhs.pitch
    }

    init(
        center: CLLocationCoordinate2D,
        zoom: Double = 15.0,
        bearing: Double = 0.0,
        pitch: Double = 0.0
    ) {
        self.center = center
        self.zoom = zoom
        self.bearing = bearing
        self.pitch = pitch
    }

    /// Default camera centered on San Francisco
    static let `default` = MapBoxCameraConfig(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        zoom: 12.0
    )
}

/// MapBox map configuration
struct MapBoxConfig: Equatable {
    let style: MapBoxStyle
    let lightingPreset: MapBoxLightingPreset
    let enable3DBuildings: Bool
    let enableGestures: Bool
    let showUserLocation: Bool
    let cameraConfig: MapBoxCameraConfig

    init(
        style: MapBoxStyle = .standard,
        lightingPreset: MapBoxLightingPreset = .night,
        enable3DBuildings: Bool = true,
        enableGestures: Bool = true,
        showUserLocation: Bool = true,
        cameraConfig: MapBoxCameraConfig = .default
    ) {
        self.style = style
        self.lightingPreset = lightingPreset
        self.enable3DBuildings = enable3DBuildings
        self.enableGestures = enableGestures
        self.showUserLocation = showUserLocation
        self.cameraConfig = cameraConfig
    }

    /// Default dark mode configuration
    static let darkMode = MapBoxConfig(
        style: .standard,
        lightingPreset: .night,
        enable3DBuildings: true,
        enableGestures: true,
        showUserLocation: true
    )

    /// Light mode configuration
    static let lightMode = MapBoxConfig(
        style: .standard,
        lightingPreset: .day,
        enable3DBuildings: true,
        enableGestures: true,
        showUserLocation: true
    )

    /// Recording mode (follow user with 3D)
    static let recording = MapBoxConfig(
        style: .standard,
        lightingPreset: .night,
        enable3DBuildings: true,
        enableGestures: true,
        showUserLocation: true
    )

    /// Detail view mode (static route display)
    static let detail = MapBoxConfig(
        style: .standard,
        lightingPreset: .dusk,
        enable3DBuildings: false,
        enableGestures: true,
        showUserLocation: false
    )
}

// MARK: - MapBox Base View

/// SwiftUI wrapper for MapBox MapView with Standard Style
struct MapBoxBaseView: UIViewRepresentable {
    // Configuration
    let config: MapBoxConfig

    // Bindings (optional)
    @Binding var cameraPosition: MapBoxCameraConfig?

    // Location updates (optional)
    let currentLocation: CLLocation?

    // Callbacks
    var onMapLoaded: (() -> Void)?
    var onCameraChanged: ((MapBoxCameraConfig) -> Void)?

    init(
        config: MapBoxConfig = .darkMode,
        cameraPosition: Binding<MapBoxCameraConfig?> = .constant(nil),
        currentLocation: CLLocation? = nil,
        onMapLoaded: (() -> Void)? = nil,
        onCameraChanged: ((MapBoxCameraConfig) -> Void)? = nil
    ) {
        self.config = config
        self._cameraPosition = cameraPosition
        self.currentLocation = currentLocation
        self.onMapLoaded = onMapLoaded
        self.onCameraChanged = onCameraChanged
    }

    func makeUIView(context: Context) -> MapboxMaps.MapView {
        // Set MapBox access token
        let accessToken = getMapBoxAccessToken()
        if !accessToken.isEmpty {
            MapboxOptions.accessToken = accessToken
        }

        // Create MapView
        let mapView = MapboxMaps.MapView(frame: .zero)

        // Load style
        try? mapView.mapboxMap.loadStyleURI(StyleURI(rawValue: config.style.uri)!)

        // Configure camera
        let cameraOptions = CameraOptions(
            center: config.cameraConfig.center,
            zoom: config.cameraConfig.zoom,
            bearing: config.cameraConfig.bearing,
            pitch: config.cameraConfig.pitch
        )
        mapView.mapboxMap.setCamera(to: cameraOptions)

        // Configure gestures
        if !config.enableGestures {
            mapView.gestures.options = GestureOptions()
        }

        // Setup user location (if enabled)
        if config.showUserLocation {
            setupUserLocation(mapView: mapView)
        }

        // Listen for map loaded event
        mapView.mapboxMap.onMapLoaded.observeNext { _ in
            DispatchQueue.main.async {
                // Configure Standard Style lighting
                self.configureStandardStyle(mapView: mapView)

                // Enable 3D buildings if requested
                if self.config.enable3DBuildings {
                    self.enable3DBuildings(mapView: mapView)
                }

                // Call loaded callback
                self.onMapLoaded?()

                #if DEBUG
                print("🗺️ MapBox: Map loaded successfully")
                print("   Style: \(self.config.style.rawValue)")
                print("   Lighting: \(self.config.lightingPreset.rawValue)")
                print("   3D Buildings: \(self.config.enable3DBuildings)")
                #endif
            }
        }.store(in: &context.coordinator.cancelables)

        // Listen for camera changes
        mapView.mapboxMap.onCameraChanged.observeNext { _ in
            let camera = mapView.mapboxMap.cameraState
            let cameraConfig = MapBoxCameraConfig(
                center: camera.center,
                zoom: camera.zoom,
                bearing: camera.bearing,
                pitch: camera.pitch
            )
            self.onCameraChanged?(cameraConfig)
        }.store(in: &context.coordinator.cancelables)

        return mapView
    }

    func updateUIView(_ mapView: MapboxMaps.MapView, context: Context) {
        // Update camera position if binding changed
        if let newPosition = cameraPosition {
            let cameraOptions = CameraOptions(
                center: newPosition.center,
                zoom: newPosition.zoom,
                bearing: newPosition.bearing,
                pitch: newPosition.pitch
            )
            mapView.mapboxMap.setCamera(to: cameraOptions)
        }

        // Update user location if changed
        if config.showUserLocation, let location = currentLocation {
            updateUserLocation(mapView: mapView, location: location, context: context)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - Coordinator

    class Coordinator {
        var cancelables = Set<AnyCancellable>()
        var hasCenteredOnUser = false
    }

    // MARK: - Private Methods

    private func getMapBoxAccessToken() -> String {
        // Try to get from environment variable first
        if let token = ProcessInfo.processInfo.environment["MAPBOX_ACCESS_TOKEN"] {
            return token
        }

        // Try to get from Info.plist
        if let token = Bundle.main.object(forInfoDictionaryKey: "MBXAccessToken") as? String {
            return token
        }

        #if DEBUG
        print("⚠️ MapBox: Access token not found in environment or Info.plist")
        #endif

        return ""
    }

    private func setupUserLocation(mapView: MapboxMaps.MapView) {
        // Configure location puck (user location indicator)
        let puckConfiguration = Puck2DConfiguration.makeDefault(showBearing: true)
        mapView.location.options.puckType = .puck2D(puckConfiguration)
        mapView.location.options.puckBearingEnabled = true
    }

    private func updateUserLocation(mapView: MapboxMaps.MapView, location: CLLocation, context: Context) {
        // Center on user's location the first time we get it (to replace default San Francisco)
        if !context.coordinator.hasCenteredOnUser {
            context.coordinator.hasCenteredOnUser = true
            let cameraOptions = CameraOptions(
                center: location.coordinate,
                zoom: 15.0, // Good zoom for pre-recording view
                bearing: mapView.mapboxMap.cameraState.bearing,
                pitch: 0.0
            )
            mapView.camera.fly(to: cameraOptions, duration: 0.5)
            #if DEBUG
            print("📍 MapBox: Centered on user location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            #endif
            return
        }

        // Update camera to follow user (if in recording mode)
        if config == .recording {
            let cameraOptions = CameraOptions(
                center: location.coordinate,
                zoom: 17.0, // Closer zoom for recording
                bearing: mapView.mapboxMap.cameraState.bearing,
                pitch: 45.0 // 3D perspective for recording
            )
            mapView.mapboxMap.setCamera(to: cameraOptions)
        }
    }

    private func configureStandardStyle(mapView: MapboxMaps.MapView) {
        // Configure Standard Style with lighting preset
        do {
            try mapView.mapboxMap.setStyleImportConfigProperty(
                for: "basemap",
                config: "lightPreset",
                value: config.lightingPreset.configValue
            )

            #if DEBUG
            print("✅ MapBox: Lighting preset set to \(config.lightingPreset.rawValue)")
            #endif
        } catch {
            #if DEBUG
            print("❌ MapBox: Failed to set lighting preset: \(error.localizedDescription)")
            #endif
        }
    }

    private func enable3DBuildings(mapView: MapboxMaps.MapView) {
        // Enable 3D building extrusions
        do {
            // Check if building layer exists in the style
            if mapView.mapboxMap.layerExists(withId: "building-extrusion") {
                try mapView.mapboxMap.updateLayer(
                    withId: "building-extrusion",
                    type: FillExtrusionLayer.self
                ) { layer in
                    layer.visibility = .constant(.visible)
                }

                #if DEBUG
                print("✅ MapBox: 3D buildings enabled")
                #endif
            }
        } catch {
            #if DEBUG
            print("❌ MapBox: Failed to enable 3D buildings: \(error.localizedDescription)")
            #endif
        }
    }
}

// MARK: - Preview Support

#if DEBUG
struct MapBoxBaseView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 0) {
            // Dark mode map
            MapBoxBaseView(
                config: .darkMode,
                currentLocation: CLLocation(
                    latitude: 37.7749,
                    longitude: -122.4194
                )
            )
            .frame(height: 300)

            Text("Dark Mode - Night Preset")
                .font(.caption)
                .padding()

            // Light mode map
            MapBoxBaseView(
                config: .lightMode,
                currentLocation: CLLocation(
                    latitude: 37.7749,
                    longitude: -122.4194
                )
            )
            .frame(height: 300)

            Text("Light Mode - Day Preset")
                .font(.caption)
                .padding()
        }
        .background(Color.black)
    }
}
#endif
