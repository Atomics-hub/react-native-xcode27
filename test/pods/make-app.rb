# Creates App.xcodeproj: an empty iOS app target, enough for CocoaPods to integrate and Xcode to build.
require "xcodeproj"

project = Xcodeproj::Project.new("App.xcodeproj")
target = project.new_target(:application, "App", :ios, ENV.fetch("APP_DEPLOYMENT_TARGET", "15.1"))
main = project.main_group.new_file("main.m")
target.add_file_references([main])
target.build_configurations.each do |configuration|
  configuration.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = "dev.xcode27.app"
  configuration.build_settings["GENERATE_INFOPLIST_FILE"] = "YES"
  configuration.build_settings["CODE_SIGNING_ALLOWED"] = "NO"
end
project.save

scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(target)
scheme.save_as(project.path, "App", true)
