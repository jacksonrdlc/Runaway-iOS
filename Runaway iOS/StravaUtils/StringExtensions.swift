//
//  StringExtensions.swift
//  Runaway
//
//  Created by Jack Rudelic on 2/1/24.
//

import Foundation

extension String {
    func toDate(_ format: String = "yyyy-MM-dd'T'HH:mm:ssZZZZZ") -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.date(from: self)
    }
}
