//
//  Upload.swift
//  RunawayUI
//
//  Created by Jack Rudelic on 7/17/24.
//

import Foundation
import SwiftUI
import CoreGPX

extension Date {
    func withAddedMinutes(minutes: Double) -> Date {
         addingTimeInterval(minutes * 60)
    }

    func withAddedHours(hours: Double) -> Date {
         withAddedMinutes(minutes: hours * 60)
    }
}

struct UploadView: View {
    @State var selectedActivity: ActivityType = .run
    @State var buttonName: String = "Upload"
    @State var title: String = ""
    //    @State var isGolf: Bool = false
    @State var email: String = ""
    @State var receiveEmails: Bool = false
    @State var selectedGolfOption = "Practice"
    var golfOptions = ["Practice", "9 Holes", "18 Holes"]
    @State var volumeSliderValue: Double = 0
    @State var date = Date()
    @State var uploadID: Int?
    @State var activityID: Int?
    
    var body: some View {
        NavigationView {
            Form {
                TextField("", text: $title, prompt: Text("Activity Name"))
                
                Picker("Activity", selection: $selectedActivity) {
                    ForEach(ActivityType.allCases, id: \.self) { option in
                        Text(String(describing: option))
                        
                    }
                }
                
                if selectedActivity == ActivityType.golf {
                    Picker(selection: $selectedGolfOption, label: Text("Golf Options")) {
                        ForEach(0 ..< golfOptions.count, id: \.self) {
                            Text(self.golfOptions[$0])
                        }
                    }
                }
                
                DatePicker("Pick a Date", selection: $date)
                
                Button(action: {
                    uploadActivity()
                }
                ) {
                    Text(buttonName)
                }
            }
            .navigationTitle("Upload Activity")
        }
    }
    func uploadActivity(){
        if selectedActivity == ActivityType.golf{
            switch selectedGolfOption {
            case "Practice":
                uploadGolfPractice()
            case "9 Holes":
                uploadGolfPractice()
            case "18 Holes":
                uploadGolfPractice()
            default:
                uploadGolfPractice()
                
            }
        }
    }
    
    func uploadGolfPractice() {
        buttonName = "Uploading..."
        
        guard let filePath = outputPracticeAsFile() else { return }
        guard let fileData = try? Data(contentsOf: filePath) else { return }
        
        let today = Date.now
        let formatter = DateFormatter()
        let dateString: String = formatter.string(from: today)
        
        let params = UploadData(activityType: .golf, name: "Golf: Practice", description: "Practice at Family Golf", private: true, trainer: nil, externalId: nil, startDate: dateString, elapsedTime: 2700, dataType: .gpx, file: fileData)
        
        StravaClient.sharedInstance.upload(Router.uploadFile(upload: params), upload: params, result: {(status: UploadStatus?) in
            if let status = status, let uploadID = status.id {
                // At this point only status.id will be valid. All other properties will be nil.
                self.uploadID = uploadID
                buttonName = "Processing new activity"
            }}, failure: { (error: NSError) in
                debugPrint(error)
                self.doAlert(title: "Strava Error", message: error.localizedDescription)
            })
    }
    
    func outputPracticeAsFile() -> URL?  {
        let waypoints = [GPXWaypoint]()
        let root = GPXRoot(creator: "Runaway")
        let timeNow = Date.now
        let trackpoint1 = GPXTrackPoint(latitude: 38.559401, longitude: -90.457009)
        trackpoint1.time = timeNow
        let trackpoint2 = GPXTrackPoint(latitude: 38.559416, longitude: -90.456714)
        trackpoint2.time = timeNow.withAddedMinutes(minutes: 15)
        let trackpoint3 = GPXTrackPoint(latitude: 38.559431, longitude: -90.455940)
        trackpoint3.time = timeNow.withAddedMinutes(minutes: 45)
        let track = GPXTrack()
        let trackseg = GPXTrackSegment()
        
        trackseg.add(trackpoints: [trackpoint1, trackpoint2, trackpoint3])
        track.add(trackSegment: trackseg)
        
        root.add(waypoints: waypoints)
        root.add(track: track)
        
        let id = UUID().uuidString
        
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] as URL
        do {
            try root.outputToFile(saveAt: url, fileName: id)
        }
        catch {
            print(error)
        }
        let file = url.appendingPathComponent("\(id).gpx")
        
