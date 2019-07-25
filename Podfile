use_frameworks!
supports_swift_versions '>= 4.0', '<= 4.2'

def pods_for_testing
  pod 'Swifter', :git => 'https://github.com/httpswift/swifter.git'
  pod 'Erik', :git => 'https://github.com/phimage/Erik.git'
  pod 'Kanna', :git => 'https://github.com/tid-kijyun/Kanna.git'
end

target 'OAuthSwiftTestsMacOS' do
    platform :osx, '10.11'

    pods_for_testing
end

target 'OAuthSwiftTests' do
    platform :ios, '10.0'

    pods_for_testing
end
