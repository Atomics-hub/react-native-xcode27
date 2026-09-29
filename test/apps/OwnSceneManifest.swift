import UIKit

// An app that already adopted scenes by declaring them in Info.plist.
@main
class AppDelegate: UIResponder, UIApplicationDelegate {}

@objc(OwnSceneDelegate)
class OwnSceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    guard let windowScene = scene as? UIWindowScene else { return }
    window = UIWindow(windowScene: windowScene)
    window?.rootViewController = UIViewController()
    window?.makeKeyAndVisible()
    record("own scene delegate connected")
  }
}
