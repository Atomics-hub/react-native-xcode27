import UIKit

// Opens the link passed as its first launch argument, the way another app would. Links opened with
// `simctl openurl` wait on a confirmation prompt instead.
@main
class AppDelegate: UIResponder, UIApplicationDelegate {
  func application(_ application: UIApplication, configurationForConnecting session: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
    let configuration = UISceneConfiguration(name: "Default", sessionRole: session.role)
    configuration.delegateClass = LauncherSceneDelegate.self
    return configuration
  }
}

class LauncherSceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    guard let windowScene = scene as? UIWindowScene else { return }
    window = UIWindow(windowScene: windowScene)
    window?.rootViewController = UIViewController()
    window?.makeKeyAndVisible()
    let arguments = CommandLine.arguments
    guard arguments.count > 1, let url = URL(string: arguments[1]) else { return }
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { UIApplication.shared.open(url) }
  }
}
