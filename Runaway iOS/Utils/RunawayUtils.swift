//
//  RunawayUtils.swift
//  Runaway iOS
//
//  Created by Jack Rudelic on 2/21/25.
//

import Foundation

extension Formatter {
    static let date: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .iso8601)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()
}

extension Date {
    var noon: Date {
        return Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: self)!
    }
}

extension Double {
    func toString() -> String {
        return String(format: "%.1f",self)
    }
}
