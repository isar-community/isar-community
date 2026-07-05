#!/bin/bash

version=`dart packages/isar_community/tool/get_version.dart`
binariesUrl="https://binaries.isar-community.dev/$ISAR_VERSION"


curl "${binariesUrl}/libisar_android_arm64.so" -o packages/isar_community_flutter_libs/android/src/main/jniLibs/arm64-v8a/libisar.so --create-dirs -L -f
curl "${binariesUrl}/libisar_android_armv7.so" -o packages/isar_community_flutter_libs/android/src/main/jniLibs/armeabi-v7a/libisar.so --create-dirs -L -f
curl "${binariesUrl}/libisar_android_x64.so" -o packages/isar_community_flutter_libs/android/src/main/jniLibs/x86_64/libisar.so --create-dirs -L
curl "${binariesUrl}/libisar_android_x86.so" -o packages/isar_community_flutter_libs/android/src/main/jniLibs/x86/libisar.so --create-dirs -L -f

curl "${binariesUrl}/isar_ios.xcframework.zip" -o packages/isar_community_flutter_libs/ios/isar_ios.xcframework.zip --create-dirs -L -f
unzip -o packages/isar_community_flutter_libs/ios/isar_ios.xcframework.zip -d packages/isar_community_flutter_libs/ios
rm packages/isar_community_flutter_libs/ios/isar_ios.xcframework.zip

curl "${binariesUrl}/libisar_macos.dylib" -o packages/isar_community_flutter_libs/macos/libisar.dylib --create-dirs -L -f
curl "${binariesUrl}/libisar_linux_x64.so" -o packages/isar_community_flutter_libs/linux/libisar.so --create-dirs -L -f
curl "${binariesUrl}/isar_windows_x64.dll" -o packages/isar_community_flutter_libs/windows/libisar.dll --create-dirs -L -f
