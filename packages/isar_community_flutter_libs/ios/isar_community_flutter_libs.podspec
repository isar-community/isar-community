Pod::Spec.new do |s|
  s.name             = 'isar_community_flutter_libs'
  s.version          = '1.0.0'
  s.summary          = 'Flutter binaries for the Isar Database. Needs to be included for Flutter apps.'
  s.homepage         = 'https://isar-community.dev'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Isar' => 'hello@isar.dev' }

  s.source           = { :path => '.' }
  s.source_files     = 'isar_community_flutter_libs/Sources/isar_community_flutter_libs/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  s.swift_version = '5.9'
  s.vendored_frameworks = 'isar_community_flutter_libs/isar.xcframework'
  s.resource_bundles = {'isar_community_flutter_libs_apple_privacy' => ['isar_community_flutter_libs/Sources/isar_community_flutter_libs/PrivacyInfo.xcprivacy']}
end
