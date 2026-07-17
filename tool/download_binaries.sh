#!/bin/bash
set -euo pipefail

# Prefer explicit ISAR_VERSION (CI/release); fall back to package version.
if [ -z "${ISAR_VERSION:-}" ]; then
  ISAR_VERSION="$(cd packages/isar_community && dart run tool/get_version.dart)"
fi
binariesUrl="https://binaries.isar-community.dev/$ISAR_VERSION"

curl "${binariesUrl}/libisar_android_arm64.so" -o packages/isar_community_flutter_libs/android/src/main/jniLibs/arm64-v8a/libisar.so --create-dirs -L -f
curl "${binariesUrl}/libisar_android_armv7.so" -o packages/isar_community_flutter_libs/android/src/main/jniLibs/armeabi-v7a/libisar.so --create-dirs -L -f
curl "${binariesUrl}/libisar_android_x64.so" -o packages/isar_community_flutter_libs/android/src/main/jniLibs/x86_64/libisar.so --create-dirs -L
curl "${binariesUrl}/libisar_android_x86.so" -o packages/isar_community_flutter_libs/android/src/main/jniLibs/x86/libisar.so --create-dirs -L -f

ios_spm_dir="packages/isar_community_flutter_libs/ios/isar_community_flutter_libs"
mkdir -p "$ios_spm_dir"
curl "${binariesUrl}/isar_ios.xcframework.zip" -o packages/isar_community_flutter_libs/ios/isar_ios.xcframework.zip --create-dirs -L -f
rm -rf "$ios_spm_dir/isar.xcframework"
unzip -o packages/isar_community_flutter_libs/ios/isar_ios.xcframework.zip -d "$ios_spm_dir"
rm packages/isar_community_flutter_libs/ios/isar_ios.xcframework.zip

macos_dir="packages/isar_community_flutter_libs/macos"
macos_spm_dir="$macos_dir/isar_community_flutter_libs"
mkdir -p "$macos_spm_dir"
curl "${binariesUrl}/libisar_macos.dylib" -o "$macos_dir/libisar.dylib" --create-dirs -L -f
rm -rf "$macos_spm_dir/isar.xcframework"
cp "$macos_dir/libisar.dylib" /tmp/libisar.dylib
xcodebuild -create-xcframework \
  -library /tmp/libisar.dylib \
  -output "$macos_spm_dir/isar.xcframework"
rm -f /tmp/libisar.dylib

curl "${binariesUrl}/libisar_linux_x64.so" -o packages/isar_community_flutter_libs/linux/libisar.so --create-dirs -L -f
curl "${binariesUrl}/isar_windows_x64.dll" -o packages/isar_community_flutter_libs/windows/libisar.dll --create-dirs -L -f
