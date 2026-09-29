# A pod shaped like react-native-svg 15.15.5: an old iOS minimum and a resource bundle.
Pod::Spec.new do |s|
  s.name = "LowBundle"
  s.version = "1.0.0"
  s.summary = "Test pod with a resource bundle below iOS 15"
  s.homepage = "https://example.invalid"
  s.license = "MIT"
  s.author = "test"
  s.source = { :git => "https://example.invalid/LowBundle.git", :tag => s.version.to_s }
  s.platforms = { :ios => "12.4" }
  s.source_files = "LowBundle.m"
  s.resource_bundles = { "LowBundleResources" => ["resource.txt"] }
end
