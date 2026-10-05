# A C++20 pod that includes fmt's headers, like react-native-nitro-modules.
Pod::Spec.new do |s|
  s.name = "FmtUser"
  s.version = "1.0.0"
  s.summary = "Test pod including fmt's headers as C++20"
  s.homepage = "https://example.invalid"
  s.license = "MIT"
  s.author = "test"
  s.source = { :git => "https://example.invalid/FmtUser.git", :tag => s.version.to_s }
  s.platforms = { :ios => "13.0" }
  s.source_files = "user.cpp"
  s.dependency "fmt"
  s.pod_target_xcconfig = { "CLANG_CXX_LANGUAGE_STANDARD" => "c++20" }
end
