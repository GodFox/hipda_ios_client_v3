platform :ios, '15.0'

target 'HiPDA' do
  pod "AFNetworking", "1.3.3"
  pod 'SDWebImage'
  pod 'MTLog'
  pod 'HMSegmentedControl'
  pod 'RegexKitLite'
  pod 'SVProgressHUD', '~> 1.0'
  pod 'ZAActivityBar'
  pod 'JSMessagesViewController'
  pod 'ALActionBlocks'
  pod 'NSString+Emoji'
  pod 'SDWebImage-ProgressView'
  pod 'FMDB'
  pod 'JDStatusBarNotification'
  pod 'MCSwipeTableViewCell'
  pod 'SSKeychain'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'

      # AFNetworking 1.3.3 在启用 Clang modules 时会因 netinet6/in6.h 私有头报错
      if target.name == 'AFNetworking'
        config.build_settings['CLANG_ENABLE_MODULES'] = 'NO'
      end
    end
  end
end
