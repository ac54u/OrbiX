//
//  OrbixWidgetLiveActivity.swift
//  OrbixWidget
//
//  Created by mac on 2026/3/21.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct OrbixWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct OrbixWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: OrbixWidgetAttributes.self) { context in
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

extension OrbixWidgetAttributes {
    fileprivate static var preview: OrbixWidgetAttributes {
        OrbixWidgetAttributes(name: "World")
    }
}

extension OrbixWidgetAttributes.ContentState {
    fileprivate static var smiley: OrbixWidgetAttributes.ContentState {
        OrbixWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: OrbixWidgetAttributes.ContentState {
         OrbixWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: OrbixWidgetAttributes.preview) {
   OrbixWidgetLiveActivity()
} contentStates: {
    OrbixWidgetAttributes.ContentState.smiley
    OrbixWidgetAttributes.ContentState.starEyes
}
