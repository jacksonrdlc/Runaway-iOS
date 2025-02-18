//
//  Upload.swift
//  Runaway
//
//  Created by Jack Rudelic on 2/1/24.
//

import Foundation
import SwiftyJSON

/**
 Upload struct

 Uploading to Strava is an asynchronous process. A file is uploaded using a multipart/form-data POST request which performs initial checks on the data and enqueues the file for processing. The activity will not appear in other API requests until it has finished processing successfully.

 Processing status may be checked by polling Strava. A one-second or longer polling interval is recommended. The mean processing time is currently around 8 seconds. Once processing is complete, Strava will respond to polling requests with the activity’s ID.

 Errors can occur during the submission or processing steps and may be due to malformed activity data or duplicate data submission.

 - warning: Not yet tested

 **/
public struct UploadData {
    public var activityType: ActivityType?
    public var name: String?
    public var description: String?
    public var `private`: Bool?
    public var trainer: Bool?
    public var externalId: String?
    public var startDate: String?
    public var elapsedTime: Int?

    public var dataType: DataType?
    public var file: Data?

    public init(name: String, dataType: DataType, file: Data) {
        self.name = name
        self.dataType = dataType
        self.file = file
    }

    public init(activityType: ActivityType?, name: String?, description: String?,
                `private`: Bool?, trainer: Bool?, externalId: String?, startDate: String?, elapsedTime: Int?, dataType: DataType, file: Data) {
        self.activityType = activityType
        self.description = description
        self.`private` = `private`
        self.trainer = trainer
        self.externalId = externalId
        self.name = name
        self.startDate = startDate
        self.elapsedTime = elapsedTime
        self.dataType = dataType
        self.file = file
    }

    internal var params: [String: Any] {

        var params: [String: Any] = [:]
        params["data_type"] = dataType?.rawValue
        params["name"] = name
        params["sport_type"] = activityType?.rawValue
        params["elapsed_time"] = elapsedTime
        params["description"] = description
        if let `private` = `private` {
            params["private"] = (`private` as NSNumber).stringValue
        }
        if let trainer = trainer {
            params["trainer"] = (trainer as NSNumber).stringValue
        }
        params["external_id"] = externalId
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        params["start_date_local"] = dateFormatter.date(from: startDate!)
        print(params)
        return params
    }
}

/**
 Upload status
 **/
public final class UploadStatus: Strava {
    public let id: Int?
    public let externalId: String?
    public let error: String?
    public let status: String?
    public let activityId: Int?

    public required init(_ json: JSON) {
        id = json["id"].int
        externalId = json["external_id"].string
        error = json["error"].string
        status = json["status"].string
        activityId = json["activity_id"].int
    }
}
