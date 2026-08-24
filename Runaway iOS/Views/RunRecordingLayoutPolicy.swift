import SwiftUI

enum RunRecordingLayoutPolicy {
    static func usesVerticalControls(for dynamicTypeSize: DynamicTypeSize) -> Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    static func statLineLimit(for dynamicTypeSize: DynamicTypeSize) -> Int {
        dynamicTypeSize.isAccessibilitySize ? 2 : 1
    }
}
