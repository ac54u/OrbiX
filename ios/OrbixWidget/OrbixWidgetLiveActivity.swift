import ActivityKit
import WidgetKit
import SwiftUI

@available(iOS 16.1, *)
struct OrbixWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DownloadAttributes.self) { context in
            // 🌟 锁屏和通知中心的 UI
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(.blue)
                    Text(context.attributes.movieName)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                }
                HStack {
                    Text(context.state.speed)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .contentTransition(.numericText()) // 🚀 丝滑数字滚动动画
                    Spacer()
                    Text(context.state.eta)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .contentTransition(.numericText()) // 🚀 丝滑数字滚动动画
                }
                ProgressView(value: context.state.progress)
                    .tint(.blue)
                
                HStack {
                    Text(context.state.sizeInfo) // 🚀 显示容量信息
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1) // 防止长文本换行
                        .minimumScaleFactor(0.8)
                    Spacer()
                    Text("\(Int(context.state.progress * 100))%")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                        .contentTransition(.numericText())
                }
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.85))
            .activitySystemActionForegroundColor(Color.white)

        } dynamicIsland: { context in
            // 🌟 顶部灵动岛的 UI
            DynamicIsland {
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
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                        .lineLimit(1) // 🚀 限制绝对只有 1 行，防止排版被顶成竖向
                        .minimumScaleFactor(0.5) // 🚀 如果字太宽，允许缩小到 50% 字号
                        .contentTransition(.numericText()) // 🚀 动画
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 4) {
                        HStack {
                            Text(context.state.sizeInfo) // 🚀 左下角显示容量或长提示语
                                .font(.caption)
                                .foregroundColor(.gray)
                                .lineLimit(1) // 🚀 防挤压换行
                                .minimumScaleFactor(0.7)
                            Spacer()
                            Text(context.state.eta)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .lineLimit(1) // 🚀 防挤压换行
                                .contentTransition(.numericText())
                        }
                        ProgressView(value: context.state.progress)
                            .tint(.blue)
                    }
                    .padding(.top, 5)
                }
            } compactLeading: {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(.blue)
            } compactTrailing: {
                Text("\(Int(context.state.progress * 100))%")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.green) // 换成绿色更显眼
                    .contentTransition(.numericText())
            } minimal: {
                Image(systemName: "arrow.down")
                    .foregroundColor(.blue)
            }
        }
    }
}
