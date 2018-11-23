# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'
swift_version = '4.2'
target 'AUv3' do
  use_frameworks!
  pod 'MusicTheorySwift'
  pod 'AudioKit'
  pod 'LiveKnob'
  pod 'MIDIEventKit'
end

target 'BasicSequencerAUv3' do
  use_frameworks!
  pod 'MusicTheorySwift'
  pod 'AudioKit'
  pod 'LiveKnob'
  pod 'MIDIEventKit'
end

post_install do |installer|
  installer.pods_project.build_configurations.each do |config|
    config.build_settings.delete('CODE_SIGNING_ALLOWED')
    config.build_settings.delete('CODE_SIGNING_REQUIRED')
  end
end
