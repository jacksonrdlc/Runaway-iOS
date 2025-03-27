//
//  CardView.swift
//  RunawayUI
//
//  Created by Jack Rudelic on 7/22/24.
//

import SwiftUI
//import MapKit
import Polyline
@_spi(Experimental) import MapboxMaps

// struct CardView: View {

//     var activity: Activity
//     var date: String! {
//         let dateFormatter = DateFormatter()
//         dateFormatter.dateFormat = "EEEE, MMM d, yyyy, hh:mm a"
//         return dateFormatter.string(from: Date(timeIntervalSinceReferenceDate: activity.start_date!))
//     }
//     var type: String!
//     @State var image: UIImage?

//     var body: some View {
//         VStack{
//             HStack{
//                 VStack (alignment: .leading){
//                     Text(activity.name!)
//                         .foregroundColor(Color.white)
//                         .font(.title2)
//                         .fontWeight(.bold)
//                         .padding(
//                             EdgeInsets(
//                                 top: 16,
//                                 leading: 16,
//                                 bottom: 8,
//                                 trailing: 8
//                             )
//                         )
//                 }
//                 Spacer()
//             }
// //            if type != "weightTraining" && type != "yoga" && stravaMap?.summaryPolyline != "" {
// //                if stravaMap != nil {
// //                    let coordinates: [CLLocationCoordinate2D] = Polyline(encodedPolyline: (stravaMap?.summaryPolyline)!).coordinates!
// //                    let mapOverview: Viewport = .overview(geometry: Polygon(center: coordinates[coordinates.count/2] , radius: 2500, vertices: 64))
// //                    VStack(spacing: 10) {
// //                        MapReader { proxy in
// //                            Map(initialViewport: mapOverview){
// //                                let routeFeature = UUID().uuidString
// //                                let routeLayer = UUID().uuidString
// //                                PolylineAnnotationGroup {
// //                                                PolylineAnnotation(id: routeFeature, lineCoordinates: coordinates)
// //                                                    .lineColor("#57A9FB")
// //                                                    .lineBorderColor("#327AC2")
// //                                                    .lineWidth(4)
// //                                                    .lineBorderWidth(2)
// //                                            }
// //                                            .layerId(routeLayer) // Specify id for underlying line layer.
// //                                            .lineCap(.round)
// //                                            .slot("middle")
// //                            }
// //                                .gestureOptions(GestureOptions.init(panEnabled: false, pinchEnabled: false))
// //                                .mapStyle(.outdoors)
// //                                .onMapIdle { _ in image = proxy.captureSnapshot() }
// //                                .frame(height: 200)
// //                        }
// //                    }
// //
// //                }
// //            }
//             HStack{
//                 VStack (alignment: .leading){
//                     Text(activity.type! + "  |  " + date + "  |  ")
//                         .foregroundColor(Color.white)
//                         .font(.subheadline)
// //                        .fontWeight(bold)
//                         .padding(
//                             EdgeInsets(
//                                 top: 8,
//                                 leading: 16,
//                                 bottom: 16,
//                                 trailing: 8
//                             )
//                         )
//                 }
//                 Spacer()
//             }
//         }
//         .background(Color.gray.opacity(0.2))
//         .cornerRadiusWithBorder(radius: 4, borderLineWidth: 0)
//     }
// }

// Create simplified card view
struct CardView: View {
    let activity: LocalActivity
//    var type: String!
    @State var image: UIImage?
    
    var body: some View {
        VStack(alignment: .leading) {
//            if type != "weightTraining" && type != "yoga" && stravaMap?.summaryPolyline != "" {
//                if stravaMap != nil {
//                    let coordinates: [CLLocationCoordinate2D] = Polyline(encodedPolyline: (stravaMap?.summaryPolyline)!).coordinates!
//                    let mapOverview: Viewport = .overview(geometry: Polygon(center: coordinates[coordinates.count/2] , radius: 2500, vertices: 64))
//                    VStack(spacing: 10) {
//                        MapReader { proxy in
//                            Map(initialViewport: mapOverview){
//                                let routeFeature = UUID().uuidString
//                                let routeLayer = UUID().uuidString
//                                PolylineAnnotationGroup {
//                                    PolylineAnnotation(id: routeFeature, lineCoordinates: coordinates)
//                                        .lineColor("#57A9FB")
//                                        .lineBorderColor("#327AC2")
//                                        .lineWidth(4)
//                                        .lineBorderWidth(2)
//                                }
//                                .layerId(routeLayer) // Specify id for underlying line layer.
//                                .lineCap(.round)
//                                .slot("middle")
//                            }
//                            .gestureOptions(GestureOptions.init(panEnabled: false, pinchEnabled: false))
//                            .mapStyle(.outdoors)
//                            .onMapIdle { _ in image = proxy.captureSnapshot() }
//                            .frame(height: 200)
//                        }
//                    }
//                    
//                }
//            }
            Text(activity.name ?? "Unknown Activity")
                .font(.headline)
            
            HStack {
                Text(activity.type ?? "Unknown Type")
                    .font(.subheadline)
                
                Spacer()
                
                if let distance = activity.distance {
                    Text(String(format: "%.2f km", distance * 0.001))
                        .font(.subheadline)
                }
                
                if let time = activity.elapsed_time {
                    Text(formatTime(seconds: time))
                        .font(.subheadline)
                }
            }
        }
        .padding()
    }
    
    private func formatTime(seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct SnapshotView: View {
    var snapshot: UIImage?
    
    var body: some View {
        if let snapshot {
            Image(uiImage: snapshot)
        } else {
            EmptyView()
        }
    }
}

fileprivate struct ModifierCornerRadiusWithBorder: ViewModifier {
    var radius: CGFloat
    var borderLineWidth: CGFloat = 1
    var borderColor: Color = .gray
    var antialiased: Bool = true
    
    func body(content: Content) -> some View {
        content
            .cornerRadius(self.radius, antialiased: self.antialiased)
            .overlay(
                RoundedRectangle(cornerRadius: self.radius)
                    .inset(by: self.borderLineWidth)
                    .strokeBorder(self.borderColor, lineWidth: self.borderLineWidth, antialiased: self.antialiased)
            )
    }
}

extension View {
    func cornerRadiusWithBorder(radius: CGFloat, borderLineWidth: CGFloat = 1, borderColor: Color = .gray, antialiased: Bool = true) -> some View {
        modifier(ModifierCornerRadiusWithBorder(radius: radius, borderLineWidth: borderLineWidth, borderColor: borderColor, antialiased: antialiased))
    }
}
