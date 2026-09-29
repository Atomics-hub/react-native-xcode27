#!/bin/sh
# Builds the apps in test/apps, runs them in the booted iOS simulator and checks what each one records.
# Needs Xcode with the iOS 27 SDK or later and a booted simulator.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
build=$(mktemp -d)
sdk=$(xcrun --sdk iphonesimulator --show-sdk-version)
target="$(uname -m)-apple-ios$sdk-simulator"
failures=0

case $sdk in
  2[7-9]* | [3-9][0-9]*) ;;
  *) echo "The selected Xcode has the iOS $sdk SDK; these tests need iOS 27 or later." >&2; exit 1 ;;
esac

# app NAME SOURCE BRIDGE [PLIST_ENTRIES]
app() {
  name=$1 source=$2 bridge=$3 entries=${4:-}
  id=$(echo "$name" | tr '[:upper:]' '[:lower:]')
  bundle="$build/$name.app"
  mkdir -p "$bundle"
  set -- "$here/apps/$source" "$here/apps/Record.swift"
  if [ "$bridge" = yes ]; then set -- "$@" "$build/bridge.o"; fi
  xcrun --sdk iphonesimulator swiftc -target "$target" -parse-as-library -suppress-warnings "$@" -o "$bundle/$name"
  cat > "$bundle/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>$name</string>
  <key>CFBundleIdentifier</key><string>dev.xcode27.$id</string>
  <key>CFBundleName</key><string>$name</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>MinimumOSVersion</key><string>$sdk</string>
  <key>UIDeviceFamily</key><array><integer>1</integer></array>
  <key>UILaunchScreen</key><dict/>
  <key>UISupportedInterfaceOrientations</key>
  <array>
    <string>UIInterfaceOrientationPortrait</string>
    <string>UIInterfaceOrientationLandscapeLeft</string>
    <string>UIInterfaceOrientationLandscapeRight</string>
  </array>
  <key>CFBundleURLTypes</key>
  <array><dict><key>CFBundleURLSchemes</key><array><string>xcode27-$id</string></array></dict></array>
  $entries
</dict>
</plist>
EOF
  codesign --force --sign - "$bundle" 2>/dev/null
  xcrun simctl uninstall booted "dev.xcode27.$id" 2>/dev/null || true
  xcrun simctl install booted "$bundle"
}

events() {
  container=$(xcrun simctl get_app_container booted "dev.xcode27.$1" data)
  cat "$container/Documents/events.log" 2>/dev/null || true
}

forget() {
  container=$(xcrun simctl get_app_container booted "dev.xcode27.$1" data)
  rm -f "$container/Documents/events.log"
}

launch() { xcrun simctl launch booted "dev.xcode27.$1" "$@" > /dev/null; }
quit() { xcrun simctl terminate booted "dev.xcode27.$1" 2> /dev/null || true; }

# Opens a link from another app, as a person tapping it would.
open_link() {
  quit launcher
  xcrun simctl launch booted dev.xcode27.launcher "$1" > /dev/null
}

pass() { echo "ok - $1"; }
fail() { echo "not ok - $1"; failures=$((failures + 1)); }

# expect APP EVENT: waits up to 20 seconds for the app to record EVENT.
expect() {
  tries=0
  while [ $tries -lt 40 ]; do
    if events "$1" | grep -Fqx "$2"; then pass "$1 records \"$2\""; return; fi
    sleep 0.5
    tries=$((tries + 1))
  done
  fail "$1 records \"$2\" (recorded: $(events "$1" | tr '\n' '|'))"
}

# expect_count APP EVENT N
expect_count() {
  found=$(events "$1" | grep -Fcx "$2" || true)
  if [ "$found" -eq "$3" ]; then pass "$1 records \"$2\" $3 times"; else fail "$1 records \"$2\" $3 times, not $found"; fi
}

xcrun --sdk iphonesimulator clang -target "$target" -fobjc-arc -Wall -Werror -c "$here/../ios/RNXcode27.m" -o "$build/bridge.o"

app LegacyNoBridge Legacy.swift no
app Legacy Legacy.swift yes
app OwnSceneCode OwnSceneCode.swift yes
app OwnSceneManifest OwnSceneManifest.swift yes '<key>UIApplicationSceneManifest</key><dict><key>UIApplicationSupportsMultipleScenes</key><false/><key>UISceneConfigurations</key><dict><key>UIWindowSceneSessionRoleApplication</key><array><dict><key>UISceneConfigurationName</key><string>Default</string><key>UISceneDelegateClassName</key><string>OwnSceneDelegate</string></dict></array></dict></dict>'
app Launcher Launcher.swift no

echo "# Without the bridge, UIKit stops the app before didFinishLaunching"
launch legacynobridge
sleep 5
if events legacynobridge | grep -Fqx "launched"; then fail "legacynobridge fails to launch"; else pass "legacynobridge fails to launch"; fi

echo "# With the bridge, the app's own window is in a scene"
launch legacy
expect legacy "launched"
expect legacy "window is key: true"
expect legacy "initial URL: none"
expect legacy "landscape window fills the scene: true"

echo "# A link that launches the app reaches application:openURL:options: and getInitialURL"
quit legacy
forget legacy
open_link "xcode27-legacy://cold"
expect legacy "opened xcode27-legacy://cold"
expect legacy "initial URL: xcode27-legacy://cold"

echo "# A link while it runs, after a trip to the background"
open_link "xcode27-legacy://warm"
expect legacy "opened xcode27-legacy://warm"
expect legacy "did enter background"
expect legacy "will enter foreground"
expect_count legacy "will enter foreground" 1
expect_count legacy "did become active" 2
quit legacy
quit launcher

echo "# Apps that declare their own scene keep it"
launch ownscenecode
expect ownscenecode "own scene delegate connected"
quit ownscenecode
launch ownscenemanifest
expect ownscenemanifest "own scene delegate connected"
quit ownscenemanifest

rm -rf "$build"
if [ $failures -gt 0 ]; then echo "$failures failed"; exit 1; fi
echo "all passed"
