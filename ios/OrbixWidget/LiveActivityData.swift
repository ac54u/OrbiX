import Foundation
import ActivityKit

@available(iOS 16.1, *)
struct DownloadAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var progress: Double
        var speed: String
        var eta: String // 🚀 新增：剩余时间
    }
    var movieName: String
}