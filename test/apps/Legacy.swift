import UIKit

// An app on the app-based life cycle, set up the way React Native templates before 0.88 set one up.
@main
class AppDelegate: UIResponder, UIApplicationDelegate {
  var window: UIWindow?

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    window = UIWindow(frame: UIScreen.main.bounds)
    window?.rootViewController = UIViewController()
    window?.makeKeyAndVisible()
    record("launched")
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.inspect() }
    return true
  }

  func inspect() {
    guard let window = window, let scene = window.windowScene else {
      return record("window has no scene")
    }
    record("window is key: \(window.isKeyWindow)")
    RCTLinkingManager().getInitialURL({ url in record("initial URL: \(url ?? "none")") }, reject: { _, _, _ in })
    scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
      let size = window.bounds.size
      record("landscape window fills the scene: \(size.width > size.height && size == scene.coordinateSpace.bounds.size)")
    }
  }

  func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    record("opened \(url.absoluteString)")
    return true
  }

  func applicationDidBecomeActive(_ application: UIApplication) { record("did become active") }
  func applicationWillResignActive(_ application: UIApplication) { record("will resign active") }
  func applicationDidEnterBackground(_ application: UIApplication) { record("did enter background") }
  func applicationWillEnterForeground(_ application: UIApplication) { record("will enter foreground") }
}

// Stands in for React Native's RCTLinkingManager, whose getInitialURL reads only the launch options.
@objc(RCTLinkingManager)
class RCTLinkingManager: NSObject {
  @objc(getInitialURL:reject:)
  dynamic func getInitialURL(_ resolve: @escaping @convention(block) (Any?) -> Void, reject: @escaping @convention(block) (String?, String?, Error?) -> Void) {
    resolve(nil)
  }
}
