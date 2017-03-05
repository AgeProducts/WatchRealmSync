
use_frameworks!

def shared_pods
  pod 'RealmSwift'
  pod 'RandomKit'
end

target ‘WatchRealmSync’ do
  platform :ios, ‘10.2’
  shared_pods
  pod 'RxRealm'
  pod 'RxSwift'
  pod 'RxCocoa'
end

target ‘WatchRealmSyncWatchApp’ do
  platform :watchos, ‘3.1’
  shared_pods
end

target ‘WatchRealmSyncWatchApp Extension’ do
  platform :watchos, ‘3.1’
  shared_pods
end

post_install do |installer|
      installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
          config.build_settings['SWIFT_VERSION'] = ‘3.0’
         end
       end
end
