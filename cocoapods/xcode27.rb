# Xcode 27 refuses to build any target whose iOS deployment target is below the minimum its SDK
# supports (15.0). React Native's post-install raises each pod's library target to React Native's
# minimum, but not the resource bundles pods declare, such as react-native-svg's RNSVGFilters and
# async-storage's privacy bundle. Those keep the podspec's older value and fail the build with
# "The iOS deployment target 'IPHONEOS_DEPLOYMENT_TARGET' is set to 12.4, but the range of supported
# deployment target versions is 15.0 to 27.0.x".
#
# After the Podfile's own post_install has run, this raises every Pods target still below the SDK's
# minimum to the app's deployment target. Targets the SDK accepts are left as they are, and nothing
# is raised above the app's own deployment target. It also compiles fmt before 12.1 as C++17, and
# turns off Swift explicit modules for C++ interop targets in apps that support iOS before 18 (below).

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

    # The lowest iOS deployment target among the app's targets.
    def self.app_minimum(installer)
      installer.aggregate_targets
        .map(&:platform)
        .select { |platform| platform.name == :ios }
        .map { |platform| version(platform.deployment_target) }
        .compact
        .min
    end

    def self.projects(installer)
      projects = installer.respond_to?(:generated_projects) && installer.generated_projects ? installer.generated_projects : [installer.pods_project]
      projects.compact.uniq
    end

    def self.apply(installer)
      minimum = sdk_minimum
      unless minimum
        log "Couldn't read the iOS SDK's minimum deployment target (is Xcode selected with xcode-select?), so no deployment targets were changed."
        return
      end

      app = app_minimum(installer)
      if app && app < minimum
        log "The app targets iOS #{app}, below this Xcode's minimum of #{minimum}. Raise `platform :ios` in the Podfile; no pods were changed."
        return
      end
      floor = app || minimum

      projects(installer).each do |project|
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
  # 11.0.2 when it builds from source. The error comes from fmt's headers, so every C++20 target that
  # includes them fails, not only fmt itself. This turns consteval off for Apple Clang in the pod's
  # copy of fmt/base.h, as the usual Podfile workaround does, and compiles the fmt pod as C++17.
  module Fmt
    FIXED = Gem::Version.new('12.1')
    MARKER = 'react-native-xcode27: consteval off for Apple Clang'
    BRANCH = "#elif defined(__cpp_consteval)\n#  define FMT_USE_CONSTEVAL 1\n"

    def self.patch_header(installer, fmt)
      base = File.join(installer.sandbox.pod_dir(fmt.pod_name).to_s, 'include', 'fmt', 'base.h')
      return unless File.file?(base)
      content = File.read(base)
      if content.include?(MARKER)
        DeploymentTargets.log "fmt #{fmt.root_spec.version}: consteval off in fmt/base.h"
        return
      end
      return unless content.include?(BRANCH)
      File.chmod(File.stat(base).mode | 0o200, base)
      branch = "#elif defined(__apple_build_version__)  // #{MARKER}\n#  define FMT_USE_CONSTEVAL 0\n"
      File.write(base, content.sub(BRANCH) { branch + BRANCH })
      DeploymentTargets.log "fmt #{fmt.root_spec.version}: consteval off in fmt/base.h"
    rescue StandardError => error
      DeploymentTargets.log "fmt #{fmt.root_spec.version}: couldn't update fmt/base.h (#{error.message})"
    end

    def self.apply(installer)
      fmt = installer.pod_targets.find { |target| target.pod_name == 'fmt' }
      return unless fmt && Gem::Version.new(fmt.root_spec.version.to_s) < FIXED
      patch_header(installer, fmt)
      DeploymentTargets.projects(installer).each do |project|
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

  # With Xcode's explicitly built Swift modules, Swift code that calls C++ through C++ interop
  # (SWIFT_OBJC_INTEROP_MODE = objcxx) gets libc++'s iOS 18 implementation of
  # std::make_exception_ptr even when the app supports earlier iOS. The object then references
  # __cxa_init_primary_exception and std::exception_ptr::__from_native_exception_pointer, which
  # earlier iOS doesn't have, and the app stops at launch there ("Symbol not found:
  # __ZNSt13exception_ptr31__from_native_exception_pointerEPv"). Built with implicit modules, the same
  # code uses the older implementation. React Native already turns explicit modules off when it uses
  # precompiled binaries; this does it for C++ interop targets when the app supports iOS before 18.
  module ExplicitModules
    IOS_18 = Gem::Version.new('18.0')
    SETTING = 'SWIFT_ENABLE_EXPLICIT_MODULES'

    def self.interop?(configuration)
      return true if configuration.build_settings['SWIFT_OBJC_INTEROP_MODE'].to_s == 'objcxx'
      xcconfig = configuration.base_configuration_reference&.real_path
      !!(xcconfig && File.file?(xcconfig) && File.read(xcconfig).match?(/^\s*SWIFT_OBJC_INTEROP_MODE\s*=\s*objcxx\s*$/))
    rescue StandardError
      false
    end

    def self.apply(installer)
      app = DeploymentTargets.app_minimum(installer)
      return unless app && app < IOS_18
      DeploymentTargets.projects(installer).each do |project|
        inherited = project.build_configurations.to_h { |configuration| [configuration.name, configuration.build_settings[SETTING].to_s] }
        project.targets.each do |target|
          changed = false
          target.build_configurations.each do |configuration|
            next unless interop?(configuration)
            effective = configuration.build_settings[SETTING] || inherited[configuration.name]
            next if effective.to_s == 'NO'
            configuration.build_settings[SETTING] = 'NO'
            changed = true
          end
          DeploymentTargets.log "#{target.name}: Swift explicit modules off (C++ interop, app supports iOS #{app})" if changed
        end
      end
    end
  end

  module PostInstall
    def post_install!(installer)
      ran = super
      DeploymentTargets.apply(installer)
      Fmt.apply(installer)
      ExplicitModules.apply(installer)
      ran
    end
  end
end

Pod::Podfile.prepend(ReactNativeXcode27::PostInstall) unless Pod::Podfile.ancestors.include?(ReactNativeXcode27::PostInstall)
