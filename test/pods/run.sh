#!/bin/sh
# Builds a small app, without and with this package, using the selected Xcode: a pod whose library and
# resource bundle target iOS 12.4, a stand-in for fmt 11.0.2 whose source only compiles below C++20 and
# whose base.h turns consteval on, and a C++20 pod that fails when fmt's consteval is on. Then a pod
# that calls C++ from Swift, like react-native-nitro-modules. Needs CocoaPods.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
package=$(cd "$here/../.." && pwd)
failures=0
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# Homebrew's CocoaPods keeps its gems, xcodeproj included, in its own GEM_HOME.
if ! ruby -e 'require "xcodeproj"' > /dev/null 2>&1; then
  gem_home=$(sed -n 's/^GEM_HOME="\([^"]*\)".*/\1/p' "$(command -v pod)")
  if [ -n "$gem_home" ]; then export GEM_HOME="$gem_home"; fi
fi

# build NAME WITH_PACKAGE APP_DEPLOYMENT_TARGET: sets $result to succeeded or failed and $notes to
# what the package printed during pod install.
build() {
  name=$1 with=$2 platform=$3
  dir=$(mktemp -d)
  cp -R "$here/LowBundle" "$here/fmt" "$here/FmtUser" "$here/main.m" "$here/make-app.rb" "$dir/"
  {
    echo "platform :ios, '$platform'"
    echo "target 'App' do"
    echo "  pod 'LowBundle', :path => './LowBundle'"
    echo "  pod 'fmt', :path => './fmt'"
    echo "  pod 'FmtUser', :path => './FmtUser'"
    if [ "$with" = yes ]; then echo "  pod 'react-native-xcode27', :path => '$package'"; fi
    echo "end"
  } > "$dir/Podfile"
  if ! (cd "$dir" && APP_DEPLOYMENT_TARGET=$platform ruby make-app.rb && pod install > pod.log 2>&1); then
    echo "$name: pod install failed"; tail -5 "$dir/pod.log"; result=failed; notes=""; rm -rf "$dir"; return
  fi
  if xcodebuild -workspace "$dir/App.xcworkspace" -scheme App -configuration Debug -sdk iphonesimulator \
    -derivedDataPath "$dir/build" build > "$dir/build.log" 2>&1; then
    result=succeeded
  else
    result=failed
  fi
  notes=$(grep -h "react-native-xcode27\]" "$dir/pod.log" || true)
  [ -n "$notes" ] && echo "$notes"
  grep -h -E "error: (The iOS|ISO C\+\+|cannot initialize)" "$dir/build.log" | sed 's/^.*error: /  error: /' | sort -u || true
  echo "$name: build $result"
  rm -rf "$dir"
}

pass() { echo "ok - $1"; }
fail() { echo "not ok - $1"; failures=$((failures + 1)); }

sdk=$(xcrun --sdk iphonesimulator --show-sdk-version)
minimum=$(plutil -extract SupportedTargets.iphonesimulator.MinimumDeploymentTarget raw "$(xcrun --sdk iphonesimulator --show-sdk-path)/SDKSettings.json" 2>/dev/null || echo unknown)
echo "# iOS $sdk SDK, minimum deployment target $minimum"
case $sdk in 2[7-9]* | [3-9][0-9]*) strict=yes ;; *) strict=no ;; esac

# The stand-in has to fail the way fmt 11 does: as C++20 only.
compile() { xcrun --sdk iphonesimulator clang++ -std="$1" -c "$here/fmt/src/format.cc" -o /dev/null > /dev/null 2>&1; }
if ! compile c++20 && compile c++17; then pass "the fmt stand-in compiles as C++17 and not as C++20"; else fail "the fmt stand-in should compile only below C++20"; fi

build "without react-native-xcode27" no 15.1
if [ "$result" = failed ]; then pass "without the package, the build fails"; else fail "expected the build without the package to fail"; fi

