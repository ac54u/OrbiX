import Foundation
import ActivityKit

@available(iOS 16.1, *)
struct DownloadAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var progress: Double
        var speed: String
    }
    var movieName: String
}
