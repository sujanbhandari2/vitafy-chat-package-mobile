Pod::Spec.new do |s|
  s.name             = 'health_messenger_ui'
  s.version          = '0.1.0'
  s.summary          = 'Health Messenger UI with optional FCM push bridge'
  s.description      = <<-DESC
Flutter plugin portion for native message push ACK and MethodChannel bridge.
                       DESC
  s.homepage         = 'https://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Health Messenger' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'Firebase/Messaging'
  s.platform = :ios, '13.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
