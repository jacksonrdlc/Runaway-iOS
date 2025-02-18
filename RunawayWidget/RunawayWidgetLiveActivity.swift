//
//  RunawayWidgetLiveActivity.swift
//  RunawayWidget
//
//  Created by Jack Rudelic on 2/18/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct RunawayWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct RunawayWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RunawayWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension RunawayWidgetAttributes {
    fileprivate static var preview: RunawayWidgetAttributes {
        RunawayWidgetAttributes(name: "World")
    }
}

extension RunawayWidgetAttributes.ContentState {
    fileprivate static var smiley: RunawayWidgetAttributes.ContentState {
        RunawayWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: RunawayWidgetAttributes.ContentState {
         RunawayWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: RunawayWidgetAttributes.preview) {
   RunawayWidgetLiveActivity()
} contentStates: {
    RunawayWidgetAttributes.ContentState.smiley
    RunawayWidgetAttributes.ContentState.starEyes
}
