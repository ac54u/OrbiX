import UIKit
import Flutter
import ActivityKit

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
      
    guard let controller = window?.rootViewController as? FlutterViewController else {
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
      
    let liveActivityChannel = FlutterMethodChannel(name: "com.orbix/live_activity",
                                              binaryMessenger: controller.binaryMessenger)
      
    liveActivityChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
        
      // ⚠️ 加入 iOS 版本判断，保护低版本系统不崩溃
      if #available(iOS 16.1, *) {
          switch call.method {
          case "startDownload":
              if let args = call.arguments as? [String: Any],
                 let movieName = args["movieName"] as? String {
                  LiveActivityManager.shared.startDownload(movieName: movieName)
                  result(true)
              } else {
                  result(FlutterError(code: "INVALID_ARGS", message: "缺少电影名", details: nil))
              }
              
          case "updateProgress":
              if let args = call.arguments as? [String: Any],
                 let progress = args["progress"] as? Double,
                 let speed = args["speed"] as? String {
                  LiveActivityManager.shared.updateProgress(progress: progress, speed: speed)
                  result(true)
              } else {
                  result(FlutterError(code: "INVALID_ARGS", message: "参数错误", details: nil))
              }
              
          case "stopDownload":
              LiveActivityManager.shared.stopDownload()
              result(true)
              
          default:
              result(FlutterMethodNotImplemented)
          }
      } else {
          // 如果手机系统低于 16.1，静默失败，啥也不干
          result(FlutterError(code: "UNSUPPORTED", message: "灵动岛需要 iOS 16.1+", details: nil))
      }
    })

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

// ⚠️ 给整个管理器打上标签，限制仅在 16.1 及以上系统编译
@available(iOS 16.1, *)
class LiveActivityManager {
    static let shared = LiveActivityManager()
    private var currentActivity: Activity<DownloadAttributes>?

    func startDownload(movieName: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        let attributes = DownloadAttributes(movieName: movieName)
        let initialState = DownloadAttributes.ContentState(progress: 0.0, speed: "启动中...")
        
        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                contentState: initialState,
                pushType: nil
            )
        } catch {
            print("灵动岛启动失败: \(error)")
        }
    }

    func updateProgress(progress: Double, speed: String) {
        Task {
            let updatedState = DownloadAttributes.ContentState(progress: progress, speed: speed)
            await currentActivity?.update(using: updatedState)
        }
    }

    func stopDownload() {
        Task {
            let finalState = DownloadAttributes.ContentState(progress: 1.0, speed: "下载完成")
            await currentActivity?.end(using: finalState, dismissalPolicy: .default)
            currentActivity = nil
        }
    }
}