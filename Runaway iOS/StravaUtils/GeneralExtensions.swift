//
//  GeneralExtensions.swift
//  Runaway
//
//  Created by Jack Rudelic on 2/1/24.
//

import Foundation

extension RawRepresentable {
    init?(optionalRawValue rawValue: RawValue?) {
        guard let rawValue = rawValue, let value = Self(rawValue: rawValue) else { return nil }
        self = value
    }
}

extension DateFormatter {
    func dateFromString(optional string: String?)  -> Date? {
        guard let string = string else { return nil }
        return date(from: string)
    }
}

extension URL {
    init?(optionalString string: String?) {
        guard let string = string else { return nil }
        self.init(string: string)
    }
}
