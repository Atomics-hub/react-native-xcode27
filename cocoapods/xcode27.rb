# Xcode 27 refuses to build any target whose iOS deployment target is below the minimum its SDK
# supports (15.0). React Native's post-install raises each pod's library target to React Native's
# minimum, but not the resource bundles pods declare, such as react-native-svg's RNSVGFilters and
# async-storage's privacy bundle. Those keep the podspec's older value and fail the build with
# "The iOS deployment target 'IPHONEOS_DEPLOYMENT_TARGET' is set to 12.4, but the range of supported
# deployment target versions is 15.0 to 27.0.x".
#
# After the Podfile's own post_install has run, this raises every Pods target still below the SDK's
# minimum to the app's deployment target. Targets the SDK accepts are left as they are, and nothing
# is raised above the app's own deployment target. It also compiles fmt before 12.1 as C++17 (below).

require 'json'

module ReactNativeXcode27
  module DeploymentTargets
    SETTING = 'IPHONEOS_DEPLOYMENT_TARGET'

    def self.version(value)
      Gem::Version.new(value.to_s) if value.to_s.match?(/\A\d+(\.\d+)*\z/)
    end

    def self.log(message)
      Pod::UI.puts "[react-native-xcode27] #{message}"
    end

    # The lowest iOS version the selected Xcode's SDK accepts, from its SDKSettings.json.
    def self.sdk_minimum
      sdk = `xcrun --sdk iphoneos --show-sdk-path 2>/dev/null`.strip
      settings = File.join(sdk, 'SDKSettings.json')
      return nil if sdk.empty? || !File.file?(settings)
      version(JSON.parse(File.read(settings)).dig('SupportedTargets', 'iphoneos', 'MinimumDeploymentTarget'))
    rescue StandardError
      nil
    end

    def self.apply(installer)
      minimum = sdk_minimum
      unless minimum
        log "Couldn't read the iOS SDK's minimum deployment target (is Xcode selected with xcode-select?), so no deployment targets were changed."
        return
      end

      app = installer.aggregate_targets
        .map(&:platform)
        .select { |platform| platform.name == :ios }
        .map { |platform| version(platform.deployment_target) }
        .compact
        .min
      if app && app < minimum
        log "The app targets iOS #{app}, below this Xcode's minimum of #{minimum}. Raise `platform :ios` in the Podfile; no pods were changed."
        return
      end
      floor = app || minimum

      projects = installer.respond_to?(:generated_projects) && installer.generated_projects ? installer.generated_projects : [installer.pods_project]
      projects.compact.uniq.each do |project|
        [[File.basename(project.path.to_s, '.xcodeproj'), project], *project.targets.map { |target| [target.name, target] }].each do |name, owner|
          raised = nil
          owner.build_configurations.each do |configuration|
            current = version(configuration.build_settings[SETTING])
            next unless current && current < minimum
            configuration.build_settings[SETTING] = floor.to_s
            raised = current
          end
          log "#{name}: iOS #{raised} -> #{floor}" if raised
        end
      end
    end
  end

  # fmt before 12.1 fails to compile as C++20 with the Apple Clang in Xcode 26.4 and later ("call to
  # consteval function ... is not a constant expression"), and React Native before 0.83.5 pins fmt
  # 11.0.2 when it builds from source. Compiled as C++17, fmt doesn't use consteval.
  module Fmt
    FIXED = Gem::Version.new('12.1')

    def self.apply(installer)
      fmt = installer.pod_targets.find { |target| target.pod_name == 'fmt' }
      return unless fmt && Gem::Version.new(fmt.root_spec.version.to_s) < FIXED
      projects = installer.respond_to?(:generated_projects) && installer.generated_projects ? installer.generated_projects : [installer.pods_project]
      projects.compact.uniq.each do |project|
        project.targets.select { |target| target.name == fmt.label }.each do |target|
          changed = false
          target.build_configurations.each do |configuration|
            next if configuration.build_settings['CLANG_CXX_LANGUAGE_STANDARD'].to_s.match?(/\A(c|gnu)\+\+(98|0x|11|14|1y|17|1z)\z/)
            configuration.build_settings['CLANG_CXX_LANGUAGE_STANDARD'] = 'c++17'
            changed = true
          end
          DeploymentTargets.log "#{target.name} #{fmt.root_spec.version}: compiled as C++17" if changed
        end
      end
    end
  end

  module PostInstall
    def post_install!(installer)
      ran = super
      DeploymentTargets.apply(installer)
      Fmt.apply(installer)
      ran
    end
  end
end

Pod::Podfile.prepend(ReactNativeXcode27::PostInstall) unless Pod::Podfile.ancestors.include?(ReactNativeXcode27::PostInstall)
