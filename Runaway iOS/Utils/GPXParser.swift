import Foundation
import CoreLocation

class GPXParser: NSObject, XMLParserDelegate {
    private var points: [CLLocation] = []
    private var currentPoint: [String: String] = [:]
    private var currentContent: String = ""
    
    func parse(data: Data) -> [CLLocation] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return points
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentContent = ""
        if elementName == "trkpt" {
            if let lat = attributeDict["lat"], let lon = attributeDict["lon"] {
                currentPoint["lat"] = lat
                currentPoint["lon"] = lon
            }
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentContent += string
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "ele" {
            currentPoint["ele"] = currentContent.trimmingCharacters(in: .whitespacesAndNewlines)
        } else if elementName == "trkpt" {
            if let latS = currentPoint["lat"], let lonS = currentPoint["lon"],
               let lat = Double(latS), let lon = Double(lonS) {
                let ele = Double(currentPoint["ele"] ?? "0") ?? 0
                let location = CLLocation(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon), 
                                         altitude: ele, horizontalAccuracy: 0, verticalAccuracy: 0, timestamp: Date())
                points.append(location)
            }
            currentPoint = [:]
        }
    }
}

extension Array where Element == CLLocation {
    func calculateElevationData() -> [CourseElevationPoint] {
        var result: [CourseElevationPoint] = []
        var totalDistance: Double = 0
        
        for i in 0..<self.count {
            if i > 0 {
                totalDistance += self[i].distance(from: self[i-1])
            }
            
            var grade: Double = 0
            if i > 0 {
                let d = self[i].distance(from: self[i-1])
                if d > 0 {
                    grade = (self[i].altitude - self[i-1].altitude) / d
                }
            }
            
            result.append(CourseElevationPoint(
                distance: totalDistance,
                elevation: self[i].altitude,
                grade: grade * 100
            ))
        }
        return result
    }
}
