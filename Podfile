platform :ios, '18.0'
use_frameworks!
inhibit_all_warnings!

target 'Articles' do
  # Required by the challenge
  pod 'Alamofire', '~> 5.10'
  pod 'XCGLogger', '~> 7.1'
  pod 'Swinject', '~> 2.9'
  pod 'ReachabilitySwift', '~> 5.2'
  pod 'Kingfisher', '~> 8.0'
  pod 'Cache', '~> 6.0'

  target 'ArticlesTests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      # Keep every pod on the app's deployment target so Xcode 26 raises no
      # "deployment target is not supported" warnings.
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '18.0'
      config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
    end
  end

  # With Xcode 26, TOOLCHAIN_DIR can resolve to the separately installed Metal
  # toolchain, which has no Swift libraries, and the linker then warns about a
  # missing search path. DT_TOOLCHAIN_DIR always points at the Xcode toolchain.
  installer.aggregate_targets.each do |aggregate_target|
    aggregate_target.xcconfigs.each_key do |config_name|
      path = aggregate_target.xcconfig_path(config_name)
      contents = File.read(path)
      patched = contents.gsub('${TOOLCHAIN_DIR}/usr/lib/swift', '${DT_TOOLCHAIN_DIR}/usr/lib/swift')
      File.write(path, patched) unless patched == contents
    end
  end
end
