//
//  DateExtensions.swift
//  RunawayUI
//
//  Created by Jack Rudelic on 7/17/24.
//

import SwiftUI

// Date extensions
extension Date {
    var startOfMonth: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components) ?? self
    }
    
    var startOfLastMonth: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        var newComponents = DateComponents()
        newComponents.year = components.year
        newComponents.month = (components.month ?? 1) - 1
        return calendar.date(from: newComponents) ?? self
    }
    
    var endOfMonth: Date {
        var components = DateComponents()
        components.month = 1
        components.day = -1
        return Calendar.current.date(byAdding: components, to: startOfMonth) ?? self
    }
    
    var noon: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: self)
        var newComponents = DateComponents()
        newComponents.year = components.year
        newComponents.month = components.month
        newComponents.day = components.day
        newComponents.hour = 12
        return calendar.date(from: newComponents) ?? self
    }
    
    func startOfWeek() -> TimeInterval {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        let startOfWeek = calendar.date(from: components)!
        return startOfWeek.timeIntervalSince1970
    }
    
    var dayOfTheWeek: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE"
        return dateFormatter.string(from: self)
    }
}

// Int extension
extension Int {
    var dayOfTheWeek: String {
        let date = Date(timeIntervalSince1970: TimeInterval(self))
        return date.dayOfTheWeek
    }
}
