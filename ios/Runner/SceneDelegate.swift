import Flutter
import UIKit
import app_links

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    // FlutterSceneDelegate 가 window/FlutterViewController 를 만든 직후
    // binaryMessenger 를 직접 획득해 채널 초기화
    if let flutterVC = window?.rootViewController as? FlutterViewController {
      PinlogDeepLinkChannel.shared.setup(messenger: flutterVC.binaryMessenger)
    }
    // cold-launch URL 은 openURLContexts 에서도 재전달되므로 여기서는 처리하지 않음
  }

  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    for context in URLContexts {
      AppLinks.shared.handleLink(url: context.url)
      PinlogDeepLinkChannel.shared.send(url: context.url)
    }
    super.scene(scene, openURLContexts: URLContexts)
  }
}
