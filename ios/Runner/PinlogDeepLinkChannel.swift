import Flutter
import UIKit

/// app_links v7 이 FlutterImplicitEngineDelegate 에서 채널 등록을 건너뛰는 버그 우회.
/// SceneDelegate.willConnectTo 에서 FlutterViewController.binaryMessenger 로 초기화한다.
class PinlogDeepLinkChannel: NSObject {
  static let shared = PinlogDeepLinkChannel()

  private var channel: FlutterMethodChannel?
  private var pendingUrl: String?

  func setup(messenger: FlutterBinaryMessenger) {
    print("🔌 [Pinlog] PinlogDeepLinkChannel.setup() called, channel ready")
    channel = FlutterMethodChannel(name: "com.pinlog/deeplink", binaryMessenger: messenger)
    if let url = pendingUrl {
      print("🔗 [Pinlog] Delivering pending URL: \(url)")
      pendingUrl = nil
      channel?.invokeMethod("onDeepLink", arguments: url)
    }
  }

  func send(url: URL) {
    if let ch = channel {
      print("🔗 [Pinlog] Sending URL to Dart: \(url.absoluteString)")
      ch.invokeMethod("onDeepLink", arguments: url.absoluteString)
    } else {
      print("⚠️ [Pinlog] Channel not ready, storing pending URL: \(url.absoluteString)")
      pendingUrl = url.absoluteString
    }
  }
}
