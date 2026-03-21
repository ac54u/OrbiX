import Foundation
import ActivityKit

@available(iOS 16.1, *)
struct DownloadAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var progress: Double
        var speed: String
        var eta: String
        var sizeInfo: String // 🚀 新增：已下载/总大小 (例如: 1.2GB / 4.0GB)
    }
    var movieName: String
}