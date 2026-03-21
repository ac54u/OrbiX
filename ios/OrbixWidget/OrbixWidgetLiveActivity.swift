import ActivityKit
import WidgetKit
import SwiftUI



// 2. 灵动岛 UI 布局
struct OrbixWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DownloadAttributes.self) { context in
            // 锁屏界面和通知中心的 UI
            VStack {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(.blue)
                    Text("正在下载: \(context.attributes.movieName)")
                        .font(.headline)
                    Spacer()
                    Text(context.state.speed)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                ProgressView(value: context.state.progress)
                    .tint(.blue)
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.8))
            .activitySystemActionForegroundColor(Color.white)

        } dynamicIsland: { context in
            // 顶部灵动岛的 UI
            DynamicIsland {
                // 灵动岛长按展开后的 UI
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.movieName)
                        .lineLimit(1)
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.speed)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: context.state.progress)
                        .tint(.blue)
                        .padding(.top, 5)
                }
            } compactLeading: {
                // 灵动岛收起时的左侧 UI
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(.blue)
            } compactTrailing: {
                // 灵动岛收起时的右侧 UI
                Text("\(Int(context.state.progress * 100))%")
                    .font(.caption2)
            } minimal: {
                // 多个灵动岛时的极简 UI
                Image(systemName: "arrow.down")
                    .foregroundColor(.blue)
            }
        }
    }
}
