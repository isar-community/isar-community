Pod::Spec.new do |s|
  s.name             = 'isar_community_flutter_libs'
  s.version          = '1.0.0'
  s.summary          = 'Flutter binaries for the Isar Database. Needs to be included for Flutter apps.'
  s.homepage         = 'https://isar-community.dev'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Isar' => 'hello@isar.dev' }

  s.source           = { :path => '.' }
  s.source_files     = 'isar_community_flutter_libs/Sources/isar_community_flutter_libs/**/*.swift'
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.15'
  s.swift_version = '5.9'
  s.vendored_libraries  = 'libisar.dylib'
end
