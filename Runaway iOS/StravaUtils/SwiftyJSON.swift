//
//  SwiftJSON.swift
//  Runaway
//
//  Created by Jack Rudelic on 2/1/24.
//

import SwiftyJSON

extension RawRepresentable {
    init?(o rawValue: RawValue?) {
        guard let rawValue = rawValue, let value = Self(rawValue: rawValue) else { return nil }
        self = value
    }
}

extension JSON  {
    public func strava<T: Strava>(_ type: T.Type?) -> T? {
        return type?.init(self)
    }

    public func strava<T: RawRepresentable>(_ type: T.Type?) -> T? where T.RawValue == Int {
        return type?.init(optionalRawValue: self.int)
    }

    public func strava<T: RawRepresentable>(_ type: T.Type?) -> T? where T.RawValue == String {
        return type?.init(optionalRawValue: self.string)
    }

    public func strava<T: Strava>(_ type: T.Type?) -> [T]? {
        return self.arrayValue.compactMap  { T($0) }
    }
}
