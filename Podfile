# Uncomment the next line to define a global platform for your project
platform :ios, '12.0'

target 'CodeComplete' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for CodeComplete
	# Using git directly because some pieces of the class were not made public in 0.2.0
	# Looks like newer commits of Sourceful depend on SwiftUI which seems to break when archiving
	# this project
  pod 'Sourceful', :git => 'git@github.com:twostraws/Sourceful.git', :commit => '9cdd591c415342679eea178e416a36837d0934e7'
  pod 'Highlightr', '~> 2.1.0'
  pod 'Purchases'
  pod 'Firebase/Auth'
  pod 'Firebase/Functions'
  pod 'Firebase/Analytics'
  pod 'Firebase/Messaging'
  pod 'Firebase/Crashlytics'
  pod 'SwiftKeychainWrapper', '3.4.0'
  pod 'TestFairy'
  pod 'FBSDKCoreKit', '~> 7.1.1'
  pod "SwiftRater", '~> 1.8.0'
  pod 'Instructions', '~> 2.0.0'
	
  target 'CodeCompleteTests' do
    inherit! :search_paths
  end
end
