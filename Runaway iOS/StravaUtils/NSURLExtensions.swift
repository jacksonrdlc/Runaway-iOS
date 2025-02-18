//
//  NSURLExtensions.swift
//  Runaway
//
//  Created by Jack Rudelic on 2/1/24.
//

import Foundation

extension URL {
    func getQueryParameters() -> Dictionary<String, String>? {
        var results = [String:String]()
        let keyValues = self.query?.components(separatedBy: "&")
        keyValues?.forEach {
            let kv = $0.components(separatedBy: "=")
            if kv.count > 1 {
                results[kv[0]] = kv[1]
            }
        }
        return results
    }
}
