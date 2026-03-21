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
                 let speed = args["speed"] as? String,
                 let eta = args["eta"] as? String,
                 let sizeInfo = args["sizeInfo"] as? String { // 🚀 接收 sizeInfo
                  
                  LiveActivityManager.shared.updateProgress(progress: progress, speed: speed, eta: eta, sizeInfo: sizeInfo)
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
          result(FlutterError(code: "UNSUPPORTED", message: "灵动岛需要 iOS 16.1+", details: nil))
      }
    })

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

@available(iOS 16.1, *)
class LiveActivityManager {
    static let shared = LiveActivityManager()
    private var currentActivity: Activity<DownloadAttributes>?

    func startDownload(movieName: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        let attributes = DownloadAttributes(movieName: movieName)
        let initialState = DownloadAttributes.ContentState(progress: 0.0, speed: "启动中...", eta: "计算中...", sizeInfo: "0 MB / 0 MB")
        
        do {
            // 🚀 适配 iOS 16.2+ 新 API，消除黄标警告
            if #available(iOS 16.2, *) {
                let content = ActivityContent(state: initialState, staleDate: nil)
                currentActivity = try Activity.request(attributes: attributes, content: content, pushType: nil)
            } else {
                currentActivity = try Activity.request(attributes: attributes, contentState: initialState, pushType: nil)
            }
        } catch {
            print("灵动岛启动失败: \(error)")
        }
    }

    func updateProgress(progress: Double, speed: String, eta: String, sizeInfo: String) {
        Task {
            let updatedState = DownloadAttributes.ContentState(progress: progress, speed: speed, eta: eta, sizeInfo: sizeInfo)
            
            // 🚀 适配 iOS 16.2+
            if #available(iOS 16.2, *) {
                let content = ActivityContent(state: updatedState, staleDate: nil)
                await currentActivity?.update(content)
            } else {
                await currentActivity?.update(using: updatedState)
            }
        }
    }

    func stopDownload() {
        Task {
            let finalState = DownloadAttributes.ContentState(progress: 1.0, speed: "下载完成", eta: "0秒", sizeInfo: "已完成")
            
            if #available(iOS 16.2, *) {
                let content = ActivityContent(state: finalState, staleDate: nil)
                await currentActivity?.end(content, dismissalPolicy: .default)
            } else {
                await currentActivity?.end(using: finalState, dismissalPolicy: .default)
            }
            currentActivity = nil
        }
    }
}