        return file
    }
    
    func outputNineAsFile() -> URL?  {
        let waypoints = [GPXWaypoint]()
        let root = GPXRoot(creator: "Runaway")
        let timeNow = Date.now
        let trackpoint1 = GPXTrackPoint(latitude: 38.580612, longitude: -90.380204)
        trackpoint1.time = timeNow
        let trackpoint2 = GPXTrackPoint(latitude: 38.582674, longitude: -90.384600)
        trackpoint2.time = timeNow.withAddedMinutes(minutes: 40)
        let trackpoint3 = GPXTrackPoint(latitude: 38.582633, longitude: -90.379797)
        trackpoint3.time = timeNow.withAddedMinutes(minutes: 80)
        let trackpoint4 = GPXTrackPoint(latitude: 38.581237, longitude: -90.379591)
        trackpoint4.time = timeNow.withAddedMinutes(minutes: 120)
        let track = GPXTrack()
        let trackseg = GPXTrackSegment()
        trackseg.add(trackpoints: [trackpoint1, trackpoint2, trackpoint3, trackpoint4])
        track.add(trackSegment: trackseg)
        
        
        root.add(waypoints: waypoints)
        root.add(track: track)
        
        let id = UUID().uuidString
        
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] as URL
        do {
            try root.outputToFile(saveAt: url, fileName: id)
        }
        catch {
            print(error)
        }
        let file = url.appendingPathComponent("\(id).gpx")
        
        return file
    }
    
    func outputEighteenAsFile() -> URL?  {
        let waypoints = [GPXWaypoint]()
        let root = GPXRoot(creator: "Runaway")
        let timeNow = Date.now
        let trackpoint1 = GPXTrackPoint(latitude: 38.580612, longitude: -90.380204)
        trackpoint1.time = timeNow
        let trackpoint2 = GPXTrackPoint(latitude: 38.582674, longitude: -90.384600)
        trackpoint2.time = timeNow.withAddedMinutes(minutes: 20)
        let trackpoint3 = GPXTrackPoint(latitude: 38.582633, longitude: -90.379797)
        trackpoint3.time = timeNow.withAddedMinutes(minutes: 40)
        let trackpoint4 = GPXTrackPoint(latitude: 38.581237, longitude: -90.379591)
        trackpoint4.time = timeNow.withAddedMinutes(minutes: 60)
        let trackpoint5 = GPXTrackPoint(latitude: 38.579913, longitude: -90.378940)
        trackpoint5.time = timeNow.withAddedMinutes(minutes: 80)
        let trackpoint6 = GPXTrackPoint(latitude: 38.582593, longitude: -90.378186)
        trackpoint6.time = timeNow.withAddedMinutes(minutes: 100)
        let trackpoint7 = GPXTrackPoint(latitude: 38.579574, longitude: -90.377752)
        trackpoint7.time = timeNow.withAddedMinutes(minutes: 120)
        let trackpoint8 = GPXTrackPoint(latitude: 38.578193, longitude: -90.382834)
        trackpoint8.time = timeNow.withAddedMinutes(minutes: 140)
        let trackpoint9 = GPXTrackPoint(latitude: 38.580050, longitude: -90.382916)
        trackpoint9.time = timeNow.withAddedMinutes(minutes: 160)
        let trackpoint10 = GPXTrackPoint(latitude: 38.581535, longitude: -90.385085)
        trackpoint10.time = timeNow.withAddedMinutes(minutes: 180)
        let trackpoint11 = GPXTrackPoint(latitude: 38.580518, longitude: -90.380283)
        trackpoint11.time = timeNow.withAddedMinutes(minutes: 200)
        
        let track = GPXTrack()
        let trackseg = GPXTrackSegment()
        trackseg.add(trackpoints: [trackpoint1, trackpoint2, trackpoint3, trackpoint4, trackpoint5, trackpoint6, trackpoint7, trackpoint8, trackpoint9,trackpoint10, trackpoint11])
        track.add(trackSegment: trackseg)
        
        
        root.add(waypoints: waypoints)
        root.add(track: track)
        
        let id = UUID().uuidString
        
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] as URL
        do {
            try root.outputToFile(saveAt: url, fileName: id)
        }
        catch {
            print(error)
        }
        let file = url.appendingPathComponent("\(id).gpx")
        
        return file
    }
    
    func doAlert(title: String, message: String)
    {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alert.addAction(okAction)
//        self.present(alert, animated: true, completion: nil)
    }
}