build "with react-native-xcode27" yes 15.1
if [ "$result" = succeeded ]; then pass "with the package, the app builds"; else fail "expected the build with the package to succeed"; fi
if [ $strict = yes ]; then
  case $notes in *"LowBundle-LowBundleResources: iOS 12.4 -> 15.1"*) pass "the resource bundle was raised to the app's 15.1" ;; *) fail "expected the resource bundle to be raised to 15.1" ;; esac
fi
case $notes in *"fmt 11.0.2: compiled as C++17"*) pass "fmt 11.0.2 was compiled as C++17" ;; *) fail "expected fmt 11.0.2 to be compiled as C++17" ;; esac
case $notes in *"fmt 11.0.2: consteval off in fmt/base.h"*) pass "fmt's consteval was turned off for the targets that include it" ;; *) fail "expected fmt/base.h to turn consteval off" ;; esac

if [ $strict = yes ]; then
  build "with react-native-xcode27, app below the SDK minimum" yes 13.0
  case $notes in
    *"The app targets iOS 13.0, below this Xcode's minimum"*"no pods were changed"*) pass "an app below the SDK minimum gets a note and unchanged pods" ;;
    *) fail "expected a note and no changes for an app targeting iOS 13.0" ;;
  esac
  case $notes in *" -> "*) fail "no target should be raised above an app targeting iOS 13.0" ;; esac
fi

# build_interop NAME WITH_PACKAGE APP_DEPLOYMENT_TARGET: sets $refs to the iOS 18-only symbols the
# Interop pod's Swift object references, and $notes to what the package printed.
build_interop() {
  name=$1 with=$2 platform=$3
  dir=$(mktemp -d)
  cp -R "$here/Interop" "$here/main.m" "$here/make-app.rb" "$dir/"
  {
    echo "platform :ios, '$platform'"
    echo "target 'App' do"
    echo "  pod 'Interop', :path => './Interop'"
    if [ "$with" = yes ]; then echo "  pod 'react-native-xcode27', :path => '$package'"; fi
    echo "end"
  } > "$dir/Podfile"
  if ! (cd "$dir" && APP_DEPLOYMENT_TARGET=$platform ruby make-app.rb && pod install > pod.log 2>&1); then
    echo "$name: pod install failed"; tail -5 "$dir/pod.log"; result=failed; notes=""; refs=""; rm -rf "$dir"; return
  fi
  if xcodebuild -workspace "$dir/App.xcworkspace" -scheme App -configuration Debug -sdk iphonesimulator \
    -derivedDataPath "$dir/build" build > "$dir/build.log" 2>&1; then
    result=succeeded
  else
    result=failed
  fi
  notes=$(grep -h "react-native-xcode27\]" "$dir/pod.log" || true)
  [ -n "$notes" ] && echo "$notes"
  object=$(find "$dir/build" -path "*Interop.build*" -name "Use.o" | head -1)
  refs=$(nm -u "$object" 2>/dev/null | grep -E "__from_native_exception_pointer|___cxa_init_primary_exception" | tr '\n' ' ' || true)
  echo "$name: build $result, iOS 18-only symbols: ${refs:-none}"
  rm -rf "$dir"
}

if [ $strict = yes ]; then
  build_interop "C++ interop without react-native-xcode27" no 15.1
  if [ -n "$refs" ]; then pass "without the package, Swift C++ interop references iOS 18-only symbols"; else fail "expected iOS 18-only symbols without the package"; fi
  build_interop "C++ interop with react-native-xcode27" yes 15.1
  if [ "$result" = succeeded ] && [ -z "$refs" ]; then pass "with the package, the interop target references no iOS 18-only symbols"; else fail "expected no iOS 18-only symbols with the package"; fi
  case $notes in *"Interop: Swift explicit modules off"*) pass "explicit modules were turned off for the interop target" ;; *) fail "expected explicit modules to be turned off for Interop" ;; esac
  build_interop "C++ interop with react-native-xcode27, app on iOS 18" yes 18.0
  case $notes in *"explicit modules off"*) fail "an app that requires iOS 18 should keep explicit modules" ;; *) pass "an app that requires iOS 18 keeps explicit modules" ;; esac
fi

if [ $failures -gt 0 ]; then echo "$failures failed"; exit 1; fi
echo "all passed"
