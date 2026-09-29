# Stands in for the fmt 11.0.2 pod React Native before 0.83.5 builds from source: same name and
# version, C++20 from its xcconfig, and a source file that only compiles as C++17 or earlier.
Pod::Spec.new do |s|
  s.name = "fmt"
  s.version = "11.0.2"
  s.summary = "Test stand-in for fmt 11.0.2"
  s.homepage = "https://example.invalid"
  s.license = "MIT"
  s.author = "test"
  s.source = { :git => "https://example.invalid/fmt.git", :tag => s.version.to_s }
  s.platforms = { :ios => "13.0" }
  s.source_files = "format.cc"
  s.pod_target_xcconfig = { "CLANG_CXX_LANGUAGE_STANDARD" => "c++20" }
end
