import ActivityKit
import WidgetKit
import SwiftUI

@available(iOS 16.1, *)
struct OrbixWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DownloadAttributes.self) { context in
            // 🌟 锁屏和通知中心的 UI (优化排版)
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(.blue)
                    Text(context.attributes.movieName)
                        .font(.headline)
                        .lineLimit(1) // 限制1行，防止名字太长顶破UI
                    Spacer()
                }
                HStack {
                    Text(context.state.speed)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(context.state.eta) // 🚀 显示剩余时间
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                ProgressView(value: context.state.progress)
                    .tint(.blue)
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.85))
            .activitySystemActionForegroundColor(Color.white)

        } dynamicIsland: { context in
            // 🌟 顶部灵动岛的 UI
            DynamicIsland {
                // 长按展开：左侧图标
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                }
                // 长按展开：中间标题
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.movieName)
                        .lineLimit(1)
                        .font(.headline)
                }
                // 长按展开：右侧网速
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.speed)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green) // 网速变成绿色，更抢眼
                }
                // 长按展开：底部进度条和剩余时间
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 4) {
                        HStack {
                            Spacer()
                            Text(context.state.eta)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        ProgressView(value: context.state.progress)
                            .tint(.blue)
                    }
                    .padding(.top, 5)
                }
            } compactLeading: {
                // 收起时：左侧 UI
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(.blue)
            } compactTrailing: {
                // 收起时：右侧 UI
                Text("\(Int(context.state.progress * 100))%")
                    .font(.caption2)
                    .fontWeight(.bold)
            } minimal: {
                // 极简模式
                Image(systemName: "arrow.down")
                    .foregroundColor(.blue)
            }
        }
    }
}