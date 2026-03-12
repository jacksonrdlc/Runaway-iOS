//
//  MapSnapshotView.swift
//  Runaway iOS
//

import SwiftUI
import MapKit
import CoreLocation

struct MapSnapshotView: View {
    let location: CLLocationCoordinate2D
    let span: CLLocationDegrees
    let coordinates: [CLLocationCoordinate2D]?

    @State private var snapshotImage: UIImage?

    var body: some View {
        GeometryReader { geometry in
            Group {
                if let image = snapshotImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                            Spacer()
                        }
                        Spacer()
                    }
                }
            }
            .onAppear {
                generateSnapshot(size: CGSize(width: geometry.size.width, height: 400))
            }
        }
    }

    private func generateSnapshot(size: CGSize) {
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: location,
            span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
        )
        options.size = size
        MKMapSnapshotter(options: options).start(with: .main) { snapshot, error in
            guard let snapshot else { return }

            let image: UIImage
            if let coords = coordinates, coords.count > 1 {
                image = drawRoute(on: snapshot, coordinates: coords)
            } else {
                image = snapshot.image
            }

            DispatchQueue.main.async { snapshotImage = image }
        }
    }

    private func drawRoute(on snapshot: MKMapSnapshotter.Snapshot, coordinates: [CLLocationCoordinate2D]) -> UIImage {
        UIGraphicsImageRenderer(size: snapshot.image.size).image { _ in
            snapshot.image.draw(at: .zero)

            let path = UIBezierPath()
            let points = coordinates.map { snapshot.point(for: $0) }
            guard let first = points.first else { return }
            path.move(to: first)
            points.dropFirst().forEach { path.addLine(to: $0) }

            UIColor(AppTheme.Colors.accent).setStroke()
            path.lineWidth = 6
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.stroke()
        }
    }
}
