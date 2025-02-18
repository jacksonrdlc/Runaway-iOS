//
//  MapSnapshotView.swift
//  RunawayUI
//
//  Created by Jack Rudelic on 7/29/24.
//

import SwiftUI
import MapKit

struct MapSnapshotView: View {
    let location: CLLocationCoordinate2D
    let span: CLLocationDegrees
    let coordinates: [CLLocationCoordinate2D]?
    
//    @EnvironmentObject var preferences: PreferencesStorage
    
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
        
        let region = MKCoordinateRegion(
            center: self.location,
            span: MKCoordinateSpan(
                latitudeDelta: self.span,
                longitudeDelta: self.span
            )
        )
        
        // Map options
        let mapOptions = MKMapSnapshotter.Options()
        mapOptions.region = region
        mapOptions.size = CGSize(width: width, height: height)
        mapOptions.showsBuildings = true
        
        // Create the snapshotter and run it
        let snapshotter = MKMapSnapshotter(options: mapOptions)
        snapshotter.start { (snapshotOrNil, errorOrNil) in
            if let error = errorOrNil {
                print(error)
                return
            }
            if let snapshot = snapshotOrNil {
                let finalImage = UIGraphicsImageRenderer(size: snapshot.image.size).image { _ in
                    
                    snapshot.image.draw(at: .zero)
                    
                    guard let coordinates = self.coordinates, coordinates.count > 1 else { return }
                    
                    // Convert the [CLLocationCoordinate2D] into a [CGPoint]
                    let points = coordinates.map { coordinate in
                        snapshot.point(for: coordinate)
                    }
                    
                    let path = UIBezierPath()
                    path.move(to: points[0])
                    
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                    
                    path.lineWidth = 6
//                    UserPreferences.convertColourChoiceToUIColor(colour: preferences.storedPreferences[0].colourChoiceConverted).setStroke()
                    path.stroke()
                }
                self.snapshotImage = finalImage
            }
        }
    }
}
