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
    
    var startOfThisYear: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: self)
        return calendar.date(from: components) ?? self
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
        let startOfWeek = calendar.date(from: components) ?? self
        return startOfWeek.timeIntervalSince1970
    }
    
    var dayOfTheWeek: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE"
        return dateFormatter.string(from: self)
    }
}

// Calendar extension
extension Calendar {
    /// Safe wrapper for date(byAdding:value:to:) that falls back to the base date on nil
    func safeDate(byAdding component: Component, value: Int, to date: Date) -> Date {
        self.date(byAdding: component, value: value, to: date) ?? date
    }
}

// Int extension
extension Int {
    var dayOfTheWeek: String {
        let date = Date(timeIntervalSince1970: TimeInterval(self))
        return date.dayOfTheWeek
    }
}
