# react-native-xcode27

Build and launch React Native and Expo apps with Xcode 27. Install it and rebuild. No code changes.

It fixes the errors that stop an app built with Xcode 27.

**The build fails** in a pod such as react-native-svg or async-storage:

```
The iOS Simulator deployment target 'IPHONEOS_DEPLOYMENT_TARGET' is set to 12.4, but the range of supported deployment target versions is 15.0 to 27.0.x. (in target 'RNSVG-RNSVGFilters' from project 'Pods')
```

Device builds say `The iOS deployment target`, and the pod, version and target vary.

With React Native before 0.83.5 built from source, the `fmt` pod fails to compile, for example:

```
include/fmt/format-inl.h:59:24: error: call to consteval function 'fmt::basic_format_string<char, fmt::basic_string_view<char> &, const char (&)[3]>::basic_format_string<FMT_COMPILE_STRING, 0>' is not a constant expression
```

**The app closes as soon as it opens**, and the log shows:

```
Application failed to launch: UIScene life cycle is required for apps built with this SDK. See "Transitioning to the UIKit scene-based life cycle" in the UIKit documentation for more information on migration.
```

## Install

React Native:

```sh
npm install react-native-xcode27
cd ios && pod install
```

Expo, in a development build or an EAS build:

```sh
npx expo install react-native-xcode27
```

Then build the app again. Autolinking adds the pod. There is no config plugin, and nothing to call
from JavaScript. Run `pod install` with the Xcode you build with, because the build fix reads that
Xcode's SDK.

## Why Xcode 27 breaks the build

Xcode 27 turns an iOS deployment target below 15.0 from a warning into an error. React Native's
`react_native_post_install` raises each pod's library target to React Native's minimum, but not
the resource bundles pods declare, such as react-native-svg's `RNSVGFilters` and async-storage's
privacy manifest bundle. Those keep the older minimum from their podspec, and Xcode refuses them.

React Native fixed this on its main branch on 2026-09-28
([react/react-native#58687](https://github.com/react/react-native/pull/58687)), and it is not in a
release yet. Expo fixed it in expo-modules-autolinking 57.0.5, which comes with SDK 57.
react-native-svg merged its own fix
([software-mansion/react-native-svg#3022](https://github.com/software-mansion/react-native-svg/pull/3022)),
but 15.15.5, the latest release, still declares iOS 12.4.

fmt 11 fails to compile as C++20 with the Apple Clang in Xcode 26.4 and later, and React Native
pinned fmt 11.0.2 until 0.83.5 ([react/react-native#55601](https://github.com/react/react-native/issues/55601)).
The usual workaround is a Podfile edit that compiles fmt as C++17.

## Why Xcode 27 breaks the launch

Apple's UIKit documentation says apps built with the iOS 27 SDK "must adopt the scene-based life
cycle or they fail to launch"
([Transitioning to the UIKit scene-based life cycle](https://developer.apple.com/documentation/uikit/transitioning-to-the-uikit-scene-based-life-cycle)).
React Native's templates create their window in `application:didFinishLaunchingWithOptions:` and
declare no scene. React Native adds scene support in 0.88
([react/react-native#57700](https://github.com/react/react-native/pull/57700),
[#57717](https://github.com/react/react-native/pull/57717)), which is at 0.88.0-rc.3. Expo SDK 56
and earlier have none, and SDK 57's templates don't use its opt-in scene delegate yet.

## What it does

At `pod install`:

- After your Podfile's own `post_install` has run, it raises every Pods target whose iOS
  deployment target is below the minimum of the active Xcode's SDK (15.0 in Xcode 27) to your
  app's deployment target. It prints each change, for example
  `[react-native-xcode27] RNSVG-RNSVGFilters: iOS 12.4 -> 15.1`. Targets the SDK accepts are left
  alone, and nothing is raised above your app's own deployment target.
- If the `fmt` pod is older than 12.1, it compiles that one pod as C++17, the same change as the
  usual Podfile workaround, and prints `[react-native-xcode27] fmt 11.0.2: compiled as C++17`.
- The podspec loads this from `cocoapods/xcode27.rb` by extending CocoaPods' Podfile
  post-install step. Your Podfile is not edited.

At launch, when built with the iOS 27 SDK:

- When UIKit sets the app delegate, and the app declares no scene (no `UIApplicationSceneManifest`
  in `Info.plist`, and no `application:configurationForConnectingSceneSession:options:`), it adds
  that method to the delegate's class, returning a configuration with its own scene delegate.
- The scene delegate puts the window your app delegate already created into the scene and makes it
  key and visible. If there is no window, it creates one and gives it to the app delegate.
- UIKit now sends links, user activities, quick actions and foreground and background transitions to
  the scene. It passes each one to the app delegate method that used to receive it, so
  `RCTLinkingManager`, Expo's app delegate subscribers and your own overrides keep working.
- A link that launches the app arrives with the scene, not in the launch options. It passes the link
  to `application:openURL:options:` as soon as the scene connects, which is where expo-linking
  records the link Expo Router starts from, and answers React Native's `Linking.getInitialURL()` with
  it when the launch options have none.
- If the app already declares a scene, it does nothing. With an SDK before iOS 27, this part
  compiles to nothing.

## How it was checked

Xcode 27.0 (27A266a) on macOS 27.0, CocoaPods 1.16.2, iPhone 18 Pro simulator on iOS 27.0.

| App | Without it | With it |
| --- | --- | --- |
| React Native 0.86.3 with react-native-svg 15.15.5 and async-storage 3.1.1 | Build fails on `RNSVG-RNSVGFilters` (12.4) and `AsyncStorage-AsyncStorage_resources` (13.0) | Builds and launches. `Linking.getInitialURL()` returns the link that launched the app |
| Expo SDK 56, default template with Expo Router and react-native-svg 15.15.4 | Build fails on `RNSVG-RNSVGFilters` | Builds and launches. A link that launches the app opens the linked route |
| Expo SDK 54 (React Native 0.81.5), blank template with react-native-svg 15.12.1 | Build fails on `RNSVG-RNSVGFilters` | Builds and launches |
| Test app with a pod whose library and resource bundle target iOS 12.4, and a stand-in for fmt 11.0.2 that compiles only below C++20 | Build fails | Builds, with fmt compiled as C++17 |
| Minimal UIKit app on the app-based life cycle | Fails to launch | Launches. The window follows the scene into landscape. Links reach `application:openURL:options:` whether they launch the app or arrive while it runs, and the app delegate's foreground and background methods run as they did before |
| Apps that declare a scene, in code or in `Info.plist` | | Launch with their own scene delegate. The launch fix stays out |

The last three rows are automated: `npm test` builds those apps and checks them in the booted
simulator, and CI runs it on GitHub's Xcode 27 image.

## Limits

- Tested in the simulator only, not yet on a device.
- CocoaPods only. Swift Package Manager dependencies are not changed.
- One window. iPad multiwindow needs real scene support.
- Universal links, Handoff and home-screen quick actions go through the same forwarding as
  custom-scheme links, but were not tested.
- Other Xcode 27 problems are out of scope. For example, `react-native run-ios` from
  @react-native-community/cli before 20.2 can't find Xcode 27's Simulator app; upgrade the CLI or
  run from Xcode.
- It includes the launch fix from react-native-uiscene-bridge. Use one or the other.
- Not affiliated with Apple, Meta or Expo.

## License

MIT
