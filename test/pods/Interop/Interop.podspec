# A pod shaped like react-native-nitro-modules: Swift that calls an inline C++ helper using
# std::make_exception_ptr through C++ interop, in an app that supports iOS 15.1.
Pod::Spec.new do |s|
  s.name = "Interop"
  s.version = "1.0.0"
  s.summary = "Test pod using Swift C++ interop"
  s.homepage = "https://example.invalid"
  s.license = "MIT"
  s.author = "test"
  s.source = { :git => "https://example.invalid/Interop.git", :tag => s.version.to_s }
  s.platforms = { :ios => "15.1" }
  s.swift_version = "5.9"
  s.source_files = "*.{swift,hpp}"
  s.public_header_files = "Thrower.hpp"
  s.pod_target_xcconfig = {
    "SWIFT_OBJC_INTEROP_MODE" => "objcxx",
    "CLANG_CXX_LANGUAGE_STANDARD" => "c++20",
    "DEFINES_MODULE" => "YES",
  }
end
