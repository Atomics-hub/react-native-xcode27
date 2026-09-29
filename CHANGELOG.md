# Changelog

## 0.1.0

First release.

- At `pod install`, raises every Pods target whose iOS deployment target is below the active SDK's
  minimum (15.0 in Xcode 27) to the app's deployment target, after the Podfile's own
  `post_install`, and prints each change. This fixes "The iOS deployment target
  'IPHONEOS_DEPLOYMENT_TARGET' is set to 12.4, but the range of supported deployment target versions
  is 15.0 to 27.0.x" for resource bundles such as react-native-svg's `RNSVGFilters`.
- At `pod install`, compiles the `fmt` pod as C++17 when it is older than 12.1, which React Native
  before 0.83.5 pins when it builds from source. As C++20, fmt 11 fails with Xcode 26.4 and later:
  "call to consteval function ... is not a constant expression".
- At launch, adopts the UIScene life cycle for apps that have not, so they don't fail with "UIScene
  life cycle is required for apps built with this SDK". The same fix as react-native-uiscene-bridge
  0.1.0: the app delegate's window moves into the scene, links, user activities, quick actions and
  lifecycle calls reach the app delegate, and `Linking.getInitialURL()` returns the launch link.
- No code changes, and nothing to configure.
